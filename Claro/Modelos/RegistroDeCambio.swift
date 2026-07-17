//
//  RegistroDeCambio.swift
//  Claro — Carpeta: Modelos
//
//  La bitácora de la Ley 4: cada corrección importante de un movimiento
//  deja una huella ("12 jun: monto cambiado de $10,000 → $1,000").
//

import Foundation
import SwiftData

@Model
final class RegistroDeCambio {
    var fecha: Date
    var campo: String          // qué se cambió: "monto", "fecha", "categoría"...
    var valorAnterior: String
    var valorNuevo: String

    var movimiento: Movimiento?

    init(campo: String, valorAnterior: String, valorNuevo: String,
         movimiento: Movimiento? = nil) {
        self.fecha = .now
        self.campo = campo
        self.valorAnterior = valorAnterior
        self.valorNuevo = valorNuevo
        self.movimiento = movimiento
    }
}
