//
//  AdministradorQwen.swift
//  Claro
//
//  Descarga y ejecuta Qwen únicamente para el chat financiero. Esta clase
//  no recibe PDFs, páginas OCR, movimientos para importar ni ModelContext.
//

import Combine
import Foundation
import HuggingFace
import MLX
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

enum EstadoModeloQwen: Equatable {
    case noDescargado
    case descargando(Double)
    case descargado
    case cargando
    case listo
    case error(String)
}

enum ModeloQwen: String, CaseIterable, Identifiable {
    case estable4B
    case potente8B

    var id: String { rawValue }

    var modeloID: String {
        switch self {
        case .estable4B: return "Qwen/Qwen3-4B-MLX-4bit"
        // Conserva los 8.2B parámetros del modelo, pero baja el peso de los
        // archivos para que la carga tenga margen real dentro de iOS.
        case .potente8B: return "mlx-community/Qwen3-8B-3bit"
        }
    }

    var nombreVisible: String {
        switch self {
        case .estable4B: return "Qwen3 4B"
        case .potente8B: return "Qwen3 8B"
        }
    }

    var nombreSelector: String {
        switch self {
        case .estable4B: return "4B · Estable"
        case .potente8B: return "8B · Potente"
        }
    }

    var tamanoAproximado: String {
        switch self {
        case .estable4B: return "2.14 GB"
        case .potente8B: return "3.58 GB"
        }
    }

    var espacioMinimoDescarga: Int64 {
        switch self {
        case .estable4B: return 2_700_000_000
        case .potente8B: return 4_300_000_000
        }
    }

    var nombreDirectorio: String {
        switch self {
        case .estable4B: return "Qwen3-4B-MLX-4bit"
        case .potente8B: return "Qwen3-8B-4bit"
        }
    }

    /// Ambos modelos usan caché creciente y cuantizada. Asignar un máximo
    /// aquí crea RotatingKVCache, que en MLX Swift todavía no puede
    /// cuantizarse y fue la causa del exceso de memoria observado en el 4B.
    var maximoKV: Int? {
        nil
    }

    func maximoTokens(requiereRazonamiento: Bool) -> Int {
        switch self {
        case .estable4B:
            return requiereRazonamiento ? 1_200 : 750
        case .potente8B:
            return requiereRazonamiento ? 8_192 : 4_096
        }
    }

    var descripcionCapacidad: String {
        switch self {
        case .estable4B:
            return "Perfil estable · caché optimizada para este iPhone"
        case .potente8B:
            return "8.2B parámetros · hasta 8,192 tokens al razonar"
        }
    }
}

struct MetricasQwen: Equatable {
    let segundos: Double
    let tokensGenerados: Int
    let temperatura: String
    let picoMemoriaMLX: Int

    var tokensPorSegundo: Double {
        guard segundos > 0 else { return 0 }
        return Double(tokensGenerados) / segundos
    }

    var descripcion: String {
        let tiempo = segundos.formatted(.number.precision(.fractionLength(1)))
        let velocidad = tokensPorSegundo.formatted(
            .number.precision(.fractionLength(1)))
        let memoria = ByteCountFormatter.string(
            fromByteCount: Int64(picoMemoriaMLX), countStyle: .memory)
        return "Última respuesta: \(tiempo) s · \(tokensGenerados) tokens · \(velocidad) tokens/s · pico MLX \(memoria) · \(temperatura)"
    }
}

@MainActor
final class AdministradorQwen: ObservableObject {
    static let shared = AdministradorQwen()

    @Published private(set) var estado: EstadoModeloQwen = .noDescargado
    @Published private(set) var modeloSeleccionado: ModeloQwen
    @Published private(set) var metricasUltimaRespuesta: MetricasQwen?

    private var contenedor: ModelContainer?
    private var operacionEnCurso = false

    private static let claveModeloSeleccionado = "modeloQwenSeleccionado"
    private static let limiteCacheMLX = 32 * 1_024 * 1_024

    private init() {
        // MLX conserva por defecto buffers temporales hasta un límite muy
        // grande. En iOS esos buffers compiten con el modelo y pueden activar
        // jetsam aunque los pesos sí hayan cabido.
        Memory.cacheLimit = Self.limiteCacheMLX
        Memory.clearCache()
        let valorGuardado = UserDefaults.standard.string(
            forKey: Self.claveModeloSeleccionado)
        let modelo = valorGuardado.flatMap(ModeloQwen.init(rawValue:)) ?? .estable4B
        self.modeloSeleccionado = modelo
        self.estado = Self.snapshotCompleto(del: modelo) != nil
            ? .descargado : .noDescargado
    }

    var estaDescargado: Bool {
        Self.snapshotCompleto(del: modeloSeleccionado) != nil
    }

    var estaListo: Bool {
        if case .listo = estado { return true }
        return false
    }

    var puedeCambiarModelo: Bool { !operacionEnCurso }

    var nombreVisible: String { modeloSeleccionado.nombreVisible }

    var tamanoAproximado: String { modeloSeleccionado.tamanoAproximado }

    var descripcionEstado: String {
        switch estado {
        case .noDescargado: return "Disponible para descargar"
        case .descargando(let avance): return "Descargando \(Int(avance * 100))%"
        case .descargado: return "Descargado · toca Preparar para cargarlo"
        case .cargando: return "Preparando el modelo"
        case .listo: return "Listo · todo se procesa en este iPhone"
        case .error(let mensaje): return mensaje
        }
    }

    /// Cambia de modelo sin descargarlo ni cargarlo automáticamente. Separar
    /// esas etapas evita mantener dos modelos o buffers temporales a la vez.
    func seleccionar(_ modelo: ModeloQwen) async {
        guard !operacionEnCurso else { return }
        guard modelo != modeloSeleccionado else { return }

        liberarModeloDeMemoria()
        metricasUltimaRespuesta = nil
        modeloSeleccionado = modelo
        UserDefaults.standard.set(modelo.rawValue,
                                  forKey: Self.claveModeloSeleccionado)
        estado = estaDescargado ? .descargado : .noDescargado
    }

    /// Descarga desde Hugging Face exclusivamente los archivos públicos del
    /// modelo. No lo carga inmediatamente: así la memoria temporal de red se
    /// libera antes de que el usuario pulse Preparar.
    func descargar() async {
        guard !operacionEnCurso else { return }
        operacionEnCurso = true
        defer { operacionEnCurso = false }
        estado = .descargando(0)

        do {
            try limpiarVersionAnteriorSiCorresponde()
            try verificarEspacioDisponible()
            let cache = HubCache(cacheDirectory:
                Self.directorioDelModelo(modeloSeleccionado))
            let cliente = HubClient(cache: cache)
            let repo = Repo.ID(rawValue: modeloSeleccionado.modeloID)!
            _ = try await cliente.downloadSnapshot(
                of: repo,
                matching: ["*.json", "*.safetensors", "*.txt", "*.model", "*.jinja"],
                // El modelo tiene un archivo de varios GB. Una descarga a la
                // vez reduce buffers y deja que el sistema reanude el archivo.
                maxConcurrentDownloads: 1) { [weak self] progreso in
                    guard let self else { return }
                    let fraccion = progreso.totalUnitCount > 0
                        ? progreso.fractionCompleted : 0
                    self.estado = .descargando(min(1, max(0, fraccion)))
                }
            Memory.clearCache()
            estado = .descargado
        } catch {
            liberarModeloDeMemoria()
            estado = .error(Self.mensajeAmigable(error))
        }
    }

    /// Al abrir el chat se prepara automáticamente solo el 4B, que ya fue
    /// validado para uso cotidiano. El 8B requiere un toque explícito.
    func prepararAlAbrir() async {
        guard estaDescargado else {
            estado = .noDescargado
            return
        }
        if modeloSeleccionado == .estable4B {
            await prepararSiEstaDescargado()
        } else {
            estado = .descargado
        }
    }

    /// Al abrir el chat, carga desde disco sin hacer una nueva descarga.
    func prepararSiEstaDescargado() async {
        guard contenedor == nil, !operacionEnCurso, estaDescargado else {
            if !estaDescargado && contenedor == nil { estado = .noDescargado }
            return
        }
        guard let snapshot = directorioSnapshotActual else {
            estado = .noDescargado
            return
        }
        operacionEnCurso = true
        estado = .cargando
        do {
            Memory.clearCache()
            try await cargar(desde: snapshot)
            Memory.clearCache()
            estado = .listo
        } catch {
            liberarModeloDeMemoria()
            estado = .error(Self.mensajeAmigable(error))
        }
        operacionEnCurso = false
    }

    /// Entrada deliberadamente limitada a texto ya calculado por el Motor
    /// financiero. Qwen no conoce ni puede modificar SwiftData.
    func responder(solicitud: String, requiereRazonamiento: Bool) async throws -> String {
        guard let contenedor else { throw ErrorQwen.modeloNoDisponible }

        Memory.clearCache()
        Memory.peakMemory = 0

        let parametros = GenerateParameters(
            maxTokens: modeloSeleccionado.maximoTokens(
                requiereRazonamiento: requiereRazonamiento),
            maxKVSize: modeloSeleccionado.maximoKV,
            kvBits: 8,
            temperature: requiereRazonamiento ? 0.45 : 0.30,
            topP: 0.88,
            topK: 20,
            minP: 0,
            repetitionPenalty: 1.05,
            repetitionContextSize: 64)
        let sesion = ChatSession(
            contenedor,
            instructions: ClaroInteligenciaLocal.instruccionesDelCopiloto,
            generateParameters: parametros)
        let modo = requiereRazonamiento ? "/think" : "/no_think"
        let inicio = Date()
        let texto = try await sesion.respond(to: "\(solicitud)\n\n\(modo)")
        let segundos = max(0.001, Date().timeIntervalSince(inicio))
        let tokenizador = await contenedor.tokenizer
        let cantidadTokens = tokenizador.encode(text: texto).count
        let memoria = Memory.snapshot()
        metricasUltimaRespuesta = MetricasQwen(
            segundos: segundos,
            tokensGenerados: cantidadTokens,
            temperatura: Self.descripcionTermica(ProcessInfo.processInfo.thermalState),
            picoMemoriaMLX: memoria.peakMemory)
        Memory.clearCache()
        let limpio = Self.limpiarRazonamientoInterno(texto)
        guard !limpio.isEmpty else { throw ErrorQwen.respuestaVacia }
        return limpio
    }

    /// Borra solo la carpeta dedicada a Qwen. Los datos financieros, PDFs y
    /// respaldos de Claro viven en contenedores distintos y no se tocan.
    func eliminarModelo() throws {
        guard !operacionEnCurso else { return }
        liberarModeloDeMemoria()
        let objetivo = Self.directorioDelModelo(modeloSeleccionado).standardizedFileURL
        let caches = FileManager.default.urls(for: .cachesDirectory,
                                              in: .userDomainMask)[0].standardizedFileURL
        let raizModelos = caches.appendingPathComponent(
            "ClaroModelos", isDirectory: true).standardizedFileURL
        let nombresPermitidos = Set(ModeloQwen.allCases.map(\.nombreDirectorio))
        guard objetivo.deletingLastPathComponent() == raizModelos,
              nombresPermitidos.contains(objetivo.lastPathComponent) else {
            throw ErrorQwen.rutaNoSegura
        }
        if FileManager.default.fileExists(atPath: objetivo.path) {
            try FileManager.default.removeItem(at: objetivo)
        }
        metricasUltimaRespuesta = nil
        estado = .noDescargado
    }

    private func cargar(desde snapshot: URL) async throws {
        contenedor = try await LLMModelFactory.shared.loadContainer(
            from: snapshot,
            using: #huggingFaceTokenizerLoader())
    }

    private func liberarModeloDeMemoria() {
        contenedor = nil
        Memory.clearCache()
    }

    private func verificarEspacioDisponible() throws {
        guard !estaDescargado else { return }
        let caches = FileManager.default.urls(for: .cachesDirectory,
                                              in: .userDomainMask)[0]
        let valores = try? caches.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let disponible = valores?.volumeAvailableCapacityForImportantUsage,
              disponible < modeloSeleccionado.espacioMinimoDescarga else { return }
        throw ErrorQwen.espacioInsuficiente(
            requerido: modeloSeleccionado.espacioMinimoDescarga,
            disponible: disponible)
    }

    /// La primera versión de prueba apuntaba al 8B de 4 bits. Al volver a
    /// pulsar Descargar para el perfil potente, se elimina exclusivamente
    /// ese repositorio antiguo o incompleto; las finanzas viven fuera de aquí.
    private func limpiarVersionAnteriorSiCorresponde() throws {
        guard modeloSeleccionado == .potente8B,
              Self.snapshotCompleto(del: .potente8B) == nil else { return }
        let cache = HubCache(cacheDirectory:
            Self.directorioDelModelo(.potente8B))
        let idAnterior = Repo.ID(rawValue: "mlx-community/Qwen3-8B-4bit")!
        let objetivos = [
            cache.repoDirectory(repo: idAnterior, kind: .model),
            cache.metadataDirectory(repo: idAnterior, kind: .model)
        ]
        for objetivo in objetivos where FileManager.default.fileExists(atPath: objetivo.path) {
            try FileManager.default.removeItem(at: objetivo)
        }
    }

    private var directorioSnapshotActual: URL? {
        Self.snapshotCompleto(del: modeloSeleccionado)
    }

    private static func snapshotCompleto(del modelo: ModeloQwen) -> URL? {
        let cache = HubCache(cacheDirectory: directorioDelModelo(modelo))
        let repo = Repo.ID(rawValue: modelo.modeloID)!
        guard let revision = cache.resolveRevision(repo: repo, kind: .model,
                                                   ref: "main") else { return nil }
        let candidato = cache.snapshotsDirectory(repo: repo, kind: .model)
            .appendingPathComponent(revision, isDirectory: true)
        return contienePesos(en: candidato) ? candidato : nil
    }

    private static func directorioDelModelo(_ modelo: ModeloQwen) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClaroModelos", isDirectory: true)
            .appendingPathComponent(modelo.nombreDirectorio, isDirectory: true)
    }

    private static func contienePesos(en directorio: URL) -> Bool {
        guard let enumerador = FileManager.default.enumerator(
            at: directorio,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]) else { return false }
        for case let archivo as URL in enumerador
            where archivo.pathExtension == "safetensors" {
            return true
        }
        return false
    }

    private static func limpiarRazonamientoInterno(_ texto: String) -> String {
        var limpio = texto
        if let expresion = try? NSRegularExpression(
            pattern: #"<think>[\s\S]*?</think>"#,
            options: [.caseInsensitive]) {
            limpio = expresion.stringByReplacingMatches(
                in: limpio,
                range: NSRange(limpio.startIndex..., in: limpio),
                withTemplate: "")
        }
        if let cierre = limpio.range(of: "</think>", options: .caseInsensitive) {
            limpio = String(limpio[cierre.upperBound...])
        }
        return limpio.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func mensajeAmigable(_ error: Error) -> String {
        if let errorQwen = error as? ErrorQwen {
            return errorQwen.localizedDescription
        }
        if (error as NSError).domain == NSURLErrorDomain {
            return "No pude descargar Qwen. Revisa tu conexión y el espacio disponible. Detalle: \(error.localizedDescription)"
        }
        return "No pude preparar Qwen: \(error.localizedDescription)"
    }

    private static func descripcionTermica(
        _ estado: ProcessInfo.ThermalState) -> String {
        switch estado {
        case .nominal: return "temperatura normal"
        case .fair: return "temperatura moderada"
        case .serious: return "temperatura alta"
        case .critical: return "temperatura crítica"
        @unknown default: return "temperatura desconocida"
        }
    }
}

private enum ErrorQwen: LocalizedError {
    case modeloNoDisponible
    case respuestaVacia
    case rutaNoSegura
    case espacioInsuficiente(requerido: Int64, disponible: Int64)

    var errorDescription: String? {
        switch self {
        case .modeloNoDisponible:
            return "Qwen no está preparado. Toca Preparar e inténtalo de nuevo."
        case .respuestaVacia: return "Qwen no produjo una respuesta."
        case .rutaNoSegura: return "No se pudo verificar la carpeta del modelo."
        case .espacioInsuficiente(let requerido, let disponible):
            let formato = ByteCountFormatter()
            formato.countStyle = .file
            return "Falta espacio para descargar Qwen: necesita aproximadamente \(formato.string(fromByteCount: requerido)) y hay \(formato.string(fromByteCount: disponible)) disponibles."
        }
    }
}
