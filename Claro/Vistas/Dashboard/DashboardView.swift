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

    @Query(filter: #Predicate<CuentaBancaria> { !$0.archivada }) private var cuentas: [CuentaBancaria]
    @Query(filter: #Predicate<TarjetaCredito> { !$0.archivada }) private var tarjetas: [TarjetaCredito]
    @Query(filter: #Predicate<Persona> { !$0.archivada }) private var personas: [Persona]
    @Query private var planes: [PlanMSI]
    @Query(filter: #Predicate<Deuda> { !$0.archivada }) private var deudas: [Deuda]

    @AppStorage("montosOcultos") private var montosOcultos = false
    @AppStorage("apariencia") private var apariencia = Apariencia.oscuro.rawValue
    @State private var mostrandoClaroInteligente = false

    private var disponible: Double {
        MotorDashboard.disponibleReal(cuentas: cuentas, tarjetas: tarjetas)
    }
    private var dineroEnCuentas: Double {
        MotorDashboard.saldoTotal(cuentas: cuentas)
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
                    cabecera

                    accesoClaroInteligente

                    panelDisponible

                    HStack(spacing: 16) {
                        panelMini(titulo: "Comprometido",
                                  monto: comprometido,
                                  color: Tema.advertencia,
                                  icono: "lock.fill")
                        panelMini(titulo: "Te deben",
                                  monto: teDeben,
                                  color: Tema.acento,
                                  icono: "person.2.fill")
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
            .background(FondoClaro())
            .navigationTitle("Claro")
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

    private var cabecera: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("TU CAPITAL, EN CLARO")
                    .font(.caption2.weight(.bold))
                    .tracking(1.45)
                    .foregroundStyle(Tema.positivo)
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Tema.textoSecundario)
            }
            Spacer()
            Pildora(texto: disponible >= 0 ? "Bajo control" : "Requiere atención",
                    color: disponible >= 0 ? Tema.positivo : Tema.urgente)
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
                OrbeClaro(icono: "sparkles", color: Tema.violeta)
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
            .background(Tema.panel,
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [Tema.violeta.opacity(0.55),
                                                Tema.cyan.opacity(0.22), .clear],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing), lineWidth: 1)
            }
            .shadow(color: Tema.violeta.opacity(0.12), radius: 18, y: 9)
        }
        .buttonStyle(Presionable())
    }

    private var panelDisponible: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Tema.gradienteHero)
            Circle()
                .fill(Tema.cyan.opacity(0.16))
                .frame(width: 210, height: 210)
                .blur(radius: 20)
                .offset(x: 68, y: -92)
            Circle()
                .stroke(Tema.acento.opacity(0.12), lineWidth: 22)
                .frame(width: 150, height: 150)
                .offset(x: 58, y: 105)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("DINERO EN CUENTAS", systemImage: "wallet.bifold.fill")
                        .font(.caption2.weight(.bold))
                        .tracking(1.0)
                        .foregroundStyle(Tema.heroTexto)
                    Spacer()
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(Tema.positivo)
                }
                Text(dineroEnCuentas.comoDinero)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.68)
                    .monospacedDigit()
                    .foregroundStyle(dineroEnCuentas >= 0
                                     ? Tema.textoPrincipal : Tema.urgente)

                VStack(spacing: 9) {
                    HStack {
                        Text("Disponible después de apartar cortes")
                            .font(.footnote)
                            .foregroundStyle(Tema.heroTexto)
                        Spacer()
                        Text(disponible.comoDinero)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(disponible >= 0
                                             ? Tema.positivo : Tema.urgente)
                    }
                    GeometryReader { geo in
                        let proporcion = dineroEnCuentas > 0
                            ? CGFloat(max(0, min(1, disponible / dineroEnCuentas)))
                            : 0
                        ZStack(alignment: .leading) {
                            Capsule().fill(Tema.heroBorde.opacity(0.55))
                            Capsule().fill(Tema.gradienteAccion)
                                .frame(width: geo.size.width * proporcion)
                        }
                    }
                    .frame(height: 7)
                    Text("El resto ya está reservado para tus cortes vigentes.")
                        .font(.caption2)
                        .foregroundStyle(Tema.textoSecundario)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous)
            .strokeBorder(Tema.heroBorde.opacity(0.75), lineWidth: 1))
        .shadow(color: Tema.acento.opacity(0.12), radius: 24, y: 12)
    }

    private func panelMini(titulo: String, monto: Double,
                           color: Color, icono: String) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: icono)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 9,
                                                     style: .continuous))
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
        let estaVencido = estado.situacion == .vencidoSinCubrir
            || estado.situacion == .vencidoParcialmenteCubierto
        let color: Color = estaVencido ? Tema.urgente
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
                Pildora(texto: estado.situacion == .parcialmenteCubierto
                         ? "Pago parcial"
                         : dias >= 0 ? "\(dias) días" : estado.situacion.titulo,
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
