//
//  Personas.swift
//  Claro — Carpeta: Modelos
//
//  Personas que comparten compras contigo y te deben dinero.
//  ⚠️ LEY 1: lo que te debe una persona NO se guarda; se calcula:
//  suma de sus participaciones − cobros que te ha pagado.
//

import Foundation
import SwiftData

@Model
final class Persona {
    var nombre: String
    var colorHex: String
    var archivada: Bool = false

    // Sus partes en compras compartidas
    @Relationship(deleteRule: .cascade, inverse: \Participacion.persona)
    var participaciones: [Participacion] = []

    // Cobros que te ha pagado (movimientos tipo cobroRecibido)
    @Relationship(inverse: \Movimiento.persona)
    var movimientos: [Movimiento] = []

    /// Inicial para el avatar ("Hermano" → "H")
    var inicial: String { String(nombre.prefix(1)).uppercased() }

    init(nombre: String, colorHex: String = "6C8CFF") {
        self.nombre = nombre
        self.colorHex = colorHex
    }
}

@Model
final class CompraCompartida {
    // La compra original (un Movimiento). Relación uno-a-uno.
    @Relationship(inverse: \Movimiento.compraCompartida)
    var movimiento: Movimiento?

    // Cómo se dividió: una participación por persona.
    // Tu parte = total de la compra − suma de las participaciones ajenas.
    @Relationship(deleteRule: .cascade, inverse: \Participacion.compra)
    var participaciones: [Participacion] = []

    init() { }
}

@Model
final class Participacion {
    var monto: Double          // cuánto le corresponde a esa persona
    var importacionID: UUID? = nil

    var persona: Persona?
    var compra: CompraCompartida?

    init(monto: Double, persona: Persona? = nil, compra: CompraCompartida? = nil) {
        self.monto = monto.redondeadoAMoneda
        self.persona = persona
        self.compra = compra
    }
}
