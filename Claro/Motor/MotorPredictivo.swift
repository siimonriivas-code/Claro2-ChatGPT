//
//  MotorPredictivo.swift
//  Claro
//

import Foundation

struct CargoRecurrenteDetectado: Identifiable {
    let id: String
    let comercio: String
    let promedio: Double
    let ultimaFecha: Date
    let siguienteFechaEstimada: Date
    let repeticiones: Int
}

struct PuntoPatrimonio: Identifiable {
    let id: Date
    let valor: Double
}

enum MotorPredictivo {

    static func recurrentes(movimientos: [Movimiento]) -> [CargoRecurrenteDetectado] {
        let calendario = Calendar.current
        let limite = calendario.date(byAdding: .month, value: -8, to: .now) ?? .distantPast
        let candidatos = movimientos.filter {
            $0.cuentaParaCalculos && $0.fecha >= limite
                && ($0.tipo == .gasto || $0.tipo == .compraCredito)
                && $0.planMSI == nil && $0.monto > 0
        }
        let grupos = Dictionary(grouping: candidatos) { claveComercio($0.detalle) }

        return grupos.compactMap { clave, movimientos -> CargoRecurrenteDetectado? in
            guard !clave.isEmpty else { return nil }
            let meses = Set(movimientos.map {
                calendario.dateComponents([.year, .month], from: $0.fecha)
            })
            guard meses.count >= 3 else { return nil }
            let montos = movimientos.map(\.monto)
            let promedio = montos.reduce(0, +) / Double(montos.count)
            let dispersion = (montos.max() ?? 0) - (montos.min() ?? 0)
            guard dispersion <= max(10, promedio * 0.20),
                  let ultimo = movimientos.max(by: { $0.fecha < $1.fecha }) else { return nil }
            let siguiente = calendario.date(byAdding: .month, value: 1,
                                             to: ultimo.fecha) ?? ultimo.fecha
            return CargoRecurrenteDetectado(id: clave,
                comercio: nombreComercio(movimientos), promedio: promedio,
                ultimaFecha: ultimo.fecha, siguienteFechaEstimada: siguiente,
                repeticiones: meses.count)
        }
        .sorted { $0.promedio > $1.promedio }
    }

    static func patrimonioActual(cuentas: [CuentaBancaria],
                                 tarjetas: [TarjetaCredito],
                                 personas: [Persona],
                                 deudas: [Deuda]) -> Double {
        MotorDashboard.saldoTotal(cuentas: cuentas)
            + MotorDashboard.totalTeDeben(personas: personas)
            - tarjetas.reduce(0) { $0 + max(0, $1.deudaCalculada) }
            - deudas.reduce(0) { $0 + max(0, $1.saldoRestante) }
    }

    static func disponibleEn30Dias(cuentas: [CuentaBancaria],
                                    tarjetas: [TarjetaCredito],
                                    recurrentes: [CargoRecurrenteDetectado]) -> Double {
        let calendario = Calendar.current
        let limite = calendario.date(byAdding: .day, value: 30, to: .now) ?? .now
        let compromisos = tarjetas.compactMap(\.estadoDeCuentaVigente)
            .filter { $0.fechaLimitePago <= limite && $0.faltaPorCubrir > 0 }
            .reduce(0) { $0 + $1.faltaPorCubrir }
        let cargosEsperados = recurrentes
            .filter { $0.siguienteFechaEstimada >= .now
                && $0.siguienteFechaEstimada <= limite }
            .reduce(0) { $0 + $1.promedio }
        return MotorDashboard.saldoTotal(cuentas: cuentas)
            - compromisos - cargosEsperados
    }

    static func historialPatrimonio(cuentas: [CuentaBancaria],
                                    tarjetas: [TarjetaCredito],
                                    personas: [Persona],
                                    deudas: [Deuda],
                                    meses: Int = 6) -> [PuntoPatrimonio] {
        let calendario = Calendar.current
        return (0..<meses).reversed().compactMap { desplazamiento in
            guard let mes = calendario.date(byAdding: .month,
                                             value: -desplazamiento,
                                             to: .now),
                  let fin = calendario.dateInterval(of: .month, for: mes)?.end
            else { return nil }
            let fecha = fin.addingTimeInterval(-1)
            let efectivo = cuentas.reduce(0) { $0 + saldo($1, hasta: fecha) }
            let deudaTarjetas = tarjetas.reduce(0) { $0 + max(0, deuda($1, hasta: fecha)) }
            let porCobrar = personas.reduce(0) { $0 + max(0, saldo($1, hasta: fecha)) }
            let deudaPropia = deudas.reduce(0) { $0 + max(0, saldo($1, hasta: fecha)) }
            return PuntoPatrimonio(id: calendario.startOfDay(for: fecha),
                                   valor: efectivo + porCobrar
                                       - deudaTarjetas - deudaPropia)
        }
    }

    private static func saldo(_ cuenta: CuentaBancaria, hasta fecha: Date) -> Double {
        guard cuenta.fechaSaldoInicial <= fecha else { return 0 }
        var saldo = cuenta.saldoInicial
        for m in cuenta.movimientos where m.cuentaParaCalculos && m.fecha <= fecha {
            switch m.tipo {
            case .ingreso, .cobroRecibido, .bonificacion: saldo += m.monto
            case .gasto, .pagoTarjeta, .transferencia, .abonoDeuda: saldo -= m.monto
            case .ajuste: saldo += m.monto
            case .compraCredito: break
            }
        }
        for m in cuenta.movimientosEntrantes
            where m.cuentaParaCalculos && m.tipo == .transferencia && m.fecha <= fecha {
            saldo += m.monto
        }
        return saldo
    }

    private static func deuda(_ tarjeta: TarjetaCredito, hasta fecha: Date) -> Double {
        guard tarjeta.fechaSaldoInicial <= fecha else { return 0 }
        var deuda = tarjeta.saldoInicial
        for m in tarjeta.movimientos where m.cuentaParaCalculos && m.fecha <= fecha {
            switch m.tipo {
            case .compraCredito: deuda += m.monto
            case .pagoTarjeta, .bonificacion: deuda -= m.monto
            case .ajuste: deuda += m.monto
            default: break
            }
        }
        return deuda
    }

    private static func saldo(_ persona: Persona, hasta fecha: Date) -> Double {
        let partes = persona.participaciones.filter {
            guard let movimiento = $0.compra?.movimiento else { return false }
            return movimiento.cuentaParaCalculos && movimiento.fecha <= fecha
        }.reduce(0) { $0 + $1.monto }
        let cobros = persona.movimientos.filter {
            $0.cuentaParaCalculos && $0.tipo == .cobroRecibido && $0.fecha <= fecha
        }.reduce(0) { $0 + $1.monto }
        return partes - cobros
    }

    private static func saldo(_ deuda: Deuda, hasta fecha: Date) -> Double {
        guard deuda.fecha <= fecha else { return 0 }
        let pagado = deuda.abonos.filter {
            $0.cuentaParaCalculos && $0.fecha <= fecha
        }.reduce(0) { $0 + $1.monto }
        return deuda.montoOriginal - pagado
    }

    private static func claveComercio(_ texto: String) -> String {
        let limpio = texto.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                   locale: Locale(identifier: "es_MX"))
            .uppercased()
            .filter { $0.isLetter || $0 == " " }
            .split(separator: " ")
            .prefix(4)
            .joined(separator: " ")
        return String(limpio.prefix(28))
    }

    private static func nombreComercio(_ movimientos: [Movimiento]) -> String {
        movimientos.max(by: { $0.fecha < $1.fecha })?.detalle
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Cargo recurrente"
    }
}
