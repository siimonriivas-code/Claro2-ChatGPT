//
//  Deuda.swift
//  Claro — Carpeta: Modelos
//
//  Deudas propias fuera de tarjetas (préstamos personales, etc.).
//  ⚠️ LEY 1: el saldo restante NO se guarda; se calcula:
//  monto original − abonos registrados.
//

import Foundation
import SwiftData

@Model
final class Deuda {
    var acreedor: String        // a quién le debes
    var montoOriginal: Double
    var fecha: Date
    var notas: String

    // Abonos registrados (movimientos tipo abonoDeuda)
    @Relationship(inverse: \Movimiento.deuda)
    var abonos: [Movimiento] = []

    init(acreedor: String, montoOriginal: Double, fecha: Date = .now, notas: String = "") {
        self.acreedor = acreedor
        self.montoOriginal = montoOriginal.redondeadoAMoneda
        self.fecha = fecha
        self.notas = notas
    }
}
