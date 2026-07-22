//
//  CierreMensualView.swift
//  Claro
//

import SwiftData
import SwiftUI

struct CierreMensualView: View {
    @Query(sort: \Movimiento.fecha, order: .reverse)
    private var movimientos: [Movimiento]
    @Query(sort: \EstadoDeCuenta.fechaCorte, order: .reverse)
    private var estados: [EstadoDeCuenta]
    @Query private var personas: [Persona]

    @State private var mesSeleccionado = Calendar.current.dateInterval(
        of: .month,
        for: FechaAnalisisClaro.actual
    )?.start ?? FechaAnalisisClaro.actual

    private var meses: [Date] {
        let calendario = Calendar.current
        let encontrados = movimientos.map(\.fecha) + estados.map(\.fechaCorte)
        let normalizados = Set(encontrados.compactMap {
            calendario.dateInterval(of: .month, for: $0)?.start
        })
        let actual = calendario.dateInterval(
            of: .month,
            for: FechaAnalisisClaro.actual
        )?.start ?? FechaAnalisisClaro.actual
        return Array(normalizados.union([actual])).sorted(by: >)
    }

    private var resumen: ResumenCierreMensual {
        MotorCierreMensual.resumir(
            mes: mesSeleccionado,
            movimientos: movimientos,
            estados: estados,
            personas: personas
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Mes", selection: $mesSeleccionado) {
                    ForEach(meses, id: \.self) { mes in
                        Text(mes.formatted(.dateTime.month(.wide).year()))
                            .tag(mes)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("RESULTADO DEL MES")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Tema.textoSecundario)
                        Text(resumen.resultadoDelMes.comoDinero)
                            .font(.system(.largeTitle, design: .rounded).bold())
                            .foregroundStyle(resumen.resultadoDelMes >= 0
                                             ? Tema.positivo : Tema.urgente)
                        Text("Ingresos propios menos gastos propios generados durante el mes.")
                            .font(.caption)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                TituloSeccion(texto: "Actividad del mes")
                Panel {
                    VStack(spacing: 10) {
                        fila("Ingresos propios", resumen.ingresos, color: Tema.positivo)
                        fila("Gastos pagados directamente", resumen.gastosDirectos)
                        fila("Compras a crédito · tu parte", resumen.comprasCreditoPropias)
                        Divider().overlay(Tema.panelElevado)
                        fila("Gasto propio generado", resumen.gastoGenerado,
                             color: Tema.advertencia, destacado: true)
                    }
                }

                TituloSeccion(texto: "Movimiento de dinero")
                Panel {
                    VStack(spacing: 10) {
                        fila("Cobros recibidos de personas", resumen.cobrosRecibidos,
                             color: Tema.acento)
                        fila("Pagos a tarjetas", resumen.pagosTarjetas)
                        fila("Abonos a otras deudas", resumen.abonosDeudas)
                        if abs(resumen.ajustes) >= 0.01 {
                            fila("Ajustes", resumen.ajustes)
                        }
                        Divider().overlay(Tema.panelElevado)
                        fila("Cambio neto en cuentas", resumen.flujoDeEfectivo,
                             color: resumen.flujoDeEfectivo >= 0
                                ? Tema.positivo : Tema.urgente,
                             destacado: true)
                    }
                }

                TituloSeccion(texto: "Cortes y cobros")
                Panel {
                    VStack(spacing: 10) {
                        HStack {
                            Text("Cortes cubiertos")
                            Spacer()
                            Text("\(resumen.cortesCubiertos) de \(resumen.totalCortes)")
                                .fontWeight(.semibold)
                        }
                        fila("Pendiente de cortes", resumen.faltaCortes,
                             color: resumen.faltaCortes > 0
                                ? Tema.urgente : Tema.positivo)
                        fila("Por cobrar a personas al cierre",
                             resumen.porCobrarAlCierre,
                             color: Tema.acento)
                    }
                }

                Text("Los cobros familiares se muestran como entrada de efectivo, pero no como ingreso propio. Los pagos de tarjeta tampoco duplican el gasto: liquidan compras registradas previamente.")
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
                    .padding(.horizontal, 4)
            }
            .padding(16)
        }
        .background(FondoClaro())
        .navigationTitle("Cierre mensual")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fila(
        _ titulo: String,
        _ monto: Double,
        color: Color = Tema.textoPrincipal,
        destacado: Bool = false
    ) -> some View {
        HStack {
            Text(titulo)
                .font(destacado ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundStyle(Tema.textoSecundario)
            Spacer()
            Text(monto.comoDinero)
                .font(destacado ? .headline : .subheadline.weight(.semibold))
                .foregroundStyle(color)
        }
    }
}
