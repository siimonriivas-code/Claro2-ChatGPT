//
//  MSI.swift
//  Claro — Carpeta: Modelos
//
//  Compras a meses sin intereses.
//  ⚠️ LEY 3: "generada" y "cubierta" son cosas DISTINTAS:
//    · generada = el banco ya la incluyó en un estado de cuenta
//    · cubierta = ya quedó respaldada por pagos reales tuyos
//  Un plan solo está concluido cuando TODAS están generadas Y cubiertas.
//

import Foundation
import SwiftData

@Model
final class PlanMSI {
    var detalle: String         // "Pantalla Samsung"
    var montoTotal: Double      // 8,000
    var numeroMeses: Int        // 4
    var fechaCompra: Date

    var tarjeta: TarjetaCredito?

    // Movimientos relacionados con este plan (la compra original, ajustes...)
    @Relationship(inverse: \Movimiento.planMSI)
    var movimientos: [Movimiento] = []

    // Las mensualidades: "1 de 4", "2 de 4"...
    @Relationship(deleteRule: .cascade, inverse: \MensualidadMSI.plan)
    var mensualidades: [MensualidadMSI] = []

    /// Monto de cada mensualidad (calculado, no guardado)
    var montoMensualidad: Double {
        guard numeroMeses > 0 else { return 0 }
        return montoTotal / Double(numeroMeses)
    }

    /// Cuántas mensualidades ya generó el banco
    var generadas: Int { mensualidades.filter { $0.fueGenerada }.count }

    /// Cuántas mensualidades ya están cubiertas con pagos reales
    var cubiertas: Int { mensualidades.filter { $0.cubierta }.count }

    /// ⭐ La regla de oro de la Ley 3
    var estaConcluido: Bool {
        generadas == numeroMeses && cubiertas == numeroMeses
    }

    init(detalle: String, montoTotal: Double, numeroMeses: Int,
         fechaCompra: Date = .now, tarjeta: TarjetaCredito? = nil) {
        self.detalle = detalle
        self.montoTotal = montoTotal
        self.numeroMeses = numeroMeses
        self.fechaCompra = fechaCompra
        self.tarjeta = tarjeta
    }
}

@Model
final class MensualidadMSI {
    var numero: Int             // 2 (de 4)
    var monto: Double

    // ¿El banco ya la incluyó en un estado de cuenta? (si sí, en cuál)
    var fechaGeneracion: Date?
    var estadoDeCuenta: EstadoDeCuenta?

    // ¿Ya quedó respaldada por pagos reales? ⚠️ Este valor lo administra
    // el Motor financiero (Etapa 3/4) al verificar los pagos registrados.
    // Ninguna pantalla lo cambia a mano.
    var cubierta: Bool

    var plan: PlanMSI?

    var fueGenerada: Bool { fechaGeneracion != nil }

    init(numero: Int, monto: Double, plan: PlanMSI? = nil) {
        self.numero = numero
        self.monto = monto
        self.cubierta = false
        self.plan = plan
    }
}
