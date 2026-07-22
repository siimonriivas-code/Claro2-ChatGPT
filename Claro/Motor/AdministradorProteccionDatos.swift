//
//  AdministradorProteccionDatos.swift
//  Claro
//
//  Mantiene puntos de recuperación locales, independientes de la base de
//  SwiftData y del respaldo remoto. Se crean antes de operaciones críticas.
//

import Foundation
import SwiftData

struct PuntoRecuperacionClaro: Identifiable, Hashable {
    var id: URL { archivo }
    let archivo: URL
    let creadoEl: Date
    let motivo: String
    let totalRegistros: Int
}

@MainActor
enum AdministradorProteccionDatos {
    private struct Documento: Codable {
        let version: Int
        let creadoEl: Date
        let motivo: String
        let respaldo: RespaldoClaro
    }

    private static let versionDocumento = 1
    private static let maximoPuntos = 12
    private static let claveUltimoPuntoAutomatico = "ultimoPuntoRecuperacionLocal"

    enum ErrorProteccion: LocalizedError {
        case documentoInvalido
        case verificacionFallida

        var errorDescription: String? {
            switch self {
            case .documentoInvalido:
                "El punto de recuperación está incompleto o dañado."
            case .verificacionFallida:
                "No se pudo verificar el punto de recuperación. Tus datos no se modificaron."
            }
        }
    }

    @discardableResult
    static func crearPunto(
        contexto: ModelContext,
        motivo: String
    ) throws -> PuntoRecuperacionClaro? {
        let respaldo = try AdministradorRespaldos.crear(contexto: contexto)
        guard contieneDatosDelUsuario(respaldo) else { return nil }

        let fecha = Date.now
        let documento = Documento(
            version: versionDocumento,
            creadoEl: fecha,
            motivo: motivo,
            respaldo: respaldo
        )
        let datos = try codificar(documento)
        let directorio = try directorioRespaldos()
        let nombre = "recuperacion-\(Int(fecha.timeIntervalSince1970))-\(UUID().uuidString).claro"
        let archivo = directorio.appendingPathComponent(nombre)
        try datos.write(to: archivo, options: [.atomic, .completeFileProtection])

        // Nunca damos por bueno un respaldo que no podamos leer de vuelta.
        let verificado = try decodificar(Data(contentsOf: archivo))
        guard verificado.respaldo.totalRegistros == respaldo.totalRegistros else {
            try? FileManager.default.removeItem(at: archivo)
            throw ErrorProteccion.verificacionFallida
        }

        try recortarHistorial(en: directorio)
        return PuntoRecuperacionClaro(
            archivo: archivo,
            creadoEl: fecha,
            motivo: motivo,
            totalRegistros: respaldo.totalRegistros
        )
    }

    @discardableResult
    static func crearPuntoSiCorresponde(
        contexto: ModelContext,
        intervaloMinimo: TimeInterval = 24 * 60 * 60
    ) throws -> PuntoRecuperacionClaro? {
        let ultimo = UserDefaults.standard.double(
            forKey: claveUltimoPuntoAutomatico
        )
        guard ultimo == 0
                || Date.now.timeIntervalSince1970 - ultimo >= intervaloMinimo
        else { return nil }

        let punto = try crearPunto(
            contexto: contexto,
            motivo: "Protección diaria automática"
        )
        if punto != nil {
            UserDefaults.standard.set(
                Date.now.timeIntervalSince1970,
                forKey: claveUltimoPuntoAutomatico
            )
        }
        return punto
    }

    static func listarPuntos() throws -> [PuntoRecuperacionClaro] {
        let directorio = try directorioRespaldos()
        let archivos = try FileManager.default.contentsOfDirectory(
            at: directorio,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return archivos.compactMap { archivo in
            guard let datos = try? Data(contentsOf: archivo),
                  let documento = try? decodificar(datos) else { return nil }
            return PuntoRecuperacionClaro(
                archivo: archivo,
                creadoEl: documento.creadoEl,
                motivo: documento.motivo,
                totalRegistros: documento.respaldo.totalRegistros
            )
        }
        .sorted { $0.creadoEl > $1.creadoEl }
    }

    static func cargar(_ punto: PuntoRecuperacionClaro) throws -> RespaldoClaro {
        let documento = try decodificar(Data(contentsOf: punto.archivo))
        // Reutiliza la validación de compatibilidad del respaldo principal.
        let datos = try AdministradorRespaldos.codificar(documento.respaldo)
        return try AdministradorRespaldos.decodificar(datos)
    }

    static func eliminar(_ punto: PuntoRecuperacionClaro) throws {
        try FileManager.default.removeItem(at: punto.archivo)
    }

    private static func contieneDatosDelUsuario(_ respaldo: RespaldoClaro) -> Bool {
        !respaldo.bancos.isEmpty
            || !respaldo.cuentas.isEmpty
            || !respaldo.tarjetas.isEmpty
            || !respaldo.personas.isEmpty
            || !respaldo.deudas.isEmpty
            || !respaldo.estados.isEmpty
            || !respaldo.movimientos.isEmpty
            || !(respaldo.ingresosRecurrentes?.isEmpty ?? true)
            || !(respaldo.gruposGastos?.isEmpty ?? true)
    }

    private static func directorioRespaldos() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directorio = base
            .appendingPathComponent("Claro", isDirectory: true)
            .appendingPathComponent("Recuperacion", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directorio,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        return directorio
    }

    private static func recortarHistorial(en directorio: URL) throws {
        let puntos = try listarPuntos()
        for punto in puntos.dropFirst(maximoPuntos) {
            try? FileManager.default.removeItem(at: punto.archivo)
        }
    }

    private static func codificar(_ documento: Documento) throws -> Data {
        let codificador = JSONEncoder()
        codificador.dateEncodingStrategy = .iso8601
        codificador.outputFormatting = [.sortedKeys]
        return try codificador.encode(documento)
    }

    private static func decodificar(_ datos: Data) throws -> Documento {
        let decodificador = JSONDecoder()
        decodificador.dateDecodingStrategy = .iso8601
        let documento = try decodificador.decode(Documento.self, from: datos)
        guard documento.version == versionDocumento else {
            throw ErrorProteccion.documentoInvalido
        }
        return documento
    }
}
