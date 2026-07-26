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
    @AppStorage("permisoNotificacionesSolicitado") private var permisoNotificacionesSolicitado = false
    @AppStorage("respaldoICloudAutomatico") private var respaldoICloudAutomatico = true
    @AppStorage("modoHistoricoActivo") private var modoHistoricoActivo = false
    @AppStorage("fechaAnalisisReferencia")
    private var fechaAnalisisReferencia = Date.now.timeIntervalSince1970

    @Query(filter: #Predicate<TarjetaCredito> { !$0.archivada }) private var tarjetas: [TarjetaCredito]
    @Query(filter: #Predicate<Persona> { !$0.archivada }) private var personas: [Persona]
    @Query private var bancos: [Banco]
    @Query(filter: #Predicate<CuentaBancaria> { !$0.archivada }) private var cuentas: [CuentaBancaria]
    @Query private var estadosDeCuenta: [EstadoDeCuenta]
    @Query private var movimientos: [Movimiento]

    @AppStorage("montosOcultos") private var montosOcultos = false

    @State private var desbloqueada = false
    @State private var mostrandoBienvenida = false
    @State private var mostrandoRegistro = false
    @ObservedObject private var enrutador = EnrutadorDeNotificaciones.compartido
    @AppStorage("onboardingCompletado") private var onboardingCompletado = false

    /// CloudKit puede entregar primero las cuentas y después sus cortes o
    /// movimientos. Esta huella vuelve a intentar migraciones pendientes
    /// cuando cualquiera de esas piezas termina de llegar.
    private var huellaDatosFinancieros: String {
        [
            tarjetas.count,
            cuentas.count,
            estadosDeCuenta.count,
            movimientos.count
        ].map(String.init).joined(separator: "-")
    }

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
            .safeAreaInset(edge: .top, spacing: 0) {
                if modoHistoricoActivo {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        Text(
                            "Periodo histórico · "
                            + Date(
                                timeIntervalSince1970:
                                    fechaAnalisisReferencia
                            ).formatted(
                                date: .abbreviated,
                                time: .omitted
                            )
                        )
                        .font(.caption.weight(.semibold))
                        Spacer()
                        Button("Volver a hoy") {
                            FechaAnalisisClaro.volverAHoy()
                            modoHistoricoActivo = false
                        }
                        .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Tema.advertencia)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(Tema.advertencia.opacity(0.12))
                }
            }
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
        .task(id: huellaDatosFinancieros) {
            MigradorDatosClaro.ejecutarSiHaceFalta(contexto: contexto)
        }
        .task {
            Sembrador.sembrarSiHaceFalta(contexto: contexto)
            FechaAnalisisClaro.alinearUnaVezConPeriodoActual(
                tarjetas: tarjetas
            )
            _ = try? AdministradorProteccionDatos.crearPuntoSiCorresponde(
                contexto: contexto
            )
            if !onboardingCompletado && bancos.isEmpty
                && cuentas.isEmpty && tarjetas.isEmpty {
                mostrandoBienvenida = true
            }
            if !permisoNotificacionesSolicitado {
                permisoNotificacionesSolicitado = true
                ProgramadorDeNotificaciones.pedirPermiso { autorizado in
                    notificacionesActivadas = autorizado
                    if autorizado {
                        ProgramadorDeNotificaciones.reprogramar(
                            tarjetas: tarjetas, personas: personas)
                    }
                }
            }
            if notificacionesActivadas {
                ProgramadorDeNotificaciones.reprogramar(tarjetas: tarjetas,
                                                        personas: personas)
            }
            if respaldoICloudAutomatico {
                await AdministradorICloud.respaldarSiCorresponde(
                    contexto: contexto)
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
            if nuevaFase == .background && respaldoICloudAutomatico {
                Task {
                    await AdministradorICloud.respaldarSiCorresponde(
                        contexto: contexto, intervaloMinimo: 0)
                }
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
        .sheet(item: $enrutador.destino) { destino in
            destinoDeNotificacion(destino)
        }
    }

    @ViewBuilder
    private func destinoDeNotificacion(
        _ destino: DestinoNotificacionClaro
    ) -> some View {
        switch destino.tipo {
        case .importarEstado:
            if let tarjeta = tarjeta(con: destino.identificador) {
                ImportarEstadoView(tarjeta: tarjeta)
            } else {
                destinoNoDisponible("La tarjeta ya no está disponible.")
            }
        case .pagarTarjeta:
            if let tarjeta = tarjeta(con: destino.identificador) {
                PagoTarjetaView(tarjetaInicial: tarjeta)
            } else {
                destinoNoDisponible("La tarjeta ya no está disponible.")
            }
        case .verTarjeta:
            if let tarjeta = tarjeta(con: destino.identificador) {
                NavigationStack { TarjetaDetalleView(tarjeta: tarjeta) }
                    .aparienciaDeLaApp()
            } else {
                destinoNoDisponible("La tarjeta ya no está disponible.")
            }
        case .verPersona:
            if let persona = persona(con: destino.identificador) {
                NavigationStack { PersonaDetalleView(persona: persona) }
                    .aparienciaDeLaApp()
            } else {
                destinoNoDisponible("La persona ya no está disponible.")
            }
        case .verPersonas:
            PersonasView()
                .aparienciaDeLaApp()
        }
    }

    private func tarjeta(con identificador: String?) -> TarjetaCredito? {
        tarjetas.first { $0.identificadorNotificaciones == identificador }
    }

    private func persona(con identificador: String?) -> Persona? {
        personas.first { $0.identificadorNotificaciones == identificador }
    }

    private func destinoNoDisponible(_ mensaje: String) -> some View {
        NavigationStack {
            ContentUnavailableView("No se pudo abrir", systemImage: "bell.slash",
                                   description: Text(mensaje))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Cerrar") { enrutador.destino = nil }
                    }
                }
        }
        .aparienciaDeLaApp()
    }
}

#Preview {
    RaizView()
}
