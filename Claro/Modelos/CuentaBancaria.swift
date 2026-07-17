//
//  CuentaBancaria.swift
//  Claro — Carpeta: Modelos
//
//  Una cuenta de débito, ahorro o efectivo.
//  ⚠️ LEY 1: el saldo actual NO se guarda aquí. Se calculará siempre
//  a partir del saldo inicial + los movimientos (Motor, Etapa 2).
//

import Foundation
import SwiftData

enum TipoCuenta: String, Codable, CaseIterable {
    case debito   = "Débito"
    case ahorro   = "Ahorro"
    case efectivo = "Efectivo"
}

@Model
final class CuentaBancaria {
    var nombre: String                 // alias: "Nómina", "Ahorro"
    var tipoRaw: String                // se guarda como texto (más estable)
    var saldoInicial: Double           // punto de partida
    var fechaSaldoInicial: Date

    var banco: Banco?

    // Movimientos donde esta cuenta es la principal (ingresos, gastos, pagos...)
    @Relationship(inverse: \Movimiento.cuenta)
    var movimientos: [Movimiento] = []

    // Movimientos donde esta cuenta RECIBE una transferencia
    @Relationship(inverse: \Movimiento.cuentaDestino)
    var movimientosEntrantes: [Movimiento] = []

    // Acceso cómodo al tipo como enum
    var tipo: TipoCuenta {
        get { TipoCuenta(rawValue: tipoRaw) ?? .debito }
        set { tipoRaw = newValue.rawValue }
    }

    init(nombre: String, tipo: TipoCuenta, saldoInicial: Double, fechaSaldoInicial: Date = .now, banco: Banco? = nil) {
        self.nombre = nombre
        self.tipoRaw = tipo.rawValue
        self.saldoInicial = saldoInicial
        self.fechaSaldoInicial = fechaSaldoInicial
        self.banco = banco
    }
}
