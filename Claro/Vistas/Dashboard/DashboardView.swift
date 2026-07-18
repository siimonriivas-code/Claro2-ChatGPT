//
//  DashboardView.swift
//  Claro — Carpeta: Vistas/Dashboard
//  ⚠️ REEMPLAZA al existente.
//
//  🎉 SE ACABARON LOS NÚMEROS FICTICIOS.
//  Todo lo que ves aquí ahora viene del Motor financiero (Ley 1):
//  disponible real, comprometido, pagos próximos, te deben e insights.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.colorScheme) private var esquemaActual

    @Query private var cuentas: [CuentaBancaria]
    @Query private var tarjetas: [TarjetaCredito]
    @Query private var personas: [Persona]
    @Query private var planes: [PlanMSI]
    @Query private var deudas: [Deuda]

    @AppStorage("montosOcultos") private var montosOcultos = false
    @AppStorage("apariencia") private var apariencia = Apariencia.oscuro.rawValue
    @State private var mostrandoClaroInteligente = false

    private var disponible: Double {
        MotorDashboard.disponibleReal(cuentas: cuentas, tarjetas: tarjetas)
    }
    private var comprometido: Double {
        MotorDashboard.comprometido(tarjetas: tarjetas)
    }
    private var teDeben: Double {
        MotorDashboard.totalTeDeben(personas: personas)
    }
    private var pagosProximos: [EstadoDeCuenta] {
        MotorDashboard.pagosProximos(tarjetas: tarjetas)
    }
    private var insights: [Insight] {
        MotorDashboard.insights(cuentas: cuentas, tarjetas: tarjetas,
                                personas: personas, planes: planes,
                                deudas: deudas)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Fecha del día (diseño Claro Premium)
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(1.1)
                        .foregroundStyle(Tema.textoSecundario)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    accesoClaroInteligente

                    panelDisponible

                    HStack(spacing: 16) {
                        panelMini(titulo: "Comprometido",
                                  monto: comprometido,
                                  color: Tema.advertencia)
                        panelMini(titulo: "Te deben",
                                  monto: teDeben,
                                  color: Tema.acento)
                    }

                    if !pagosProximos.isEmpty {
                        TituloSeccion(texto: "Pagos próximos")
                        ForEach(pagosProximos, id: \.persistentModelID) { estado in
                            panelPagoProximo(estado)
                        }
                    }

                    if !insights.isEmpty {
                        TituloSeccion(texto: "Insights")
                        ForEach(insights) { insight in
                            panelInsight(insight)
                        }
                    }

                    if cuentas.isEmpty && tarjetas.isEmpty {
                        Panel {
                            Text("Da de alta tus bancos, cuentas y tarjetas en la pestaña Cuentas para que este tablero cobre vida.")
                                .font(.footnote)
                                .foregroundStyle(Tema.textoSecundario)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(16)
            }
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Inicio")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        mostrandoClaroInteligente = true
                    } label: {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Tema.acento)
                    }
                    .accessibilityLabel("Abrir Claro Inteligente")

                    Button {
                        alternarApariencia()
                    } label: {
                        Image(systemName: esquemaActual == .dark
                              ? "sun.max.fill" : "moon.fill")
                            .foregroundStyle(Tema.textoSecundario)
                    }
                    .accessibilityLabel(esquemaActual == .dark
                                        ? "Activar modo claro"
                                        : "Activar modo oscuro")

                    Button {
                        montosOcultos.toggle()
                    } label: {
                        Image(systemName: montosOcultos ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(Tema.textoSecundario)
                    }
                }
            }
            .sheet(isPresented: $mostrandoClaroInteligente) {
                ClaroInteligenteView()
            }
        }
    }

    /// Acceso rápido desde Inicio. Si la app seguía al sistema, toma el
    /// aspecto que se ve en ese momento y cambia al contrario.
    private func alternarApariencia() {
        apariencia = esquemaActual == .dark
            ? Apariencia.claro.rawValue
            : Apariencia.oscuro.rawValue
    }

    private var accesoClaroInteligente: some View {
        Button {
            mostrandoClaroInteligente = true
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Tema.acento)
                    .frame(width: 44, height: 44)
                    .background(Tema.acento.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Pregúntale a Claro")
                        .font(.headline)
                        .foregroundStyle(Tema.textoPrincipal)
                    Text("Analiza, proyecta y evalúa decisiones con tus datos")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Tema.textoSecundario)
            }
            .padding(16)
            .background(
                LinearGradient(colors: [Tema.acento.opacity(0.15), Tema.panel],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Tema.acento.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(Presionable())
    }

    private var panelDisponible: some View {
        Panel {
            VStack(alignment: .leading, spacing: 6) {
                Text("DISPONIBLE REAL")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Tema.textoSecundario)
                Text(disponible.comoDinero)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(disponible >= 0 ? Tema.positivo : Tema.urgente)
                Text("Dinero en cuentas menos lo comprometido en pagos de tarjetas")
                    .font(.footnote)
                    .foregroundStyle(Tema.textoSecundario)
            }
        }
    }

    private func panelMini(titulo: String, monto: Double, color: Color) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 6) {
                Text(titulo.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Tema.textoSecundario)
                Text(monto.comoDinero)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(color)
            }
        }
    }

    private func panelPagoProximo(_ estado: EstadoDeCuenta) -> some View {
        let dias = estado.diasParaVencer
        let color: Color = estado.situacion == .vencidoSinCubrir ? Tema.urgente
                         : dias <= 3 ? Tema.urgente
                         : dias <= 7 ? Tema.advertencia
                         : Tema.positivo

        return Panel {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(estado.tarjeta?.nombre ?? "Tarjeta")
                        .font(.headline)
                        .foregroundStyle(Tema.textoPrincipal)
                    Text("Falta cubrir: \(estado.faltaPorCubrir.comoDinero) · vence \(estado.fechaLimitePago.formatted(date: .abbreviated, time: .omitted))")
                        .font(.footnote)
                        .foregroundStyle(Tema.textoSecundario)
                }
                Spacer()
                Pildora(texto: dias >= 0 ? "\(dias) días" : "Vencido",
                        color: color)
            }
        }
    }

    private func panelInsight(_ insight: Insight) -> some View {
        Panel {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: insight.icono)
                    .font(.title3)
                    .foregroundStyle(insight.esUrgente ? Tema.urgente : Tema.acento)
                Text(insight.texto)
                    .font(.footnote)
                    .foregroundStyle(Tema.textoPrincipal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
