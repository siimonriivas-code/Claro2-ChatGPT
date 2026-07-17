//
//  CalculadoraDeSaldos.swift
//  Claro — Carpeta: Motor
//
//  ⭐ LA LEY 1 EN ACCIÓN.
//  Aquí vive la fórmula del saldo de una cuenta. Ninguna pantalla hace
//  cuentas por su lado: todas le preguntan a este motor. Por eso es
//  imposible que dos pantallas muestren saldos contradictorios.
//

import Foundation

extension CuentaBancaria {

    /// El saldo REAL de la cuenta, calculado desde los movimientos.
    ///
    /// Saldo = saldo inicial
    ///       + ingresos, cobros recibidos y bonificaciones
    ///       + transferencias que LLEGAN a esta cuenta
    ///       − gastos, pagos de tarjeta, abonos a deudas
    ///       − transferencias que SALEN de esta cuenta
    ///       ± ajustes manuales (su monto lleva signo)
    var saldoCalculado: Double {
        var saldo = saldoInicial

        // Movimientos donde esta cuenta es la principal
        for m in movimientos where m.cuentaParaCalculos {
            switch m.tipo {
            case .ingreso, .cobroRecibido, .bonificacion:
                saldo += m.monto
            case .gasto, .pagoTarjeta, .transferencia, .abonoDeuda:
                saldo -= m.monto
            case .ajuste:
                saldo += m.monto   // el ajuste puede ser positivo o negativo
            case .compraCredito:
                break              // las compras a crédito no tocan cuentas de débito
            }
        }

        // Transferencias que llegan a esta cuenta desde otra
        for m in movimientosEntrantes where m.cuentaParaCalculos && m.tipo == .transferencia {
            saldo += m.monto
        }

        return saldo
    }
}
