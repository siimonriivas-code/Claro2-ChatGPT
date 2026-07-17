//
//  MotorDeTarjetas.swift
//  Claro — Carpeta: Motor
//  ⚠️ REEMPLAZA al existente.
//
//  ⭐ LA LEY 2 EN ACCIÓN.
//  Único cambio de esta versión: el semáforo (SituacionEstadoDeCuenta)
//  se declara 'nonisolated' para el nuevo sistema de concurrencia de Swift.
//

import Foundation

// MARK: - Cálculos de la tarjeta

extension TarjetaCredito {

    /// Deuda TOTAL actual de la tarjeta, calculada desde los movimientos.
    /// Deuda = saldo inicial + compras − pagos − bonificaciones ± ajustes
    var deudaCalculada: Double {
        var deuda = saldoInicial
        for m in movimientos where m.cuentaParaCalculos {
            switch m.tipo {
            case .compraCredito:            deuda += m.monto
            case .pagoTarjeta, .bonificacion: deuda -= m.monto
            case .ajuste:                   deuda += m.monto
            default: break
            }
        }
        return deuda
    }

    /// Crédito que te queda disponible en la tarjeta.
    var creditoDisponible: Double { limiteCredito - deudaCalculada }

    /// El estado de cuenta más reciente (el corte vigente).
    var estadoDeCuentaVigente: EstadoDeCuenta? {
        estadosDeCuenta.max(by: { $0.fechaCorte < $1.fechaCorte })
    }

    /// Compras hechas DESPUÉS del último corte: el "periodo actual".
    /// Esto aún no te lo han "cobrado" en ningún estado de cuenta.
    var comprasDelPeriodoActual: [Movimiento] {
        let compras = movimientos.filter {
            $0.cuentaParaCalculos && $0.tipo == .compraCredito
        }
        guard let ultimoCorte = estadoDeCuentaVigente?.fechaCorte else {
            return compras.sorted { $0.fecha > $1.fecha }
        }
        return compras
            .filter { $0.fecha > ultimoCorte }
            .sorted { $0.fecha > $1.fecha }
    }
}

// MARK: - Cálculos del estado de cuenta

/// Las 4 situaciones posibles de un estado de cuenta.
/// 'nonisolated': puede usarse y compararse desde cualquier contexto
/// del nuevo sistema de concurrencia de Swift.
nonisolated enum SituacionEstadoDeCuenta {
    case pendiente            // 🟡 nada pagado aún, dentro del plazo
    case parcialmenteCubierto // 🟡 pagaste algo, pero falta
    case cubierto             // 🟢 alcanzaste el pago para no generar intereses
    case vencidoSinCubrir     // 🔴 pasó la fecha límite sin cubrirlo

    var titulo: String {
        switch self {
        case .pendiente:            return "Pendiente"
        case .parcialmenteCubierto: return "Parcialmente cubierto"
        case .cubierto:             return "Cubierto"
        case .vencidoSinCubrir:     return "Vencido sin cubrir"
        }
    }
}

extension EstadoDeCuenta {

    /// Suma de los PAGOS REALES de la tarjeta registrados dentro del
    /// periodo de pago de este corte (del corte a la fecha límite).
    /// ⚠️ Ley 2: solo pagos registrados explícitamente cuentan aquí.
    var pagadoDelPeriodo: Double {
        guard let tarjeta else { return 0 }
        let calendario = Calendar.current
        let inicio = calendario.startOfDay(for: fechaCorte)
        // Hasta el FINAL del día de la fecha límite
        let limite = calendario.date(byAdding: .day, value: 1,
                                     to: calendario.startOfDay(for: fechaLimitePago)) ?? fechaLimitePago

        return tarjeta.movimientos
            .filter { $0.cuentaParaCalculos
                   && $0.tipo == .pagoTarjeta
                   && $0.fecha >= inicio
                   && $0.fecha < limite }
            .reduce(0) { $0 + $1.monto }
    }

    /// Cuánto falta para cubrir el pago para no generar intereses.
    var faltaPorCubrir: Double {
        max(0, pagoParaNoGenerarIntereses - pagadoDelPeriodo)
    }

    /// La situación actual (el semáforo).
    var situacion: SituacionEstadoDeCuenta {
        if pagadoDelPeriodo >= pagoParaNoGenerarIntereses && pagoParaNoGenerarIntereses > 0 {
            return .cubierto
        }
        if pagoParaNoGenerarIntereses == 0 { return .cubierto } // corte en ceros
        let hoy = Calendar.current.startOfDay(for: .now)
        let limite = Calendar.current.startOfDay(for: fechaLimitePago)
        if hoy > limite { return .vencidoSinCubrir }
        return pagadoDelPeriodo > 0 ? .parcialmenteCubierto : .pendiente
    }

    /// Días que faltan para la fecha límite (negativo si ya pasó).
    var diasParaVencer: Int {
        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: .now)
        let limite = calendario.startOfDay(for: fechaLimitePago)
        return calendario.dateComponents([.day], from: hoy, to: limite).day ?? 0
    }
}
