//
//  MotorDashboard.swift
//  Claro — Carpeta: Motor
//
//  Los cálculos de la pantalla de los 10 segundos y los insights
//  inteligentes. Todo local, todo calculado, nada escrito a mano.
//

import Foundation

struct Insight: Identifiable {
    let id = UUID()
    let icono: String
    let texto: String
    let esUrgente: Bool
}

enum MotorDashboard {

    /// Dinero que técnicamente tienes pero YA tiene dueño:
    /// lo que falta por cubrir de los cortes vigentes no cubiertos.
    static func comprometido(tarjetas: [TarjetaCredito]) -> Double {
        tarjetas
            .compactMap { $0.estadoDeCuentaVigente }
            .filter { $0.situacion != .cubierto }
            .reduce(0) { $0 + $1.faltaPorCubrir }
    }

    static func saldoTotal(cuentas: [CuentaBancaria]) -> Double {
        cuentas.reduce(0) { $0 + $1.saldoCalculado }
    }

    /// ⭐ El número grande: lo que puedes gastar sin meterte en problemas.
    static func disponibleReal(cuentas: [CuentaBancaria],
                               tarjetas: [TarjetaCredito]) -> Double {
        saldoTotal(cuentas: cuentas) - comprometido(tarjetas: tarjetas)
    }

    /// Cortes con dinero pendiente, ordenados por urgencia.
    static func pagosProximos(tarjetas: [TarjetaCredito]) -> [EstadoDeCuenta] {
        tarjetas
            .compactMap { $0.estadoDeCuentaVigente }
            .filter { $0.faltaPorCubrir > 0 }
            .sorted { $0.diasParaVencer < $1.diasParaVencer }
    }

    static func totalTeDeben(personas: [Persona]) -> [Double].Element {
        personas.reduce(0) { $0 + max(0, $1.saldoPendiente) }
    }

    /// Las tarjetas de aviso inteligente del dashboard.
    static func insights(cuentas: [CuentaBancaria],
                         tarjetas: [TarjetaCredito],
                         personas: [Persona],
                         planes: [PlanMSI],
                         deudas: [Deuda] = []) -> [Insight] {

        var lista: [Insight] = []
        let total = saldoTotal(cuentas: cuentas)
        let comprometidoTotal = comprometido(tarjetas: tarjetas)

        // 1. Cortes vencidos sin cubrir (lo más grave)
        for estado in tarjetas.compactMap({ $0.estadoDeCuentaVigente })
            where estado.situacion == .vencidoSinCubrir
                || estado.situacion == .vencidoParcialmenteCubierto {
            lista.append(Insight(
                icono: "exclamationmark.triangle.fill",
                texto: "\(estado.tarjeta?.nombre ?? "Una tarjeta") tiene un corte vencido. Faltan \(estado.faltaPorCubrir.comoDinero) después de los pagos registrados.",
                esUrgente: true))
        }

        // 2. Riesgo: un pago próximo es mayor que todo tu dinero en cuentas
        for estado in pagosProximos(tarjetas: tarjetas)
            where estado.situacion != .vencidoSinCubrir
               && estado.situacion != .vencidoParcialmenteCubierto
               && estado.faltaPorCubrir > total {
            lista.append(Insight(
                icono: "exclamationmark.circle.fill",
                texto: "Riesgo: a \(estado.tarjeta?.nombre ?? "una tarjeta") le faltan \(estado.faltaPorCubrir.comoDinero) y en tus cuentas hay \(total.comoDinero).",
                esUrgente: true))
        }

        // 3. Porcentaje comprometido alto
        if total > 0 && comprometidoTotal / total >= 0.6 {
            let porcentaje = Int((comprometidoTotal / total) * 100)
            lista.append(Insight(
                icono: "chart.pie.fill",
                texto: "El \(porcentaje)% del dinero en tus cuentas ya está comprometido en pagos de tarjetas.",
                esUrgente: false))
        }

        // 4. Compromiso futuro por MSI
        let futuroMSI = planes.reduce(0) { $0 + $1.compromisoFuturo }
        if futuroMSI > 0 {
            lista.append(Insight(
                icono: "calendar.badge.clock",
                texto: "Tus compras a MSI seguirán cobrando \(futuroMSI.comoDinero) en meses futuros.",
                esUrgente: false))
        }

        // 5. Personas que te deben
        for persona in personas where persona.saldoPendiente > 0 {
            lista.append(Insight(
                icono: "person.fill.questionmark",
                texto: "\(persona.nombre) todavía te debe \(persona.saldoPendiente.comoDinero).",
                esUrgente: false))
        }

        // 5b. Deudas propias pendientes
        let totalDeudas = deudas.reduce(0) { $0 + $1.saldoRestante }
        if totalDeudas > 0 {
            lista.append(Insight(
                icono: "banknote.fill",
                texto: "Tienes \(totalDeudas.comoDinero) pendientes en deudas personales fuera de tarjetas.",
                esUrgente: false))
        }

        // 6. Recordatorio: ya cortó y no has cargado el estado de cuenta
        for tarjeta in tarjetas {
            guard let corteProgramado = ultimoCorteProgramado(para: tarjeta) else { continue }
            let hoy = Calendar.current.startOfDay(for: .now)
            let dias = Calendar.current.dateComponents([.day],
                                                       from: corteProgramado,
                                                       to: hoy).day ?? 0
            let yaRegistrado = tarjeta.estadosDeCuenta.contains {
                abs($0.fechaCorte.timeIntervalSince(corteProgramado)) < 6 * 86_400
            }
            if dias >= 4 && dias <= 20 && !yaRegistrado {
                lista.append(Insight(
                    icono: "scissors",
                    texto: "Tu \(tarjeta.nombre) cortó hace \(dias) días. Descarga el estado de cuenta del banco e impórtalo desde el detalle de la tarjeta.",
                    esUrgente: false))
            }
        }

        return lista
    }

    /// La fecha de corte "programada" más reciente según el día de corte
    /// configurado en la tarjeta (con ajuste para meses cortos).
    private static func ultimoCorteProgramado(para tarjeta: TarjetaCredito) -> Date? {
        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: .now)
        for offsetMes in [0, -1] {
            guard let mesBase = calendario.date(byAdding: .month,
                                                value: offsetMes, to: hoy)
            else { continue }
            var componentes = calendario.dateComponents([.year, .month], from: mesBase)
            let diasDelMes = calendario.range(of: .day, in: .month, for: mesBase)?.count ?? 28
            componentes.day = min(tarjeta.diaCorte, diasDelMes)
            if let fecha = calendario.date(from: componentes), fecha <= hoy {
                return fecha
            }
        }
        return nil
    }
}
