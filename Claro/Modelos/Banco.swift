//
//  Banco.swift
//  Claro — Carpeta: Modelos
//
//  Un banco (BBVA, Banorte, Nu...). Agrupa cuentas y tarjetas
//  y les da identidad visual (color).
//

import Foundation
import SwiftData

@Model
final class Banco {
    var nombre: String
    var colorHex: String
    var icono: String

    // Un banco tiene muchas cuentas y muchas tarjetas.
    // .cascade = si se elimina el banco, se eliminan sus cuentas/tarjetas
    // (la app pedirá confirmación antes, eso se construye en la Etapa 2).
    @Relationship(deleteRule: .cascade, inverse: \CuentaBancaria.banco)
    var cuentas: [CuentaBancaria] = []

    @Relationship(deleteRule: .cascade, inverse: \TarjetaCredito.banco)
    var tarjetas: [TarjetaCredito] = []

    init(nombre: String, colorHex: String = "6C8CFF", icono: String = "building.columns.fill") {
        self.nombre = nombre
        self.colorHex = colorHex
        self.icono = icono
    }
}
