//
//  RaizView.swift
//  Claro — Carpeta: Vistas
//  ⚠️ REEMPLAZA al existente.
//
//  Novedades: cortina de Face ID (se vuelve a bloquear al ir al fondo)
//  y reprogramación automática de notificaciones al abrir la app.
//

import SwiftUI
import SwiftData

struct RaizView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.scenePhase) private var fase

    @AppStorage("bloqueoActivado") private var bloqueoActivado = false
    @AppStorage("notificacionesActivadas") private var notificacionesActivadas = false

    @Query(filter: #Predicate<TarjetaCredito> { !$0.archivada }) private var tarjetas: [TarjetaCredito]
    @Query(filter: #Predicate<Persona> { !$0.archivada }) private var personas: [Persona]
    @Query private var bancos: [Banco]
    @Query(filter: #Predicate<CuentaBancaria> { !$0.archivada }) private var cuentas: [CuentaBancaria]

    @AppStorage("montosOcultos") private var montosOcultos = false

    @State private var desbloqueada = false
    @State private var mostrandoBienvenida = false
    @State private var mostrandoRegistro = false
    @AppStorage("onboardingCompletado") private var onboardingCompletado = false

    var body: some View {
        ZStack {
            TabView {
                DashboardView()
                    .tabItem { Label("Inicio", systemImage: "house.fill") }

                CuentasView()
                    .tabItem { Label("Cuentas", systemImage: "creditcard.fill") }

                PersonasView()
                    .tabItem { Label("Personas", systemImage: "person.2.fill") }

                AnalisisView()
                    .tabItem { Label("Análisis", systemImage: "chart.bar.xaxis") }
            }
            .tint(Tema.positivo)
            // Al cambiar el modo privacidad, toda la app se redibuja
            // (con un fundido suave para que no se sienta el golpe)
            .id(montosOcultos)
            .animation(.easeInOut(duration: 0.25), value: montosOcultos)
            .overlay(alignment: .bottom) {
                Button {
                    mostrandoRegistro = true
                } label: {
                    Label("Registrar", systemImage: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 48)
                        .background(Tema.gradienteAccion, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.8))
                        .shadow(color: Tema.positivo.opacity(0.30), radius: 16, y: 8)
                }
                .buttonStyle(Presionable())
                .padding(.bottom, 62)
                .accessibilityHint("Abre las opciones para registrar un movimiento")
            }

            if bloqueoActivado && !desbloqueada {
                BloqueoView { desbloqueada = true }
                    .transition(.opacity)
            }

            // Evita que el selector de apps o una captura de transición
            // expongan saldos mientras Claro no está activo.
            if fase != .active {
                FondoClaro()
            }
        }
        .aparienciaDeLaApp()
        .task {
            MigradorDatosClaro.ejecutarSiHaceFalta(contexto: contexto)
            Sembrador.sembrarSiHaceFalta(contexto: contexto)
            if !onboardingCompletado && bancos.isEmpty
                && cuentas.isEmpty && tarjetas.isEmpty {
                mostrandoBienvenida = true
            }
            if notificacionesActivadas {
                ProgramadorDeNotificaciones.reprogramar(tarjetas: tarjetas,
                                                        personas: personas)
            }
        }
        .onChange(of: fase) { _, nuevaFase in
            if nuevaFase != .active {
                // Al irse al fondo, la app vuelve a quedar bloqueada
                desbloqueada = false
            }
            if nuevaFase == .active && notificacionesActivadas {
                // Al regresar, los recordatorios se actualizan a la realidad
                ProgramadorDeNotificaciones.reprogramar(tarjetas: tarjetas,
                                                        personas: personas)
            }
        }
        .fullScreenCover(isPresented: $mostrandoBienvenida) {
            BienvenidaClaroView {
                onboardingCompletado = true
                mostrandoBienvenida = false
            }
        }
        .sheet(isPresented: $mostrandoRegistro) {
            RegistrarView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    RaizView()
}
