//
//  AdministradorImportaciones.swift
//  Claro
//
//  Deshace de forma atómica un lote creado por la importación de un PDF.
//

import Foundation
import SwiftData

enum AdministradorImportaciones {

    static func deshacer(id: UUID, contexto: ModelContext) throws {
        let mensualidades = try contexto.fetch(FetchDescriptor<MensualidadMSI>())
        let participaciones = try contexto.fetch(FetchDescriptor<Participacion>())
        let planes = try contexto.fetch(FetchDescriptor<PlanMSI>())
        let movimientos = try contexto.fetch(FetchDescriptor<Movimiento>())
        let estados = try contexto.fetch(FetchDescriptor<EstadoDeCuenta>())

        // Mensualidades de planes que ya existían antes de la importación:
        // vuelven a quedar pendientes. Las de planes nuevos desaparecerán
        // junto con su plan por la relación en cascada.
        for mensualidad in mensualidades
            where mensualidad.importacionID == id
                && mensualidad.plan?.importacionID != id {
            mensualidad.fechaGeneracion = nil
            mensualidad.estadoDeCuenta = nil
            mensualidad.importacionID = nil
            mensualidad.cubierta = false
        }

        // Una mensualidad de un plan ya existente puede haber agregado la
        // parte compartida de ese mes sin crear un movimiento nuevo.
        for parte in participaciones where parte.importacionID == id {
            contexto.delete(parte)
        }

        for movimiento in movimientos where movimiento.importacionID == id {
            if let compartida = movimiento.compraCompartida {
                for parte in compartida.participaciones { contexto.delete(parte) }
                movimiento.compraCompartida = nil
                contexto.delete(compartida)
            }
            contexto.delete(movimiento)
        }

        for plan in planes where plan.importacionID == id {
            contexto.delete(plan)
        }

        for estado in estados where estado.importacionID == id {
            contexto.delete(estado)
        }

        try contexto.save()
    }
}
