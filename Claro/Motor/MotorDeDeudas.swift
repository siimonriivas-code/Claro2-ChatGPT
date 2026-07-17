//
//  MotorDeDeudas.swift
//  Claro — Carpeta: Motor
//
//  Ley 1 aplicada a deudas propias: el saldo restante nunca se escribe
//  a mano; se calcula = monto original − abonos registrados.
//

import Foundation

extension Deuda {

    /// Suma de los abonos registrados (solo movimientos activos).
    var totalAbonado: Double {
        abonos
            .filter { $0.cuentaParaCalculos && $0.tipo == .abonoDeuda }
            .reduce(0) { $0 + $1.monto }
    }

    /// Lo que falta por pagar HOY.
    var saldoRestante: Double {
        max(0, montoOriginal - totalAbonado)
    }

    /// ¿Ya quedó saldada?
    var estaLiquidada: Bool { saldoRestante <= 0 }
}
