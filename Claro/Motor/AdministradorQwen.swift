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
#if canImport(UIKit)
import UIKit
#endif

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

    var id: String { rawValue }

    var modeloID: String { "Qwen/Qwen3-4B-MLX-4bit" }

    var nombreVisible: String { "Qwen3 4B" }

    var tamanoAproximado: String { "2.14 GB" }

    var espacioMinimoDescarga: Int64 { 2_700_000_000 }

    var nombreDirectorio: String { "Qwen3-4B-MLX-4bit" }

    /// Ambos modelos usan caché creciente y cuantizada. Asignar un máximo
    /// aquí crea RotatingKVCache, que en MLX Swift todavía no puede
    /// cuantizarse y fue la causa del exceso de memoria observado en el 4B.
    var maximoKV: Int? {
        nil
    }

    func maximoTokens(requiereRazonamiento: Bool) -> Int {
        requiereRazonamiento ? 1_200 : 750
    }

    var descripcionCapacidad: String {
        "Perfil estable · Qwen3 4B con Apple Intelligence como complemento"
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
    @Published private(set) var bytesDescargados: Int64 = 0
    @Published private(set) var bytesTotales: Int64 = 0

    private var contenedor: ModelContainer?
    private var operacionEnCurso = false
    private var generandoRespuesta = false
    private var tareaDescarga: Task<Void, Never>?

    private static let claveModeloSeleccionado = "modeloQwenSeleccionado"
    private static let limiteCacheMLX = 32 * 1_024 * 1_024
    private static let contextoTotalSeguro = 4_608
    private static let reservaPlantillaTokens = 128
    private static let nombreDirectorio8BRetirado = "Qwen3-8B-4bit"

    private init() {
        // La prueba 8B se retiró porque excede la memoria práctica del iPhone.
        // Se elimina únicamente su caché; SwiftData, PDFs y respaldos viven
        // fuera de ClaroModelos y nunca pasan por esta ruta.
        Self.eliminarCache8BRetirada()
        // MLX conserva por defecto buffers temporales hasta un límite muy
        // grande. En iOS esos buffers compiten con el modelo y pueden activar
        // jetsam aunque los pesos sí hayan cabido.
        Memory.cacheLimit = Self.limiteCacheMLX
        Memory.clearCache()
        let modelo = ModeloQwen.estable4B
        self.modeloSeleccionado = modelo
        UserDefaults.standard.set(modelo.rawValue,
                                  forKey: Self.claveModeloSeleccionado)
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

    var puedeCambiarModelo: Bool { !operacionEnCurso && !generandoRespuesta }

    /// Impide que Apple Intelligence intente reservar memoria mientras una
    /// inferencia de Qwen cancelada todavía termina de soltar sus buffers.
    var bloqueaOtroModeloEnMemoria: Bool {
        operacionEnCurso || generandoRespuesta || contenedor != nil
    }

    var nombreVisible: String { modeloSeleccionado.nombreVisible }

    var tamanoAproximado: String { modeloSeleccionado.tamanoAproximado }

    var descripcionEstado: String {
        switch estado {
        case .noDescargado: return "Disponible para descargar"
        case .descargando(let avance):
            guard bytesDescargados > 0 else {
                return "Conectando y preparando \(tamanoAproximado)…"
            }
            let descargado = ByteCountFormatter.string(
                fromByteCount: bytesDescargados, countStyle: .file)
            let total = ByteCountFormatter.string(
                fromByteCount: max(bytesTotales, 1), countStyle: .file)
            let porcentaje = (avance * 100).formatted(
                .number.precision(.fractionLength(avance < 0.01 ? 1 : 0)))
            return "Descargando \(descargado) de \(total) · \(porcentaje)%"
        case .descargado: return "Disponible · se carga solo al preguntar"
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
        bytesDescargados = 0
        bytesTotales = 0
        modeloSeleccionado = modelo
        UserDefaults.standard.set(modelo.rawValue,
                                  forKey: Self.claveModeloSeleccionado)
        estado = estaDescargado ? .descargado : .noDescargado
    }

    /// Descarga desde Hugging Face exclusivamente los archivos públicos del
    /// modelo. No lo carga inmediatamente: así la memoria temporal de red se
    /// libera antes de que el usuario pulse Preparar.
    func iniciarDescarga() {
        guard tareaDescarga == nil, !operacionEnCurso else { return }
        tareaDescarga = Task { [weak self] in
            guard let self else { return }
            await self.descargar()
            self.tareaDescarga = nil
        }
    }

    func cancelarDescarga() {
        guard case .descargando = estado else { return }
        tareaDescarga?.cancel()
        estado = estaDescargado ? .descargado : .noDescargado
    }

    private func descargar() async {
        guard !operacionEnCurso else { return }
        operacionEnCurso = true
        defer { operacionEnCurso = false }
        #if canImport(UIKit)
        let reposoEstabaDeshabilitado = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        defer {
            UIApplication.shared.isIdleTimerDisabled = reposoEstabaDeshabilitado
        }
        #endif
        bytesDescargados = 0
        bytesTotales = 0
        estado = .descargando(0)

        do {
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
                    self.bytesDescargados = max(0, progreso.completedUnitCount)
                    self.bytesTotales = max(0, progreso.totalUnitCount)
                    self.estado = .descargando(min(1, max(0, fraccion)))
                }
            Memory.clearCache()
            estado = .descargado
        } catch {
            liberarModeloDeMemoria()
            if Task.isCancelled || Self.esCancelacionDeRed(error) {
                estado = estaDescargado ? .descargado : .noDescargado
            } else {
                estado = .error(Self.mensajeAmigable(error))
            }
        }
    }

    /// Al abrir el chat solo se comprueba que el modelo esté en el iPhone.
    /// Mantener sus pesos residentes mientras Apple Intelligence trabaja fue
    /// la causa de los cierres por memoria después de la primera respuesta.
    func prepararAlAbrir() async {
        guard estaDescargado else {
            estado = .noDescargado
            return
        }
        // Una vista nueva puede aparecer mientras la anterior todavía está
        // terminando una inferencia cancelada. Nunca se toca el contenedor ni
        // la caché de una operación activa.
        guard !generandoRespuesta, !operacionEnCurso else { return }
        liberarModeloDeMemoria()
        estado = .descargado
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
            // El pico comienza antes de cargar los pesos; antes se reiniciaba
            // después y ocultaba precisamente la parte más costosa.
            Memory.peakMemory = 0
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
    func responder(solicitud: String,
                   instrucciones: String,
                   requiereRazonamiento: Bool) async throws -> String {
        guard let contenedor else { throw ErrorQwen.modeloNoDisponible }
        guard !generandoRespuesta, !operacionEnCurso else {
            throw ErrorQwen.respuestaEnCurso
        }
        operacionEnCurso = true
        generandoRespuesta = true
        defer {
            generandoRespuesta = false
            operacionEnCurso = false
            // Nunca se conserva Qwen entre preguntas. Esto deja libre la RAM
            // para Apple Intelligence, SwiftUI, SwiftData y la próxima carga.
            self.contenedor = nil
            estado = estaDescargado ? .descargado : .noDescargado
            // No se difiere esta limpieza en otra Task: una limpieza tardía
            // podía coincidir con la carga de la siguiente pregunta.
            Memory.clearCache()
        }

        Memory.clearCache()

        let maximoSalida = modeloSeleccionado.maximoTokens(
            requiereRazonamiento: requiereRazonamiento)
        let modo = requiereRazonamiento ? "/think" : "/no_think"
        let maximoEntrada = Self.contextoTotalSeguro
            - maximoSalida - Self.reservaPlantillaTokens
        let solicitudSegura = try await Self.ajustarSolicitud(
            solicitud,
            instrucciones: instrucciones,
            modo: modo,
            maximoTokensEntrada: maximoEntrada,
            contenedor: contenedor)

        let parametros = GenerateParameters(
            maxTokens: maximoSalida,
            maxKVSize: modeloSeleccionado.maximoKV,
            kvBits: 8,
            temperature: requiereRazonamiento ? 0.45 : 0.30,
            topP: 0.88,
            topK: 20,
            minP: 0,
            repetitionPenalty: 1.05,
            repetitionContextSize: 64,
            prefillStepSize: 256)
        let sesion = ChatSession(
            contenedor,
            instructions: instrucciones,
            generateParameters: parametros)
        let inicio = Date()
        var partes: [String] = []
        var informacion: GenerateCompletionInfo?
        do {
            for try await evento in sesion.streamDetails(
                to: "\(solicitudSegura)\n\n\(modo)") {
                try Task.checkCancellation()
                switch evento {
                case .chunk(let fragmento):
                    partes.append(fragmento)
                case .info(let detalle):
                    informacion = detalle
                case .toolCall:
                    break
                }
            }
            try Task.checkCancellation()
            // La generación interna y su KV cache deben haber terminado antes
            // de soltar el ModelContainer o permitir que Apple reserve RAM.
            await sesion.synchronize()
            await sesion.clear()
        } catch {
            await sesion.synchronize()
            await sesion.clear()
            throw error
        }
        let texto = partes.joined()
        let segundos = max(0.001, Date().timeIntervalSince(inicio))
        let cantidadTokens: Int
        if let informacion {
            cantidadTokens = informacion.generationTokenCount
        } else {
            let tokenizador = await contenedor.tokenizer
            cantidadTokens = tokenizador.encode(text: texto).count
        }
        let memoria = Memory.snapshot()
        metricasUltimaRespuesta = MetricasQwen(
            segundos: segundos,
            tokensGenerados: cantidadTokens,
            temperatura: Self.descripcionTermica(ProcessInfo.processInfo.thermalState),
            picoMemoriaMLX: memoria.peakMemory)
        let limpio = Self.limpiarRazonamientoInterno(texto)
        guard !limpio.isEmpty else { throw ErrorQwen.respuestaVacia }
        return limpio
    }

    private static func ajustarSolicitud(
        _ solicitud: String,
        instrucciones: String,
        modo: String,
        maximoTokensEntrada: Int,
        contenedor: ModelContainer
    ) async throws -> String {
        var resultado = solicitud
        for _ in 0..<4 {
            let cantidad = try await cantidadTokensDelPrompt(
                contenedor: contenedor,
                instrucciones: instrucciones,
                solicitud: "\(resultado)\n\n\(modo)")
            if cantidad <= maximoTokensEntrada { return resultado }

            let tokenizador = await contenedor.tokenizer
            let tokens = tokenizador.encode(
                text: resultado, addSpecialTokens: false)
            let exceso = cantidad - maximoTokensEntrada
            let objetivo = max(256, tokens.count - exceso - 64)
            guard objetivo < tokens.count else { break }
            resultado = recortarCentro(
                tokens: tokens, tokenizador: tokenizador,
                maximo: objetivo)
        }
        let cantidadFinal = try await cantidadTokensDelPrompt(
            contenedor: contenedor,
            instrucciones: instrucciones,
            solicitud: "\(resultado)\n\n\(modo)")
        guard cantidadFinal <= maximoTokensEntrada else {
            throw ErrorQwen.solicitudDemasiadoLarga
        }
        return resultado
    }

    private static func cantidadTokensDelPrompt(
        contenedor: ModelContainer,
        instrucciones: String,
        solicitud: String
    ) async throws -> Int {
        let entrada = try await contenedor.prepare(input: UserInput(chat: [
            .system(instrucciones),
            .user(solicitud)
        ]))
        return entrada.text.tokens.size
    }

    private static func recortarCentro(
        tokens: [Int],
        tokenizador: any MLXLMCommon.Tokenizer,
        maximo: Int
    ) -> String {
        guard tokens.count > maximo else {
            return tokenizador.decode(
                tokenIds: tokens, skipSpecialTokens: true)
        }
        let cabeza = max(1, Int(Double(maximo) * 0.72))
        let cola = max(1, maximo - cabeza)
        let inicial = tokenizador.decode(
            tokenIds: Array(tokens.prefix(cabeza)),
            skipSpecialTokens: true)
        let final = tokenizador.decode(
            tokenIds: Array(tokens.suffix(cola)),
            skipSpecialTokens: true)
        return inicial
            + "\n\n[Se omitió contexto secundario para proteger la memoria]\n\n"
            + final
    }

    /// Borra solo la carpeta dedicada a Qwen. Los datos financieros, PDFs y
    /// respaldos de Claro viven en contenedores distintos y no se tocan.
    func eliminarModelo() throws {
        guard !operacionEnCurso, !generandoRespuesta else { return }
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
        bytesDescargados = 0
        bytesTotales = 0
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
        return snapshotTieneArchivosEsenciales(en: candidato)
            ? candidato : nil
    }

    private static func directorioDelModelo(_ modelo: ModeloQwen) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClaroModelos", isDirectory: true)
            .appendingPathComponent(modelo.nombreDirectorio, isDirectory: true)
    }

    private static func eliminarCache8BRetirada() {
        let caches = FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask)[0].standardizedFileURL
        let raiz = caches.appendingPathComponent(
            "ClaroModelos", isDirectory: true).standardizedFileURL
        let objetivo = raiz.appendingPathComponent(
            nombreDirectorio8BRetirado, isDirectory: true).standardizedFileURL
        guard objetivo.deletingLastPathComponent() == raiz,
              objetivo.lastPathComponent == nombreDirectorio8BRetirado,
              FileManager.default.fileExists(atPath: objetivo.path) else { return }
        try? FileManager.default.removeItem(at: objetivo)
    }

    private static func snapshotTieneArchivosEsenciales(
        en directorio: URL
    ) -> Bool {
        let fm = FileManager.default
        let config = directorio.appendingPathComponent("config.json")
        let tokenizer = directorio.appendingPathComponent("tokenizer.json")
        guard fm.fileExists(atPath: config.path),
              fm.fileExists(atPath: tokenizer.path) else { return false }
        guard let enumerador = FileManager.default.enumerator(
            at: directorio,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]) else { return false }
        var bytesDePesos: Int64 = 0
        for case let archivo as URL in enumerador
            where archivo.pathExtension == "safetensors" {
            // Hugging Face puede representar el snapshot con enlaces a su
            // almacén de blobs. Se mide el destino real, no el tamaño del
            // enlace, para no pedir una descarga que ya está completa.
            let archivoReal = archivo.resolvingSymlinksInPath()
            let valores = try? archivoReal.resourceValues(
                forKeys: [.isRegularFileKey, .fileSizeKey])
            if valores?.isRegularFile == true {
                bytesDePesos += Int64(valores?.fileSize ?? 0)
            }
        }
        // Evita declarar «listo» un snapshot interrumpido que solo alcanzó a
        // escribir el primer fragmento. El 4B cuantizado completo supera con
        // margen este piso, sin depender de un número exacto de shards.
        return bytesDePesos >= 1_500_000_000
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

    private static func esCancelacionDeRed(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
            && nsError.code == NSURLErrorCancelled
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
    case respuestaEnCurso
    case respuestaVacia
    case solicitudDemasiadoLarga
    case rutaNoSegura
    case espacioInsuficiente(requerido: Int64, disponible: Int64)

    var errorDescription: String? {
        switch self {
        case .modeloNoDisponible:
            return "Qwen no está preparado. Toca Preparar e inténtalo de nuevo."
        case .respuestaEnCurso:
            return "Qwen todavía está terminando la respuesta anterior."
        case .respuestaVacia: return "Qwen no produjo una respuesta."
        case .solicitudDemasiadoLarga:
            return "La pregunta contiene demasiado texto para procesarla de forma segura en el iPhone."
        case .rutaNoSegura: return "No se pudo verificar la carpeta del modelo."
        case .espacioInsuficiente(let requerido, let disponible):
            let formato = ByteCountFormatter()
            formato.countStyle = .file
            return "Falta espacio para descargar Qwen: necesita aproximadamente \(formato.string(fromByteCount: requerido)) y hay \(formato.string(fromByteCount: disponible)) disponibles."
        }
    }
}
