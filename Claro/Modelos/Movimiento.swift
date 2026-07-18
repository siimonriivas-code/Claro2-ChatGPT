//
//  Movimiento.swift
//  Claro — Carpeta: Modelos
//
//  ⭐ LA FICHA MÁS IMPORTANTE DE TODA LA APP.
//  Cada peso que entra, sale o se mueve es un Movimiento.
//  Es la "fuente de verdad" de la Ley 1: todos los saldos
//  se calculan a partir de estas fichas.
//

import Foundation
import SwiftData

enum TipoMovimiento: String, Codable, CaseIterable {
    case ingreso        = "Ingreso"
    case gasto          = "Gasto"            // pagado con débito o efectivo
    case compraCredito  = "Compra a crédito" // pagado con tarjeta de crédito
    case pagoTarjeta    = "Pago de tarjeta"
    case transferencia  = "Transferencia"
    case cobroRecibido  = "Cobro recibido"   // alguien te pagó lo que te debía
    case abonoDeuda     = "Abono a deuda"
    case ajuste         = "Ajuste manual"
    case bonificacion   = "Bonificación"     // devolución del banco a la tarjeta
}

enum EstadoMovimiento: String, Codable {
    case activo    = "Activo"
    case cancelado = "Cancelado"  // cancelar NO borra: deja rastro (Ley 4)
}

@Model
final class Movimiento {
    var tipoRaw: String
    var monto: Double
    var fecha: Date
    var detalle: String            // descripción libre: "Cena", "Pensión junio"...
    var estadoRaw: String

    // Bitácora básica
    var creadoEl: Date
    var editadoEl: Date?

    // Identifica los movimientos creados juntos al importar un PDF. Es
    // opcional para conservar sin cambios los datos de versiones anteriores.
    var importacionID: UUID? = nil

    // Vínculos (todos opcionales: cada tipo de movimiento usa los que necesita)
    var cuenta: CuentaBancaria?        // cuenta principal (de donde sale o entra dinero)
    var cuentaDestino: CuentaBancaria? // solo transferencias: cuenta que recibe
    var tarjeta: TarjetaCredito?       // compras a crédito y pagos de tarjeta
    var categoria: Categoria?
    var persona: Persona?              // cobros recibidos: quién te pagó
    var planMSI: PlanMSI?              // si pertenece a una compra a meses
    var compraCompartida: CompraCompartida?
    var deuda: Deuda?                  // abonos a deudas propias

    // Historial de correcciones de este movimiento (Ley 4)
    @Relationship(deleteRule: .cascade, inverse: \RegistroDeCambio.movimiento)
    var cambios: [RegistroDeCambio] = []

    var tipo: TipoMovimiento {
        get { TipoMovimiento(rawValue: tipoRaw) ?? .gasto }
        set { tipoRaw = newValue.rawValue }
    }

    var estado: EstadoMovimiento {
        get { EstadoMovimiento(rawValue: estadoRaw) ?? .activo }
        set { estadoRaw = newValue.rawValue }
    }

    /// ¿Este movimiento cuenta para los cálculos? (los cancelados no)
    var cuentaParaCalculos: Bool { estado == .activo }

    init(tipo: TipoMovimiento,
         monto: Double,
         fecha: Date = .now,
         detalle: String = "",
         cuenta: CuentaBancaria? = nil,
         cuentaDestino: CuentaBancaria? = nil,
         tarjeta: TarjetaCredito? = nil,
         categoria: Categoria? = nil,
         persona: Persona? = nil,
         planMSI: PlanMSI? = nil,
         deuda: Deuda? = nil) {
        self.tipoRaw = tipo.rawValue
        self.monto = monto.redondeadoAMoneda
        self.fecha = fecha
        self.detalle = detalle
        self.estadoRaw = EstadoMovimiento.activo.rawValue
        self.creadoEl = .now
        self.cuenta = cuenta
        self.cuentaDestino = cuentaDestino
        self.tarjeta = tarjeta
        self.categoria = categoria
        self.persona = persona
        self.planMSI = planMSI
        self.deuda = deuda
    }
}
