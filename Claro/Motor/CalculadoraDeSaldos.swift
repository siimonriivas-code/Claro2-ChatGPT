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

    private func finDelDia(_ fecha: Date) -> Date {
        let calendario = Calendar.current
        let inicio = calendario.startOfDay(for: fecha)
        let siguienteDia = calendario.date(byAdding: .day, value: 1, to: inicio)
        return siguienteDia?.addingTimeInterval(-0.001) ?? fecha
    }

    /// Saldo confirmado en una fecha concreta. El saldo inicial es una foto
    /// tomada en `fechaSaldoInicial`: los movimientos anteriores a esa foto y
    /// las operaciones futuras no se vuelven parte del disponible actual.
    func saldoCalculado(hasta fecha: Date) -> Double {
        let limite = finDelDia(fecha)
        guard limite >= fechaSaldoInicial else { return 0 }

        var saldo = saldoInicial
        for m in movimientos where m.cuentaParaCalculos
            && m.fecha >= fechaSaldoInicial && m.fecha <= limite {
            switch m.tipo {
            case .ingreso, .cobroRecibido, .bonificacion:
                saldo += m.monto
            case .gasto, .pagoTarjeta, .transferencia, .abonoDeuda:
                saldo -= m.monto
            case .ajuste:
                saldo += m.monto
            case .compraCredito:
                break
            }
        }

        for m in movimientosEntrantes where m.cuentaParaCalculos
            && m.tipo == .transferencia
            && m.fecha >= fechaSaldoInicial && m.fecha <= limite {
            saldo += m.monto
        }
        return saldo.redondeadoAMoneda
    }

    /// Se enseñan aparte y no alteran el dinero disponible de hoy.
    var movimientosProgramados: [Movimiento] {
        let limite = finDelDia(FechaAnalisisClaro.actual)
        return (movimientos + movimientosEntrantes)
            .filter { $0.cuentaParaCalculos && $0.fecha > limite }
            .sorted { $0.fecha < $1.fecha }
    }

    /// El saldo REAL de la cuenta, calculado desde los movimientos.
    ///
    /// Saldo = saldo inicial
    ///       + ingresos, cobros recibidos y bonificaciones
    ///       + transferencias que LLEGAN a esta cuenta
    ///       − gastos, pagos de tarjeta, abonos a deudas
    ///       − transferencias que SALEN de esta cuenta
    ///       ± ajustes manuales (su monto lleva signo)
    var saldoCalculado: Double {
        saldoCalculado(hasta: FechaAnalisisClaro.actual)
    }
}
