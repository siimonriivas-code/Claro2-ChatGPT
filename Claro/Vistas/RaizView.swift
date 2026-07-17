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

    @Query private var tarjetas: [TarjetaCredito]
    @Query private var personas: [Persona]

    @AppStorage("montosOcultos") private var montosOcultos = false

    @State private var desbloqueada = false

    var body: some View {
        ZStack {
            TabView {
                DashboardView()
                    .tabItem { Label("Inicio", systemImage: "house.fill") }

                CuentasView()
                    .tabItem { Label("Cuentas", systemImage: "creditcard.fill") }

                RegistrarView()
                    .tabItem { Label("Registrar", systemImage: "plus.circle.fill") }

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

            if bloqueoActivado && !desbloqueada {
                BloqueoView { desbloqueada = true }
                    .transition(.opacity)
            }
        }
        .aparienciaDeLaApp()
        .task {
            Sembrador.sembrarSiHaceFalta(contexto: contexto)
            if notificacionesActivadas {
                ProgramadorDeNotificaciones.reprogramar(tarjetas: tarjetas,
                                                        personas: personas)
            }
        }
        .onChange(of: fase) { _, nuevaFase in
            if nuevaFase == .background {
                // Al irse al fondo, la app vuelve a quedar bloqueada
                desbloqueada = false
            }
            if nuevaFase == .active && notificacionesActivadas {
                // Al regresar, los recordatorios se actualizan a la realidad
                ProgramadorDeNotificaciones.reprogramar(tarjetas: tarjetas,
                                                        personas: personas)
            }
        }
    }
}

#Preview {
    RaizView()
}
