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

@MainActor
enum AdministradorICloud {
    static let claveUltimoRespaldo = "ultimoRespaldoICloud"
    private static let tipoRegistro = "RespaldoClaro"
    private static let identificadorRegistro = CKRecord.ID(
        recordName: "respaldo-principal")

    enum ErrorICloud: LocalizedError {
        case cuentaNoDisponible
        case respaldoInexistente
        case archivoInvalido

        var errorDescription: String? {
            switch self {
            case .cuentaNoDisponible:
                "iCloud no está disponible. Revisa que hayas iniciado sesión en iCloud y que iCloud Drive esté activo."
            case .respaldoInexistente:
                "Todavía no existe un respaldo de Claro en tu iCloud."
            case .archivoInvalido:
                "El respaldo de iCloud está incompleto o no se puede leer."
            }
        }
    }

    static func estadoDeCuenta() async -> CKAccountStatus {
        (try? await CKContainer.default().accountStatus()) ?? .couldNotDetermine
    }

    @discardableResult
    static func respaldar(contexto: ModelContext) async throws -> Date {
        guard await estadoDeCuenta() == .available else {
            throw ErrorICloud.cuentaNoDisponible
        }

        let respaldo = try AdministradorRespaldos.crear(contexto: contexto)
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

        let fecha = Date.now
        registro["archivo"] = CKAsset(fileURL: archivo)
        registro["creadoEl"] = fecha as CKRecordValue
        registro["version"] = respaldo.version as CKRecordValue
        registro["registros"] = respaldo.totalRegistros as CKRecordValue
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
        guard let recurso = registro["archivo"] as? CKAsset,
              let url = recurso.fileURL,
              let datos = try? Data(contentsOf: url) else {
            throw ErrorICloud.archivoInvalido
        }
        return try AdministradorRespaldos.decodificar(datos)
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
}
