//
//  AdministradorClaroFamilia.swift
//  Claro
//
//  Colaboración familiar mediante CKShare, separada por persona.
//  SwiftData continúa siendo exclusivamente local: CloudKit solo contiene
//  el desglose que el propietario decide compartir y los pagos reportados.
//

import CloudKit
import Foundation

enum EstadoActualizacionFamiliar: String, Codable {
    case pendiente
    case confirmada
    case descartada
}

struct ActualizacionFamiliar: Codable, Hashable, Identifiable {
    let id: UUID
    let monto: Double
    let fecha: Date
    let concepto: String
    let autor: String
    let creadoEl: Date
    var estado: EstadoActualizacionFamiliar

    init(
        id: UUID = UUID(),
        monto: Double,
        fecha: Date,
        concepto: String,
        autor: String,
        creadoEl: Date = .now,
        estado: EstadoActualizacionFamiliar = .pendiente
    ) {
        self.id = id
        self.monto = monto.redondeadoAMoneda
        self.fecha = fecha
        self.concepto = concepto
        self.autor = autor
        self.creadoEl = creadoEl
        self.estado = estado
    }
}

struct LocalizadorVinculoFamiliar: Codable, Hashable {
    let recordName: String
    let zoneName: String
    let ownerName: String

    var recordID: CKRecord.ID {
        CKRecord.ID(
            recordName: recordName,
            zoneID: CKRecordZone.ID(
                zoneName: zoneName,
                ownerName: ownerName
            )
        )
    }
}

struct VinculoClaroFamilia: Identifiable {
    let localizador: LocalizadorVinculoFamiliar
    let personaClave: String
    let personaNombre: String
    let saldoPendiente: Double
    let resumenCobro: String
    let actualizadoEl: Date
    let esPropietario: Bool
    let participantesAceptados: Int
    let actualizaciones: [ActualizacionFamiliar]
    let share: CKShare?

    var id: String {
        [
            localizador.ownerName,
            localizador.zoneName,
            localizador.recordName
        ].joined(separator: "/")
    }

    var pagosPendientes: [ActualizacionFamiliar] {
        actualizaciones
            .filter { $0.estado == .pendiente }
            .sorted { $0.creadoEl > $1.creadoEl }
    }
}

extension Notification.Name {
    static let claroFamiliaCambio = Notification.Name(
        "ClaroFamiliaCambio"
    )
}

@MainActor
enum AdministradorClaroFamilia {
    private static let zonaNombre = "ClaroFamilia"
    private static let tipoVinculo = "VinculoClaroFamilia"
    private static let claveLocalizadores = "vinculosFamiliaAceptados"
    private static let versionEsquema: Int64 = 1

    enum ErrorFamilia: LocalizedError {
        case cuentaNoDisponible
        case vinculoInexistente
        case respuestaInvalida
        case conflictoPersistente

        var errorDescription: String? {
            switch self {
            case .cuentaNoDisponible:
                "iCloud no está disponible. Cada integrante necesita iniciar sesión con su propia cuenta de iCloud."
            case .vinculoInexistente:
                "Esta conexión familiar ya no está disponible."
            case .respuestaInvalida:
                "iCloud devolvió una respuesta incompleta. Inténtalo nuevamente."
            case .conflictoPersistente:
                "Otra persona actualizó esta conexión al mismo tiempo. Vuelve a intentarlo."
            }
        }
    }

    static func prepararInvitacion(
        persona: Persona,
        propietarioNombre: String
    ) async throws -> VinculoClaroFamilia {
        try await verificarCuenta()
        let base = CKContainer.default().privateCloudDatabase
        let zonaID = CKRecordZone.ID(
            zoneName: zonaNombre,
            ownerName: CKCurrentUserDefaultName
        )
        try await asegurarZona(zonaID, en: base)

        let registroID = CKRecord.ID(
            recordName: nombreRegistro(persona.identificadorNotificaciones),
            zoneID: zonaID
        )
        let registro: CKRecord
        do {
            registro = try await base.record(for: registroID)
        } catch let error as CKError where error.code == .unknownItem {
            registro = CKRecord(
                recordType: tipoVinculo,
                recordID: registroID
            )
        }
        configurar(
            registro,
            persona: persona,
            propietarioNombre: propietarioNombre
        )

        let share: CKShare
        if let referencia = registro.share,
           let existente = try await base.record(
               for: referencia.recordID
           ) as? CKShare {
            _ = try await base.save(registro)
            share = existente
        } else {
            let nuevo = CKShare(rootRecord: registro)
            nuevo.publicPermission = .none
            nuevo[CKShare.SystemFieldKey.title] =
                "Claro Familia · \(persona.nombre)" as CKRecordValue
            nuevo[CKShare.SystemFieldKey.shareType] =
                "com.simonrivas.claro.familia" as CKRecordValue

            let resultado = try await base.modifyRecords(
                saving: [registro, nuevo],
                deleting: [],
                savePolicy: .changedKeys,
                atomically: true
            )
            try verificarGuardado(
                [registro.recordID, nuevo.recordID],
                resultados: resultado.saveResults
            )
            share = (try resultado.saveResults[nuevo.recordID]?.get()
                     as? CKShare) ?? nuevo
        }

        let actualizado = try await base.record(for: registroID)
        return try construir(
            registro: actualizado,
            share: share,
            esPropietario: true
        )
    }

    static func vinculoPropio(
        para persona: Persona,
        propietarioNombre: String
    ) async throws -> VinculoClaroFamilia? {
        try await verificarCuenta()
        let base = CKContainer.default().privateCloudDatabase
        let zonaID = CKRecordZone.ID(
            zoneName: zonaNombre,
            ownerName: CKCurrentUserDefaultName
        )
        let id = CKRecord.ID(
            recordName: nombreRegistro(persona.identificadorNotificaciones),
            zoneID: zonaID
        )
        let registro: CKRecord
        do {
            registro = try await base.record(for: id)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }

        configurar(
            registro,
            persona: persona,
            propietarioNombre: propietarioNombre
        )
        let guardado = try await base.save(registro)
        let share: CKShare?
        if let referencia = guardado.share {
            share = try await base.record(
                for: referencia.recordID
            ) as? CKShare
        } else {
            share = nil
        }
        return try construir(
            registro: guardado,
            share: share,
            esPropietario: true
        )
    }

    static func vinculosCompartidosConmigo() async throws
        -> [VinculoClaroFamilia] {
        try await verificarCuenta()
        let base = CKContainer.default().sharedCloudDatabase
        var resultado: [VinculoClaroFamilia] = []

        for localizador in localizadoresAceptados() {
            do {
                let registro = try await base.record(
                    for: localizador.recordID
                )
                resultado.append(try construir(
                    registro: registro,
                    share: nil,
                    esPropietario: false
                ))
            } catch let error as CKError where error.code == .unknownItem {
                quitarLocalizador(localizador)
            }
        }
        return resultado.sorted { $0.personaNombre < $1.personaNombre }
    }

    static func reportarPago(
        en vinculo: VinculoClaroFamilia,
        monto: Double,
        fecha: Date,
        concepto: String,
        autor: String
    ) async throws {
        let limpio = concepto.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let nombre = autor.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let actualizacion = ActualizacionFamiliar(
            monto: monto,
            fecha: fecha,
            concepto: limpio.isEmpty ? "Pago enviado" : limpio,
            autor: nombre.isEmpty ? vinculo.personaNombre : nombre
        )
        try await mutarActualizaciones(en: vinculo) {
            $0.append(actualizacion)
        }
    }

    static func cambiarEstado(
        de actualizacion: ActualizacionFamiliar,
        a estado: EstadoActualizacionFamiliar,
        en vinculo: VinculoClaroFamilia
    ) async throws {
        try await mutarActualizaciones(en: vinculo) { elementos in
            guard let indice = elementos.firstIndex(
                where: { $0.id == actualizacion.id }
            ) else { return }
            elementos[indice].estado = estado
        }
    }

    static func aceptar(_ metadata: CKShare.Metadata) async {
        do {
            let contenedor = CKContainer(
                identifier: metadata.containerIdentifier
            )
            if metadata.participantStatus == .pending {
                _ = try await contenedor.accept(metadata)
            }
            if let raiz = metadata.hierarchicalRootRecordID {
                guardarLocalizador(LocalizadorVinculoFamiliar(
                    recordName: raiz.recordName,
                    zoneName: raiz.zoneID.zoneName,
                    ownerName: raiz.zoneID.ownerName
                ))
            }
            UserDefaults.standard.removeObject(
                forKey: "ultimoErrorClaroFamilia"
            )
            NotificationCenter.default.post(
                name: .claroFamiliaCambio,
                object: nil
            )
        } catch {
            UserDefaults.standard.set(
                error.localizedDescription,
                forKey: "ultimoErrorClaroFamilia"
            )
            NotificationCenter.default.post(
                name: .claroFamiliaCambio,
                object: nil
            )
        }
    }

    // MARK: - CloudKit

    private static func verificarCuenta() async throws {
        guard try await CKContainer.default().accountStatus() == .available
        else { throw ErrorFamilia.cuentaNoDisponible }
    }

    private static func asegurarZona(
        _ id: CKRecordZone.ID,
        en base: CKDatabase
    ) async throws {
        do {
            _ = try await base.recordZone(for: id)
        } catch let error as CKError where error.code == .zoneNotFound
                    || error.code == .unknownItem {
            _ = try await base.save(CKRecordZone(zoneID: id))
        }
    }

    private static func configurar(
        _ registro: CKRecord,
        persona: Persona,
        propietarioNombre: String
    ) {
        registro["version"] = versionEsquema as CKRecordValue
        registro["personaClave"] =
            persona.identificadorNotificaciones as CKRecordValue
        registro["personaNombre"] = persona.nombre as CKRecordValue
        registro["propietarioNombre"] =
            propietarioNombre.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) as CKRecordValue
        registro["actualizadoEl"] = Date.now as CKRecordValue
        registro.encryptedValues["saldoPendiente"] =
            persona.saldoPendiente.redondeadoAMoneda as CKRecordValue
        registro.encryptedValues["resumenCobro"] =
            GeneradorResumenCobro.texto(para: persona) as CKRecordValue
        if registro.encryptedValues["actualizaciones"] == nil,
           let datos = try? JSONEncoder().encode(
               [ActualizacionFamiliar]()
           ) {
            registro.encryptedValues["actualizaciones"] =
                datos as CKRecordValue
        }
    }

    private static func construir(
        registro: CKRecord,
        share: CKShare?,
        esPropietario: Bool
    ) throws -> VinculoClaroFamilia {
        guard let clave = registro["personaClave"] as? String,
              let nombre = registro["personaNombre"] as? String else {
            throw ErrorFamilia.respuestaInvalida
        }
        let localizador = LocalizadorVinculoFamiliar(
            recordName: registro.recordID.recordName,
            zoneName: registro.recordID.zoneID.zoneName,
            ownerName: registro.recordID.zoneID.ownerName
        )
        let datos = registro.encryptedValues["actualizaciones"] as? Data
        let actualizaciones = datos.flatMap {
            try? JSONDecoder().decode(
                [ActualizacionFamiliar].self,
                from: $0
            )
        } ?? []
        let aceptados = share?.participants.filter {
            $0.role != .owner && $0.acceptanceStatus == .accepted
        }.count ?? 0

        return VinculoClaroFamilia(
            localizador: localizador,
            personaClave: clave,
            personaNombre: nombre,
            saldoPendiente:
                (registro.encryptedValues["saldoPendiente"]
                    as? NSNumber)?.doubleValue ?? 0,
            resumenCobro:
                registro.encryptedValues["resumenCobro"] as? String ?? "",
            actualizadoEl:
                registro["actualizadoEl"] as? Date
                    ?? registro.modificationDate
                    ?? .distantPast,
            esPropietario: esPropietario,
            participantesAceptados: aceptados,
            actualizaciones: actualizaciones,
            share: share
        )
    }

    private static func mutarActualizaciones(
        en vinculo: VinculoClaroFamilia,
        cambio: (inout [ActualizacionFamiliar]) -> Void
    ) async throws {
        let base = vinculo.esPropietario
            ? CKContainer.default().privateCloudDatabase
            : CKContainer.default().sharedCloudDatabase

        for _ in 0..<3 {
            let registro = try await base.record(
                for: vinculo.localizador.recordID
            )
            let datos = registro.encryptedValues["actualizaciones"] as? Data
            var elementos = datos.flatMap {
                try? JSONDecoder().decode(
                    [ActualizacionFamiliar].self,
                    from: $0
                )
            } ?? []
            cambio(&elementos)
            registro.encryptedValues["actualizaciones"] =
                try JSONEncoder().encode(elementos) as CKRecordValue
            registro["actualizadoEl"] = Date.now as CKRecordValue
            do {
                _ = try await base.save(registro)
                NotificationCenter.default.post(
                    name: .claroFamiliaCambio,
                    object: nil
                )
                return
            } catch let error as CKError
                where error.code == .serverRecordChanged {
                continue
            }
        }
        throw ErrorFamilia.conflictoPersistente
    }

    private static func verificarGuardado(
        _ ids: [CKRecord.ID],
        resultados: [CKRecord.ID: Result<CKRecord, Error>]
    ) throws {
        for id in ids {
            guard let resultado = resultados[id] else {
                throw ErrorFamilia.respuestaInvalida
            }
            _ = try resultado.get()
        }
    }

    // MARK: - Localizadores aceptados

    private static func nombreRegistro(_ clave: String) -> String {
        let permitido = clave.unicodeScalars.map { escalar -> Character in
            CharacterSet.alphanumerics.contains(escalar)
                ? Character(String(escalar))
                : "-"
        }
        return "familia-" + String(permitido)
    }

    private static func localizadoresAceptados()
        -> [LocalizadorVinculoFamiliar] {
        let local = decodificarLocalizadores(
            UserDefaults.standard.data(forKey: claveLocalizadores)
        )
        let nube = decodificarLocalizadores(
            NSUbiquitousKeyValueStore.default.data(
                forKey: claveLocalizadores
            )
        )
        return Array(Set(local + nube))
    }

    private static func guardarLocalizador(
        _ localizador: LocalizadorVinculoFamiliar
    ) {
        var elementos = localizadoresAceptados()
        guard !elementos.contains(localizador) else { return }
        elementos.append(localizador)
        guardarLocalizadores(elementos)
    }

    private static func quitarLocalizador(
        _ localizador: LocalizadorVinculoFamiliar
    ) {
        guardarLocalizadores(
            localizadoresAceptados().filter { $0 != localizador }
        )
    }

    private static func guardarLocalizadores(
        _ elementos: [LocalizadorVinculoFamiliar]
    ) {
        guard let datos = try? JSONEncoder().encode(elementos) else {
            return
        }
        UserDefaults.standard.set(datos, forKey: claveLocalizadores)
        NSUbiquitousKeyValueStore.default.set(
            datos,
            forKey: claveLocalizadores
        )
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    private static func decodificarLocalizadores(_ datos: Data?)
        -> [LocalizadorVinculoFamiliar] {
        guard let datos else { return [] }
        return (try? JSONDecoder().decode(
            [LocalizadorVinculoFamiliar].self,
            from: datos
        )) ?? []
    }
}
