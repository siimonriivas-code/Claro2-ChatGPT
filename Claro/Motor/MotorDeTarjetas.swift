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

// MARK: - Conciliación entre cortes

nonisolated struct VerificacionContableEstado {
    let saldoEsperado: Double
    let diferencia: Double
    var esCoherente: Bool { abs(diferencia) <= 1.0 }
}

nonisolated enum ConciliadorEstadoCuenta {
    private static func moneda(_ valor: Double) -> Double {
        (valor * 100).rounded() / 100
    }

    /// Comprueba la ecuación impresa por el banco antes de guardar el corte.
    static func verificar(adeudoAnterior: Double,
                          cargosYCostos: Double,
                          pagosYAbonos: Double,
                          nuevoPagoParaNoGenerarIntereses: Double)
        -> VerificacionContableEstado {
        let esperado = moneda(max(0, adeudoAnterior + cargosYCostos - pagosYAbonos))
        return VerificacionContableEstado(
            saldoEsperado: esperado,
            diferencia: moneda(nuevoPagoParaNoGenerarIntereses - esperado))
    }

    /// En Banamex, el adeudo anterior del documento nuevo debe ser el PNGI
    /// que informó el corte previo. El pago posterior explica su liquidación,
    /// pero no modifica la cifra histórica que abre el siguiente resumen.
    static func diferenciaConCorteAnterior(
        adeudoAnteriorReportado: Double,
        corteAnterior: EstadoDeCuenta) -> Double {
        moneda(adeudoAnteriorReportado
            - corteAnterior.pagoParaNoGenerarIntereses)
    }
}

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

    /// Actividad que pertenece visualmente a un corte concreto. La
    /// importación es la fuente principal; los pagos se unen por el corte
    /// objetivo que tenían al registrarse. Para movimientos manuales antiguos
    /// sin lote se usa el periodo impreso por el banco.
    func movimientos(asociadosA estado: EstadoDeCuenta) -> [Movimiento] {
        let calendario = Calendar.current
        let finExclusivo = calendario.date(
            byAdding: .day, value: 1,
            to: calendario.startOfDay(for: estado.finPeriodo)
        ) ?? estado.finPeriodo

        return movimientos.filter { movimiento in
            if let lote = estado.importacionID,
               movimiento.importacionID == lote {
                return true
            }
            if let corteObjetivo = movimiento.fechaCorteObjetivoPago,
               calendario.isDate(corteObjetivo,
                                  inSameDayAs: estado.fechaCorte) {
                return true
            }
            guard movimiento.importacionID == nil,
                  movimiento.fecha >= estado.inicioPeriodo,
                  movimiento.fecha < finExclusivo else { return false }
            return movimiento.tipo != .pagoTarjeta
        }
        .sorted { $0.fecha > $1.fecha }
    }

    /// Actividad posterior al último corte, todavía no incluida por el banco.
    var movimientosDelPeriodoActual: [Movimiento] {
        guard let ultimoCorte = estadoDeCuentaVigente?.fechaCorte else {
            return movimientos.sorted { $0.fecha > $1.fecha }
        }
        return movimientos
            .filter { $0.fecha > ultimoCorte }
            .sorted { $0.fecha > $1.fecha }
    }

    /// Convierte los pagos creados por versiones anteriores en asignaciones
    /// de un solo corte. Primero reconstruye qué estado ya existía cuando se
    /// capturó el pago; si no hay metadatos antiguos suficientes, conserva la
    /// ventana histórica por fecha. Una vez sellado, un pago jamás puede
    /// saltar al estado que se importe después.
    @discardableResult
    func sellarAsignacionUnicaDePagos() -> Int {
        let estados = estadosDeCuenta.sorted { $0.fechaCorte < $1.fechaCorte }
        guard !estados.isEmpty else { return 0 }

        let registrosConocidos: [(estado: EstadoDeCuenta, fecha: Date)] =
            estados.compactMap { estado in
                if let fecha = estado.registradoEl {
                    return (estado, fecha)
                }
                guard let lote = estado.importacionID,
                      let fecha = movimientos
                        .filter({ $0.importacionID == lote })
                        .map(\.creadoEl).min()
                else { return nil }
                return (estado, fecha)
            }

        var sellados = 0
        for pago in movimientos
            where pago.tipo == .pagoTarjeta
                && pago.fechaCorteObjetivoPago == nil {
            let vigenteAlRegistrarlo = registrosConocidos
                .filter { $0.fecha <= pago.creadoEl }
                .max { $0.fecha < $1.fecha }?.estado
            let correspondientePorFecha = estados
                .last { $0.fechaCorte <= pago.fecha }
            guard let objetivo = vigenteAlRegistrarlo
                    ?? correspondientePorFecha
                    ?? estados.first
            else { continue }

            pago.fechaCorteObjetivoPago = objetivo.fechaCorte
            sellados += 1
        }
        return sellados
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
