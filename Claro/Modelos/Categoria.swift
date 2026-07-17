//
//  Categoria.swift
//  Claro — Carpeta: Modelos
//
//  Las categorías de gasto/ingreso (comida, transporte, salud, etc.).
//  @Model le dice a SwiftData: "esta ficha se guarda permanentemente
//  en el iPhone".
//

import Foundation
import SwiftData

@Model
final class Categoria {
    var nombre: String
    var icono: String          // nombre de símbolo de Apple, ej. "fork.knife"
    var colorHex: String
    var esPredefinida: Bool    // true = vino con la app; false = la creó el usuario

    // Movimientos que usan esta categoría
    @Relationship(inverse: \Movimiento.categoria)
    var movimientos: [Movimiento] = []

    init(nombre: String, icono: String, colorHex: String, esPredefinida: Bool = false) {
        self.nombre = nombre
        self.icono = icono
        self.colorHex = colorHex
        self.esPredefinida = esPredefinida
    }
}

// Lista de categorías que la app creará por defecto (se sembrarán en la Etapa 2)
extension Categoria {
    static let predefinidas: [(nombre: String, icono: String, colorHex: String)] = [
        ("Comida",          "fork.knife",          "F5B14C"),
        ("Súper",           "cart.fill",           "4ADE9C"),
        ("Transporte",      "car.fill",            "6C8CFF"),
        ("Salud",           "cross.case.fill",     "F26D6D"),
        ("Hogar",           "house.fill",          "9B8CFF"),
        ("Servicios",       "bolt.fill",           "F5D14C"),
        ("Entretenimiento", "gamecontroller.fill", "FF8CC8"),
        ("Ropa",            "tshirt.fill",         "4CC9F5"),
        ("Educación",       "book.fill",           "8CF5B1"),
        ("Mascotas",        "pawprint.fill",       "D9A66C"),
        ("Regalos",         "gift.fill",           "F58C8C"),
        ("Otro",            "ellipsis.circle.fill","8A93A6")
    ]
}
