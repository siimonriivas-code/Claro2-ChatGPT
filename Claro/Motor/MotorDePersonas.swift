//
//  MotorDePersonas.swift
//  Claro — Carpeta: Motor
//
//  Ley 1 aplicada a personas: lo que te deben nunca se escribe a mano;
//  se calcula = sus partes en compras compartidas − cobros que te pagaron.
//

import Foundation

extension Movimiento {
    /// TU parte real de una compra: el total menos las partes ajenas.
    /// Si no es compartida, tu parte es el total.
    var montoPropio: Double {
        guard let compartida = compraCompartida else { return monto }
        let ajeno = compartida.participaciones.reduce(0) { $0 + $1.monto }
        return max(0, monto - ajeno)
    }
}

extension Persona {

    /// Suma de sus partes en compras compartidas (solo compras activas).
    var totalQueTeDebe: Double {
        participaciones
            .filter { $0.compra?.movimiento?.cuentaParaCalculos ?? false }
            .reduce(0) { $0 + $1.monto }
    }

    /// Suma de los cobros que te ha pagado (movimientos activos).
    var totalQueTeHaPagado: Double {
        movimientos
            .filter { $0.cuentaParaCalculos && $0.tipo == .cobroRecibido }
            .reduce(0) { $0 + $1.monto }
    }

    /// Lo que le falta pagarte HOY.
    var saldoPendiente: Double { totalQueTeDebe - totalQueTeHaPagado }
}
