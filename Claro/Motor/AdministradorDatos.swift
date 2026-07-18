//
//  AdministradorDatos.swift
//  Claro
//

import Foundation
import SwiftData

enum AdministradorDatos {
    static func borrarTodo(contexto: ModelContext,
                           restaurarCategorias: Bool) throws {
        try contexto.delete(model: RegistroDeCambio.self)
        try contexto.delete(model: Participacion.self)
        try contexto.delete(model: CompraCompartida.self)
        try contexto.delete(model: MensualidadMSI.self)
        try contexto.delete(model: PlanMSI.self)
        try contexto.delete(model: EstadoDeCuenta.self)
        try contexto.delete(model: Movimiento.self)
        try contexto.delete(model: Deuda.self)
        try contexto.delete(model: TarjetaCredito.self)
        try contexto.delete(model: CuentaBancaria.self)
        try contexto.delete(model: Banco.self)
        try contexto.delete(model: Persona.self)
        try contexto.delete(model: Categoria.self)
        try contexto.save()

        if restaurarCategorias {
            Sembrador.sembrarSiHaceFalta(contexto: contexto)
            try contexto.save()
        }
        UserDefaults.standard.removeObject(forKey: "planificacionClaro")
        UserDefaults.standard.set(false, forKey: "onboardingCompletado")
        ProgramadorDeNotificaciones.cancelarTodas()
    }
}
