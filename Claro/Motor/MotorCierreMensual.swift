//
//  MotorCierreMensual.swift
//  Claro
//
//  Resume un mes sin mezclar gasto generado con flujo de efectivo.
//

import Foundation

struct ResumenCierreMensual {
    let mes: Date
    let ingresos: Double
    let cobrosRecibidos: Double
    let gastosDirectos: Double
    let comprasCreditoPropias: Double
    let pagosTarjetas: Double
    let abonosDeudas: Double
    let ajustes: Double
    let totalCortes: Int
    let cortesCubiertos: Int
    let faltaCortes: Double
    let porCobrarAlCierre: Double

    var gastoGenerado: Double {
        (gastosDirectos + comprasCreditoPropias).redondeadoAMoneda
    }

    /// Actividad económica del mes: ingresos propios menos gastos propios.
    /// Los cobros familiares no son ingreso propio y los pagos de tarjeta no
    /// vuelven a contar como gasto porque liquidan compras ya registradas.
    var resultadoDelMes: Double {
        (ingresos - gastoGenerado).redondeadoAMoneda
    }

    /// Entradas y salidas reales en cuentas bancarias durante el mes.
    var flujoDeEfectivo: Double {
        (ingresos + cobrosRecibidos - gastosDirectos
            - pagosTarjetas - abonosDeudas + ajustes).redondeadoAMoneda
    }
}

enum MotorCierreMensual {
    static func resumir(
        mes: Date,
        movimientos: [Movimiento],
        estados: [EstadoDeCuenta],
        personas: [Persona],
        calendario: Calendar = .current
    ) -> ResumenCierreMensual {
        guard let intervalo = calendario.dateInterval(of: .month, for: mes) else {
            return ResumenCierreMensual(
                mes: mes, ingresos: 0, cobrosRecibidos: 0,
                gastosDirectos: 0, comprasCreditoPropias: 0,
                pagosTarjetas: 0, abonosDeudas: 0, ajustes: 0,
                totalCortes: 0, cortesCubiertos: 0, faltaCortes: 0,
                porCobrarAlCierre: 0
            )
        }

        let delMes = movimientos.filter {
            $0.cuentaParaCalculos && intervalo.contains($0.fecha)
        }
        var ingresos = 0.0
        var cobros = 0.0
        var gastos = 0.0
        var credito = 0.0
        var pagos = 0.0
        var abonos = 0.0
        var ajustes = 0.0

        for movimiento in delMes {
            switch movimiento.tipo {
            case .ingreso:
                ingresos += movimiento.monto
            case .cobroRecibido:
                cobros += movimiento.monto
            case .gasto:
                gastos += movimiento.montoPropio
            case .compraCredito:
                credito += movimiento.montoPropio
            case .pagoTarjeta:
                pagos += movimiento.monto
            case .abonoDeuda:
                abonos += movimiento.monto
            case .ajuste:
                ajustes += movimiento.monto
            case .transferencia:
                break
            case .bonificacion:
                // Reduce la deuda de la tarjeta; no es dinero depositado en
                // una cuenta ni un ingreso propio del mes.
                break
            }
        }

        let cortes = estados.filter { intervalo.contains($0.fechaCorte) }
        let cubiertos = cortes.filter { $0.faltaPorCubrir <= 0.009 }
        let falta = cortes.reduce(0) { $0 + max(0, $1.faltaPorCubrir) }
        let fin = intervalo.end.addingTimeInterval(-1)
        let porCobrar = personas.reduce(0) {
            $0 + saldo(persona: $1, hasta: fin)
        }

        return ResumenCierreMensual(
            mes: intervalo.start,
            ingresos: ingresos.redondeadoAMoneda,
            cobrosRecibidos: cobros.redondeadoAMoneda,
            gastosDirectos: gastos.redondeadoAMoneda,
            comprasCreditoPropias: credito.redondeadoAMoneda,
            pagosTarjetas: pagos.redondeadoAMoneda,
            abonosDeudas: abonos.redondeadoAMoneda,
            ajustes: ajustes.redondeadoAMoneda,
            totalCortes: cortes.count,
            cortesCubiertos: cubiertos.count,
            faltaCortes: falta.redondeadoAMoneda,
            porCobrarAlCierre: max(0, porCobrar).redondeadoAMoneda
        )
    }

    private static func saldo(persona: Persona, hasta fecha: Date) -> Double {
        let partes = persona.participaciones.filter {
            guard let movimiento = $0.compra?.movimiento else { return false }
            return movimiento.cuentaParaCalculos && movimiento.fecha <= fecha
        }.reduce(0) { $0 + $1.monto }
        let cobros = persona.movimientos.filter {
            $0.cuentaParaCalculos
                && $0.tipo == .cobroRecibido
                && $0.fecha <= fecha
        }.reduce(0) { $0 + $1.monto }
        return max(0, partes - cobros)
    }
}
