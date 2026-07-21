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

    /// Parte de sus depósitos que se aplicó a compras compartidas.
    var totalAplicadoADeuda: Double {
        movimientos
            .filter { $0.cuentaParaCalculos && $0.tipo == .cobroRecibido }
            .reduce(0) { $0 + $1.monto }
    }

    /// Dinero adicional recibido de esta persona y registrado como ingreso.
    var totalExcedenteRecibido: Double {
        movimientos
            .filter { $0.cuentaParaCalculos && $0.tipo == .ingreso }
            .reduce(0) { $0 + $1.monto }
    }

    /// Todo lo recibido de la persona: deuda liquidada más excedentes.
    var totalQueTeHaPagado: Double {
        totalAplicadoADeuda + totalExcedenteRecibido
    }

    /// Lo que le falta pagarte HOY.
    var saldoPendiente: Double {
        max(0, totalQueTeDebe - totalAplicadoADeuda)
    }
}

struct DistribucionCobroPersona: Equatable {
    let aplicadoADeuda: Double
    let excedenteComoIngreso: Double
}

enum MotorDePersonas {
    static func distribuirCobro(monto: Double,
                                saldoPendiente: Double) -> DistribucionCobroPersona {
        let total = max(0, monto).redondeadoAMoneda
        let pendiente = max(0, saldoPendiente).redondeadoAMoneda
        let aplicado = min(total, pendiente).redondeadoAMoneda
        return DistribucionCobroPersona(
            aplicadoADeuda: aplicado,
            excedenteComoIngreso: max(0, total - aplicado).redondeadoAMoneda)
    }
}
