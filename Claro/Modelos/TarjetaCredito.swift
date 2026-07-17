//
//  TarjetaCredito.swift
//  Claro — Carpeta: Modelos
//
//  Una tarjeta de crédito con su calendario propio (corte y fecha límite).
//  ⚠️ LEY 1: la deuda actual NO se guarda. Se calcula desde los movimientos.
//

import Foundation
import SwiftData

@Model
final class TarjetaCredito {
    var nombre: String              // alias: "BBVA Azul"
    var ultimosDigitos: String      // opcional en la práctica, puede ir vacío
    var limiteCredito: Double
    var diaCorte: Int               // ej. 15 = corta el día 15 de cada mes
    var diaLimitePago: Int          // día del mes de la fecha límite de pago
    var saldoInicial: Double        // deuda que ya traía al darla de alta
    var fechaSaldoInicial: Date
    var colorHex: String

    var banco: Banco?

    @Relationship(inverse: \Movimiento.tarjeta)
    var movimientos: [Movimiento] = []

    @Relationship(deleteRule: .cascade, inverse: \EstadoDeCuenta.tarjeta)
    var estadosDeCuenta: [EstadoDeCuenta] = []

    @Relationship(deleteRule: .cascade, inverse: \PlanMSI.tarjeta)
    var planesMSI: [PlanMSI] = []

    init(nombre: String,
         ultimosDigitos: String = "",
         limiteCredito: Double,
         diaCorte: Int,
         diaLimitePago: Int,
         saldoInicial: Double = 0,
         fechaSaldoInicial: Date = .now,
         colorHex: String = "6C8CFF",
         banco: Banco? = nil) {
        self.nombre = nombre
        self.ultimosDigitos = ultimosDigitos
        self.limiteCredito = limiteCredito
        self.diaCorte = diaCorte
        self.diaLimitePago = diaLimitePago
        self.saldoInicial = saldoInicial
        self.fechaSaldoInicial = fechaSaldoInicial
        self.colorHex = colorHex
        self.banco = banco
    }
}
