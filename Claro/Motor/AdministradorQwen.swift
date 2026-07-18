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
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

enum EstadoModeloQwen: Equatable {
    case noDescargado
    case descargando(Double)
    case cargando
    case listo
    case error(String)
}

@MainActor
final class AdministradorQwen: ObservableObject {
    static let shared = AdministradorQwen()

    static let modeloID = "Qwen/Qwen3-4B-MLX-4bit"
    static let nombreVisible = "Qwen3 4B"
    static let tamanoAproximado = "2.14 GB"

    @Published private(set) var estado: EstadoModeloQwen = .noDescargado

    private var contenedor: ModelContainer?
    private var operacionEnCurso = false

    private let cache: HubCache
    private let cliente: HubClient
    private let repo: Repo.ID

    private init() {
        let raiz = Self.directorioDelModelo
        let cache = HubCache(cacheDirectory: raiz)
        self.cache = cache
        self.cliente = HubClient(cache: cache)
        self.repo = Repo.ID(rawValue: Self.modeloID)!
        self.estado = Self.contienePesos(en: raiz) ? .cargando : .noDescargado
    }

    var estaDescargado: Bool {
        Self.contienePesos(en: Self.directorioDelModelo)
    }

    var estaListo: Bool {
        if case .listo = estado { return true }
        return false
    }

    var descripcionEstado: String {
        switch estado {
        case .noDescargado: return "Disponible para descargar"
        case .descargando(let avance): return "Descargando \(Int(avance * 100))%"
        case .cargando: return "Preparando el modelo"
        case .listo: return "Listo · todo se procesa en este iPhone"
        case .error(let mensaje): return mensaje
        }
    }

    /// Descarga desde Hugging Face exclusivamente los archivos públicos del
    /// modelo. Ningún dato de la app forma parte de esta solicitud.
    func descargarYCargar() async {
        guard !operacionEnCurso else { return }
        operacionEnCurso = true
        estado = .descargando(0)

        do {
            let snapshot = try await cliente.downloadSnapshot(
                of: repo,
                matching: ["*.json", "*.safetensors", "*.txt", "*.model"],
                maxConcurrentDownloads: 4) { [weak self] progreso in
                    guard let self else { return }
                    let fraccion = progreso.totalUnitCount > 0
                        ? progreso.fractionCompleted : 0
                    self.estado = .descargando(min(1, max(0, fraccion)))
                }
            estado = .cargando
            try await cargar(desde: snapshot)
            estado = .listo
        } catch {
            contenedor = nil
            estado = .error(Self.mensajeAmigable(error))
        }
        operacionEnCurso = false
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
            try await cargar(desde: snapshot)
            estado = .listo
        } catch {
            contenedor = nil
            estado = .error(Self.mensajeAmigable(error))
        }
        operacionEnCurso = false
    }

    /// Entrada deliberadamente limitada a texto ya calculado por el Motor
    /// financiero. Qwen no conoce ni puede modificar SwiftData.
    func responder(solicitud: String, requiereRazonamiento: Bool) async throws -> String {
        if contenedor == nil { await prepararSiEstaDescargado() }
        guard let contenedor else { throw ErrorQwen.modeloNoDisponible }

        let parametros = GenerateParameters(
            maxTokens: requiereRazonamiento ? 1_200 : 750,
            maxKVSize: 8_192,
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
        let texto = try await sesion.respond(to: "\(solicitud)\n\n\(modo)")
        let limpio = Self.limpiarRazonamientoInterno(texto)
        guard !limpio.isEmpty else { throw ErrorQwen.respuestaVacia }
        return limpio
    }

    /// Borra solo la carpeta dedicada a Qwen. Los datos financieros, PDFs y
    /// respaldos de Claro viven en contenedores distintos y no se tocan.
    func eliminarModelo() throws {
        guard !operacionEnCurso else { return }
        contenedor = nil
        let objetivo = Self.directorioDelModelo.standardizedFileURL
        let caches = FileManager.default.urls(for: .cachesDirectory,
                                              in: .userDomainMask)[0].standardizedFileURL
        guard objetivo.path.hasPrefix(caches.path + "/"),
              objetivo.lastPathComponent == "Qwen3-4B-MLX-4bit" else {
            throw ErrorQwen.rutaNoSegura
        }
        if FileManager.default.fileExists(atPath: objetivo.path) {
            try FileManager.default.removeItem(at: objetivo)
        }
        estado = .noDescargado
    }

    private func cargar(desde snapshot: URL) async throws {
        contenedor = try await LLMModelFactory.shared.loadContainer(
            from: snapshot,
            using: #huggingFaceTokenizerLoader())
    }

    private var directorioSnapshotActual: URL? {
        guard let revision = cache.resolveRevision(repo: repo, kind: .model,
                                                   ref: "main") else { return nil }
        let candidato = cache.snapshotsDirectory(repo: repo, kind: .model)
            .appendingPathComponent(revision, isDirectory: true)
        return FileManager.default.fileExists(atPath: candidato.path) ? candidato : nil
    }

    private static var directorioDelModelo: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClaroModelos", isDirectory: true)
            .appendingPathComponent("Qwen3-4B-MLX-4bit", isDirectory: true)
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
        if (error as NSError).domain == NSURLErrorDomain {
            return "No pude descargar Qwen. Revisa tu conexión e inténtalo de nuevo."
        }
        return "No pude preparar Qwen. Apple Intelligence seguirá disponible."
    }
}

private enum ErrorQwen: LocalizedError {
    case modeloNoDisponible
    case respuestaVacia
    case rutaNoSegura

    var errorDescription: String? {
        switch self {
        case .modeloNoDisponible: return "Qwen no está descargado."
        case .respuestaVacia: return "Qwen no produjo una respuesta."
        case .rutaNoSegura: return "No se pudo verificar la carpeta del modelo."
        }
    }
}
