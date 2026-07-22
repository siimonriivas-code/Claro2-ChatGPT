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
    @UIApplicationDelegateAdaptor(DelegadoAplicacionClaro.self)
    private var delegadoAplicacion

    /// SwiftData debe seguir usando exactamente la base local histórica.
    /// CloudKit se usa únicamente mediante AdministradorICloud para guardar
    /// un respaldo versionado; nunca debe cambiar silenciosamente el almacén.
    private let contenedor: ModelContainer

    init() {
        let esquema = Schema([
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
        let configuracion = ModelConfiguration(
            schema: esquema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            contenedor = try ModelContainer(
                for: esquema,
                configurations: [configuracion]
            )
        } catch {
            fatalError("No se pudo abrir la base local de Claro: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RaizView()
        }
        .modelContainer(contenedor)
    }
}
