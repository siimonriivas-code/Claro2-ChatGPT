//
//  AdministradorICloud.swift
//  Claro
//
//  Respaldo automático completo en la base PRIVADA de CloudKit. Se guarda
//  el mismo documento versionado que usa la exportación manual; no se suben
//  los PDF originales ni el modelo local de IA.
//

import CloudKit
import Foundation
import SwiftData

struct PuntoRespaldoICloud: Identifiable, Hashable {
    let id: String
    let creadoEl: Date
    let totalRegistros: Int
}

@MainActor
enum AdministradorICloud {
    static let claveUltimoRespaldo = "ultimoRespaldoICloud"
    private static let tipoRegistro = "RespaldoClaro"
    private static let identificadorRegistro = CKRecord.ID(
        recordName: "respaldo-principal")
    private static let cantidadGeneraciones = 10
    private static let claveSiguienteGeneracion = "siguienteGeneracionICloud"

    enum ErrorICloud: LocalizedError {
        case cuentaNoDisponible
        case respaldoInexistente
        case archivoInvalido
        case sinDatosDelUsuario
        case reduccionInesperada

        var errorDescription: String? {
            switch self {
            case .cuentaNoDisponible:
                "iCloud no está disponible. Revisa que hayas iniciado sesión en iCloud y que iCloud Drive esté activo."
            case .respaldoInexistente:
                "Todavía no existe un respaldo de Claro en tu iCloud."
            case .archivoInvalido:
                "El respaldo de iCloud está incompleto o no se puede leer."
            case .sinDatosDelUsuario:
                "Claro no reemplazó el respaldo de iCloud porque esta base local no contiene todavía información financiera."
            case .reduccionInesperada:
                "Claro no reemplazó automáticamente un respaldo más completo por otro mucho menor. Revisa tus datos y usa “Respaldar ahora” si la reducción fue intencional."
            }
        }
    }

    static func estadoDeCuenta() async -> CKAccountStatus {
        (try? await CKContainer.default().accountStatus()) ?? .couldNotDetermine
    }

    @discardableResult
    static func respaldar(
        contexto: ModelContext,
        permitirReduccion: Bool = false
    ) async throws -> Date {
        guard await estadoDeCuenta() == .available else {
            throw ErrorICloud.cuentaNoDisponible
        }

        let respaldo = try AdministradorRespaldos.crear(contexto: contexto)
        guard contieneDatosDelUsuario(respaldo) else {
            // Protección anti-base-vacía: una instalación recién abierta o
            // una base equivocada jamás puede pisar un respaldo útil.
            throw ErrorICloud.sinDatosDelUsuario
        }
        let datos = try AdministradorRespaldos.codificar(respaldo)
        let archivo = FileManager.default.temporaryDirectory
            .appendingPathComponent("Claro-\(UUID().uuidString).claro")
        try datos.write(to: archivo, options: [.atomic, .completeFileProtection])
        defer { try? FileManager.default.removeItem(at: archivo) }

        let base = CKContainer.default().privateCloudDatabase
        let registro: CKRecord
        do {
            registro = try await base.record(for: identificadorRegistro)
        } catch let error as CKError where error.code == .unknownItem {
            registro = CKRecord(recordType: tipoRegistro,
                                recordID: identificadorRegistro)
        }

        if !permitirReduccion,
           let anteriores = registro["registros"] as? Int64,
           anteriores >= 20,
           respaldo.totalRegistros < Int(anteriores) / 2 {
            throw ErrorICloud.reduccionInesperada
        }

        let fecha = Date.now
        let indice = UserDefaults.standard.integer(
            forKey: claveSiguienteGeneracion
        ) % cantidadGeneraciones
        let identificadorHistorial = CKRecord.ID(
            recordName: "respaldo-historial-\(indice)"
        )
        let historial: CKRecord
        do {
            historial = try await base.record(for: identificadorHistorial)
        } catch let error as CKError where error.code == .unknownItem {
            historial = CKRecord(
                recordType: tipoRegistro,
                recordID: identificadorHistorial
            )
        }

        configurar(historial, archivo: archivo, respaldo: respaldo, fecha: fecha)
        _ = try await base.save(historial)
        UserDefaults.standard.set(
            (indice + 1) % cantidadGeneraciones,
            forKey: claveSiguienteGeneracion
        )

        configurar(registro, archivo: archivo, respaldo: respaldo, fecha: fecha)
        _ = try await base.save(registro)
        UserDefaults.standard.set(fecha.timeIntervalSince1970,
                                  forKey: claveUltimoRespaldo)
        return fecha
    }

    /// Se usa al abrir/cerrar la app. Evita tráfico repetido si no ha pasado
    /// el intervalo; las operaciones importantes pueden forzar intervalo 0.
    static func respaldarSiCorresponde(
        contexto: ModelContext,
        intervaloMinimo: TimeInterval = 6 * 60 * 60
    ) async {
        guard UserDefaults.standard.object(forKey: "respaldoICloudAutomatico") == nil
                || UserDefaults.standard.bool(forKey: "respaldoICloudAutomatico")
        else { return }

        let ultimo = UserDefaults.standard.double(forKey: claveUltimoRespaldo)
        guard ultimo == 0
                || Date.now.timeIntervalSince1970 - ultimo >= intervaloMinimo
        else { return }
        _ = try? await respaldar(contexto: contexto)
    }

    static func descargarRespaldo() async throws -> RespaldoClaro {
        guard await estadoDeCuenta() == .available else {
            throw ErrorICloud.cuentaNoDisponible
        }
        let base = CKContainer.default().privateCloudDatabase
        let registro: CKRecord
        do {
            registro = try await base.record(for: identificadorRegistro)
        } catch let error as CKError where error.code == .unknownItem {
            throw ErrorICloud.respaldoInexistente
        }
        return try decodificar(registro)
    }

    static func listarGeneraciones() async throws -> [PuntoRespaldoICloud] {
        guard await estadoDeCuenta() == .available else {
            throw ErrorICloud.cuentaNoDisponible
        }
        let base = CKContainer.default().privateCloudDatabase
        var puntos: [PuntoRespaldoICloud] = []
        for indice in 0..<cantidadGeneraciones {
            let id = CKRecord.ID(recordName: "respaldo-historial-\(indice)")
            guard let registro = try? await base.record(for: id) else { continue }
            let fecha = registro["creadoEl"] as? Date
                ?? registro.modificationDate
                ?? .distantPast
            let total = (registro["registros"] as? Int64).map(Int.init) ?? 0
            puntos.append(PuntoRespaldoICloud(
                id: id.recordName,
                creadoEl: fecha,
                totalRegistros: total
            ))
        }
        return puntos.sorted { $0.creadoEl > $1.creadoEl }
    }

    static func descargar(_ punto: PuntoRespaldoICloud) async throws -> RespaldoClaro {
        guard await estadoDeCuenta() == .available else {
            throw ErrorICloud.cuentaNoDisponible
        }
        let registro = try await CKContainer.default().privateCloudDatabase
            .record(for: CKRecord.ID(recordName: punto.id))
        return try decodificar(registro)
    }

    static func fechaRemota() async throws -> Date? {
        guard await estadoDeCuenta() == .available else {
            throw ErrorICloud.cuentaNoDisponible
        }
        do {
            let registro = try await CKContainer.default().privateCloudDatabase
                .record(for: identificadorRegistro)
            return registro["creadoEl"] as? Date ?? registro.modificationDate
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
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
            || !(respaldo.conversaciones?.isEmpty ?? true)
            || !(respaldo.gruposGastos?.isEmpty ?? true)
    }

    private static func configurar(
        _ registro: CKRecord,
        archivo: URL,
        respaldo: RespaldoClaro,
        fecha: Date
    ) {
        registro["archivo"] = CKAsset(fileURL: archivo)
        registro["creadoEl"] = fecha as CKRecordValue
        registro["version"] = respaldo.version as CKRecordValue
        registro["registros"] = respaldo.totalRegistros as CKRecordValue
    }

    private static func decodificar(_ registro: CKRecord) throws -> RespaldoClaro {
        guard let recurso = registro["archivo"] as? CKAsset,
              let url = recurso.fileURL,
              let datos = try? Data(contentsOf: url) else {
            throw ErrorICloud.archivoInvalido
        }
        return try AdministradorRespaldos.decodificar(datos)
    }
}
