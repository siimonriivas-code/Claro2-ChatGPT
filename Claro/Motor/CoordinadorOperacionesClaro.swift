//
//  CoordinadorOperacionesClaro.swift
//  Claro
//
//  Punto único para finalizar una operación financiera: guarda, actualiza
//  recordatorios y solicita el respaldo remoto sin duplicar esa lógica en
//  cada pantalla.
//

import Foundation
import SwiftData

@MainActor
enum CoordinadorOperacionesClaro {
    @discardableResult
    static func prepararCambioCritico(
        contexto: ModelContext,
        motivo: String
    ) throws -> PuntoRecuperacionClaro? {
        try AdministradorProteccionDatos.crearPunto(
            contexto: contexto,
            motivo: motivo
        )
    }

    static func guardar(contexto: ModelContext) throws {
        try contexto.save()
        actualizarServicios(contexto: contexto)
    }

    static func actualizarServicios(contexto: ModelContext) {
        if UserDefaults.standard.bool(forKey: "notificacionesActivadas") {
            let tarjetas = (try? contexto.fetch(FetchDescriptor<TarjetaCredito>()))?
                .filter { !$0.archivada } ?? []
            let personas = (try? contexto.fetch(FetchDescriptor<Persona>()))?
                .filter { !$0.archivada } ?? []
            ProgramadorDeNotificaciones.reprogramar(
                tarjetas: tarjetas,
                personas: personas
            )
        }

        let respaldoActivo = UserDefaults.standard.object(
            forKey: "respaldoICloudAutomatico"
        ) == nil || UserDefaults.standard.bool(forKey: "respaldoICloudAutomatico")
        if respaldoActivo {
            Task { @MainActor in
                await AdministradorICloud.respaldarSiCorresponde(
                    contexto: contexto,
                    intervaloMinimo: 0
                )
            }
        }
    }
}
