//
//  AnalisisView.swift
//  Claro — Carpeta: Vistas/Analisis
//  ⚠️ REEMPLAZA al existente.
//
//  Novedad: gráficas premium con Swift Charts (nativas de Apple):
//  · Dona de gastos por categoría del mes (tu parte)
//  · Barras de ingresos vs gastos por mes
//  Conserva el engrane de Configuración y los compromisos MSI.
//

import SwiftUI
import SwiftData
import Charts

struct AnalisisView: View {
    @Query(sort: \Movimiento.fecha, order: .reverse) private var movimientos: [Movimiento]
    @Query private var planes: [PlanMSI]
    @Query private var cuentas: [CuentaBancaria]
    @Query private var tarjetas: [TarjetaCredito]
    @Query private var personas: [Persona]
    @Query private var deudas: [Deuda]

    @State private var mostrandoConfiguracion = false

    // MARK: - Historial mensual
    private struct ResumenMes: Identifiable {
        let id: Date
        var ingresos: Double
        var egresos: Double
    }

    private var resumenesMensuales: [ResumenMes] {
        let calendario = Calendar.current
        var dict: [Date: ResumenMes] = [:]

        for m in movimientos where m.cuentaParaCalculos {
            let clave = calendario.date(from:
                calendario.dateComponents([.year, .month], from: m.fecha)) ?? m.fecha
            var resumen = dict[clave] ?? ResumenMes(id: clave, ingresos: 0, egresos: 0)
            switch m.tipo {
            case .ingreso:
                resumen.ingresos += m.monto
            case .gasto, .compraCredito:
                resumen.egresos += m.montoPropio   // solo TU parte
            default:
                break
            }
            dict[clave] = resumen
        }
        return dict.values.sorted { $0.id > $1.id }
    }

    // Datos "aplanados" para la gráfica de barras (últimos 6 meses)
    private struct PuntoMensual: Identifiable {
        let id = UUID()
        let mes: Date
        let tipo: String
        let monto: Double
    }

    private var puntosMensuales: [PuntoMensual] {
        resumenesMensuales.prefix(6).flatMap { resumen in
            [PuntoMensual(mes: resumen.id, tipo: "Ingresos", monto: resumen.ingresos),
             PuntoMensual(mes: resumen.id, tipo: "Gastos", monto: resumen.egresos)]
        }
    }

    // MARK: - Categorías del mes actual
    private struct GastoCategoria: Identifiable {
        let id: String
        let icono: String
        let colorHex: String
        let monto: Double
    }

    private var gastosPorCategoria: [GastoCategoria] {
        let calendario = Calendar.current
        let ahora = Date.now
        var dict: [String: (icono: String, color: String, monto: Double)] = [:]

        for m in movimientos where m.cuentaParaCalculos
            && (m.tipo == .gasto || m.tipo == .compraCredito)
            && calendario.isDate(m.fecha, equalTo: ahora, toGranularity: .month) {

            let nombre = m.categoria?.nombre ?? "Sin categoría"
            let icono = m.categoria?.icono ?? "questionmark.circle.fill"
            let color = m.categoria?.colorHex ?? "8A93A6"
            var actual = dict[nombre] ?? (icono, color, 0)
            actual.monto += m.montoPropio
            dict[nombre] = actual
        }

        return dict.map {
            GastoCategoria(id: $0.key, icono: $0.value.icono,
                           colorHex: $0.value.color, monto: $0.value.monto)
        }
        .sorted { $0.monto > $1.monto }
    }

    private var totalMesActual: Double {
        gastosPorCategoria.reduce(0) { $0 + $1.monto }
    }

    private var planesActivos: [PlanMSI] {
        planes.filter { !$0.estaConcluidoReal }
              .sorted { $0.fechaCompra > $1.fechaCompra }
    }

    private var recurrentes: [CargoRecurrenteDetectado] {
        MotorPredictivo.recurrentes(movimientos: movimientos)
    }

    private var patrimonio: Double {
        MotorPredictivo.patrimonioActual(cuentas: cuentas, tarjetas: tarjetas,
                                         personas: personas, deudas: deudas)
    }

    private var disponible30: Double {
        MotorPredictivo.disponibleEn30Dias(cuentas: cuentas, tarjetas: tarjetas,
                                           recurrentes: recurrentes)
    }

    private var historialPatrimonio: [PuntoPatrimonio] {
        MotorPredictivo.historialPatrimonio(cuentas: cuentas, tarjetas: tarjetas,
                                            personas: personas, deudas: deudas)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    TituloSeccion(texto: "Panorama financiero")
                    Panel {
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("PATRIMONIO ESTIMADO")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Tema.textoSecundario)
                                    Text(patrimonio.comoDinero)
                                        .font(.title2.bold())
                                        .foregroundStyle(patrimonio >= 0
                                                         ? Tema.positivo : Tema.urgente)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text("DISPONIBLE EN 30 DÍAS")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Tema.textoSecundario)
                                    Text(disponible30.comoDinero)
                                        .font(.headline)
                                        .foregroundStyle(disponible30 >= 0
                                                         ? Tema.acento : Tema.urgente)
                                }
                            }
                            if historialPatrimonio.count > 1 {
                                Chart(historialPatrimonio) { punto in
                                    LineMark(x: .value("Mes", punto.id),
                                             y: .value("Patrimonio", punto.valor))
                                        .foregroundStyle(Tema.positivo)
                                    AreaMark(x: .value("Mes", punto.id),
                                             y: .value("Patrimonio", punto.valor))
                                        .foregroundStyle(Tema.positivo.opacity(0.12))
                                }
                                .chartXAxis {
                                    AxisMarks(values: .stride(by: .month)) {
                                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                                    }
                                }
                                .frame(height: 150)
                            }
                        }
                    }

                    // ── 🍩 Dona: gastos del mes por categoría ──
                    TituloSeccion(texto: "Este mes por categoría (tu parte)")
                    if gastosPorCategoria.isEmpty {
                        Panel {
                            Text("Sin gastos registrados este mes.")
                                .font(.footnote)
                                .foregroundStyle(Tema.textoSecundario)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        Panel {
                            VStack(spacing: 14) {
                                ZStack {
                                    Chart(gastosPorCategoria) { gasto in
                                        SectorMark(
                                            angle: .value("Monto", gasto.monto),
                                            innerRadius: .ratio(0.66),
                                            angularInset: 2)
                                        .cornerRadius(5)
                                        .foregroundStyle(Color(hex: gasto.colorHex))
                                    }
                                    .frame(height: 210)

                                    VStack(spacing: 2) {
                                        Text("TOTAL")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(Tema.textoSecundario)
                                        Text(totalMesActual.comoDinero)
                                            .font(.system(.title3, design: .rounded).weight(.bold))
                                            .foregroundStyle(Tema.textoPrincipal)
                                    }
                                }

                                VStack(spacing: 0) {
                                    ForEach(gastosPorCategoria) { gasto in
                                        HStack(spacing: 12) {
                                            Image(systemName: gasto.icono)
                                                .foregroundStyle(Color(hex: gasto.colorHex))
                                                .frame(width: 28)
                                            Text(gasto.id)
                                                .font(.subheadline)
                                                .foregroundStyle(Tema.textoPrincipal)
                                            Spacer()
                                            if totalMesActual > 0 {
                                                Text("\(Int((gasto.monto / totalMesActual) * 100))%")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(Tema.textoSecundario)
                                            }
                                            Text(gasto.monto.comoDinero)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Tema.textoPrincipal)
                                        }
                                        .padding(.vertical, 7)
                                        if gasto.id != gastosPorCategoria.last?.id {
                                            Divider().overlay(Tema.panelElevado)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── 📊 Barras: ingresos vs gastos por mes ──
                    if !puntosMensuales.isEmpty {
                        TituloSeccion(texto: "Ingresos vs gastos (últimos meses)")
                        Panel {
                            Chart(puntosMensuales) { punto in
                                BarMark(
                                    x: .value("Mes", punto.mes, unit: .month),
                                    y: .value("Monto", punto.monto))
                                .position(by: .value("Tipo", punto.tipo))
                                .foregroundStyle(by: .value("Tipo", punto.tipo))
                                .cornerRadius(4)
                            }
                            .chartForegroundStyleScale([
                                "Ingresos": Tema.positivo,
                                "Gastos": Tema.acento
                            ])
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .month)) {
                                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                                }
                            }
                            .frame(height: 220)
                        }
                    }

                    if !recurrentes.isEmpty {
                        TituloSeccion(texto: "Cargos recurrentes detectados")
                        Panel {
                            VStack(spacing: 0) {
                                ForEach(recurrentes.prefix(8)) { cargo in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(cargo.comercio)
                                                .font(.subheadline.weight(.medium))
                                                .lineLimit(1)
                                            Text("Próximo estimado: \(cargo.siguienteFechaEstimada.formatted(date: .abbreviated, time: .omitted))")
                                                .font(.caption2)
                                                .foregroundStyle(Tema.textoSecundario)
                                        }
                                        Spacer()
                                        Text(cargo.promedio.comoDinero)
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .padding(.vertical, 7)
                                    if cargo.id != recurrentes.prefix(8).last?.id {
                                        Divider().overlay(Tema.panelElevado)
                                    }
                                }
                            }
                        }
                    }

                    // ── Detalle mes a mes ──
                    TituloSeccion(texto: "Historial mensual")
                    if resumenesMensuales.isEmpty {
                        Panel {
                            Text("Aquí aparecerá tu historia mes a mes conforme registres movimientos.")
                                .font(.footnote)
                                .foregroundStyle(Tema.textoSecundario)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        ForEach(resumenesMensuales) { mes in
                            Panel {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(mes.id.formatted(.dateTime.month(.wide).year()).capitalized)
                                        .font(.headline)
                                        .foregroundStyle(Tema.textoPrincipal)
                                    HStack {
                                        Label("Ingresos", systemImage: "arrow.down.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(Tema.textoSecundario)
                                        Spacer()
                                        Text("+" + mes.ingresos.comoDinero)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Tema.positivo)
                                    }
                                    HStack {
                                        Label("Gastos (tu parte)", systemImage: "arrow.up.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(Tema.textoSecundario)
                                        Spacer()
                                        Text("−" + mes.egresos.comoDinero)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Tema.textoPrincipal)
                                    }
                                    Divider().overlay(Tema.panelElevado)
                                    HStack {
                                        Text("Balance")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Tema.textoSecundario)
                                        Spacer()
                                        let balance = mes.ingresos - mes.egresos
                                        Text(balance.comoDinero)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(balance >= 0
                                                             ? Tema.positivo : Tema.urgente)
                                    }
                                }
                            }
                        }
                    }

                    // ── Compromisos futuros por MSI ──
                    if !planesActivos.isEmpty {
                        TituloSeccion(texto: "Compromisos futuros (MSI)")
                        ForEach(planesActivos) { plan in
                            Panel {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(plan.detalle.isEmpty ? "Compra a MSI" : plan.detalle)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Tema.textoPrincipal)
                                        Spacer()
                                        Text("\(plan.mensualidadTipica.comoDinero)/mes")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Tema.textoSecundario)
                                    }
                                    if plan.montoPendienteDeCubrir > 0 {
                                        Text("Ya generado y sin cubrir: \(plan.montoPendienteDeCubrir.comoDinero)")
                                            .font(.caption)
                                            .foregroundStyle(Tema.advertencia)
                                    }
                                    if plan.compromisoFuturo > 0 {
                                        Text("Aún por generar en meses futuros: \(plan.compromisoFuturo.comoDinero)")
                                            .font(.caption)
                                            .foregroundStyle(Tema.acento)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Análisis")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        PlanificacionView()
                    } label: {
                        Image(systemName: "target")
                            .foregroundStyle(Tema.positivo)
                    }
                    Button {
                        mostrandoConfiguracion = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Tema.textoSecundario)
                    }
                }
            }
            .sheet(isPresented: $mostrandoConfiguracion) {
                ConfiguracionView()
            }
        }
    }
}
