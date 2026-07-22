//
//  ClaroApp.swift
//  Claro
//
//  Punto de arranque de la aplicación.
//  Aquí también se "enciende" SwiftData: le decimos al iPhone qué fichas
//  (modelos) debe guardar permanentemente.
//

import SwiftUI
import SwiftData

@main
struct ClaroApp: App {
    var body: some Scene {
        WindowGroup {
            RaizView()
        }
        .modelContainer(for: [
            Banco.self,
            CuentaBancaria.self,
            TarjetaCredito.self,
            Movimiento.self,
            EstadoDeCuenta.self,
            PlanMSI.self,
            MensualidadMSI.self,
            Persona.self,
            CompraCompartida.self,
            Participacion.self,
            Deuda.self,
            Categoria.self,
            RegistroDeCambio.self,
            IngresoRecurrente.self,
            OcurrenciaIngresoRecurrente.self,
            ConversacionFinanciera.self,
            MensajeFinanciero.self,
            ConciliacionCuentaBancaria.self,
            GrupoGastosCompartidos.self,
            GastoCompartidoIndependiente.self,
            ParteGastoIndependiente.self,
            LiquidacionGastoIndependiente.self
        ])
    }
}
