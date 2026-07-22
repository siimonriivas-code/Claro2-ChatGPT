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

/// Las situaciones posibles de un estado de cuenta.
/// 'nonisolated': puede usarse y compararse desde cualquier contexto
/// del nuevo sistema de concurrencia de Swift.
nonisolated enum SituacionEstadoDeCuenta {
    case pendiente            // 🟡 nada pagado aún, dentro del plazo
    case parcialmenteCubierto // 🟡 pagaste algo, pero falta
    case cubierto             // 🟢 alcanzaste el pago para no generar intereses
    case vencidoSinCubrir     // 🔴 pasó la fecha límite sin cubrirlo
    case vencidoParcialmenteCubierto // 🔴 venció, pero ya recibió un abono

    var titulo: String {
        switch self {
        case .pendiente:            return "Pendiente"
        case .parcialmenteCubierto: return "Parcialmente cubierto"
        case .cubierto:             return "Cubierto"
        case .vencidoSinCubrir:     return "Vencido sin cubrir"
        case .vencidoParcialmenteCubierto:
            return "Vencido · pago parcial"
        }
    }
}

extension EstadoDeCuenta {

    /// Suma los pagos reales que corresponden a este corte. La fecha límite
    /// mide puntualidad, pero no impide que un pago tardío reduzca lo que
    /// todavía falta. Si existe un corte posterior, ese corte inicia una
    /// ventana nueva y evita contar el mismo pago dos veces en el historial.
    func pagadoAplicado(hasta fechaReferencia: Date) -> Double {
        guard let tarjeta else { return 0 }
        let calendario = Calendar.current
        let inicio = calendario.startOfDay(for: fechaCorte)
        let finReferencia = calendario.date(
            byAdding: .day, value: 1,
            to: calendario.startOfDay(for: fechaReferencia)) ?? fechaReferencia
        let siguienteCorte = tarjeta.estadosDeCuenta
            .filter { $0 !== self && $0.fechaCorte > fechaCorte }
            .map(\.fechaCorte)
            .min()
        let finExclusivo = min(siguienteCorte ?? .distantFuture, finReferencia)

        return tarjeta.movimientos
            .filter { movimiento in
                guard movimiento.cuentaParaCalculos,
                      movimiento.tipo == .pagoTarjeta,
                      movimiento.fecha < finReferencia else { return false }

                if let corteObjetivo = movimiento.fechaCorteObjetivoPago {
                    return calendario.isDate(corteObjetivo,
                                              inSameDayAs: fechaCorte)
                }
                // Compatibilidad con pagos creados antes de que existiera la
                // asociación explícita al corte.
                return movimiento.fecha >= inicio
                    && movimiento.fecha < finExclusivo
            }
            .reduce(0) { $0 + $1.monto }
            .redondeadoAMoneda
    }

    /// Nombre conservado para las vistas existentes. Ahora representa todos
    /// los pagos aplicados al corte, incluidos los tardíos.
    var pagadoDelPeriodo: Double {
        pagadoAplicado(hasta: FechaAnalisisClaro.actual)
    }

    /// Cuánto falta para cubrir el pago para no generar intereses.
    var faltaPorCubrir: Double {
        max(0, pagoParaNoGenerarIntereses - pagadoDelPeriodo)
            .redondeadoAMoneda
    }

    /// Valores vivos que la interfaz debe mostrar después de cada pago. Los
    /// importes originales del PDF se conservan como evidencia histórica.
    var saldoDelCortePendiente: Double {
        max(0, saldoAlCorte - pagadoDelPeriodo).redondeadoAMoneda
    }

    var pagoMinimoPendiente: Double {
        max(0, pagoMinimo - pagadoDelPeriodo).redondeadoAMoneda
    }

    /// La situación actual (el semáforo).
    var situacion: SituacionEstadoDeCuenta {
        if pagadoDelPeriodo >= pagoParaNoGenerarIntereses && pagoParaNoGenerarIntereses > 0 {
            return .cubierto
        }
        if pagoParaNoGenerarIntereses == 0 { return .cubierto } // corte en ceros
        let hoy = Calendar.current.startOfDay(for: FechaAnalisisClaro.actual)
        let limite = Calendar.current.startOfDay(for: fechaLimitePago)
        if hoy > limite {
            return pagadoDelPeriodo > 0
                ? .vencidoParcialmenteCubierto
                : .vencidoSinCubrir
        }
        return pagadoDelPeriodo > 0 ? .parcialmenteCubierto : .pendiente
    }

    /// Días que faltan para la fecha límite (negativo si ya pasó).
    var diasParaVencer: Int {
        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: FechaAnalisisClaro.actual)
        let limite = calendario.startOfDay(for: fechaLimitePago)
        return calendario.dateComponents([.day], from: hoy, to: limite).day ?? 0
    }
}
