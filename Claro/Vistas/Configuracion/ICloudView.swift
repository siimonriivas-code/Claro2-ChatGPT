//
//  ICloudView.swift
//  Claro
//

import CloudKit
import SwiftData
import SwiftUI

struct ICloudView: View {
    @Environment(\.modelContext) private var contexto
    @AppStorage("respaldoICloudAutomatico") private var automatico = true

    @State private var estado = "Comprobando iCloud…"
    @State private var trabajando = false
    @State private var mensaje: String?
    @State private var respaldoDescargado: RespaldoClaro?
    @State private var confirmandoRestauracion = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Estado") { Text(estado) }
                Toggle("Respaldo automático", isOn: $automatico)
            } header: {
                Text("iCloud privado")
            } footer: {
                Text("Claro guarda una copia completa y privada en tu cuenta de iCloud. No sube tus PDF ni el modelo de IA. Cada persona que instale la app usa su propio iCloud.")
            }

            Section {
                Button {
                    crearRespaldo()
                } label: {
                    Label(trabajando ? "Guardando…" : "Respaldar ahora",
                          systemImage: "icloud.and.arrow.up")
                }
                .disabled(trabajando)

                Button {
                    prepararRestauracion()
                } label: {
                    Label("Restaurar desde iCloud",
                          systemImage: "icloud.and.arrow.down")
                }
                .disabled(trabajando)
            } footer: {
                Text("Restaurar reemplaza los datos de este iPhone. La app siempre pide confirmación antes de hacerlo.")
            }

            if let mensaje {
                Section {
                    Label(mensaje, systemImage: "info.circle.fill")
                        .foregroundStyle(Tema.acento)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tema.fondo.ignoresSafeArea())
        .navigationTitle("iCloud")
        .navigationBarTitleDisplayMode(.inline)
        .task { await comprobarEstado() }
        .confirmationDialog(
            "¿Restaurar este respaldo?",
            isPresented: $confirmandoRestauracion,
            titleVisibility: .visible
        ) {
            Button("Sí, reemplazar datos de este iPhone", role: .destructive) {
                restaurar()
            }
            Button("Cancelar", role: .cancel) { respaldoDescargado = nil }
        } message: {
            if let respaldoDescargado {
                Text("Respaldo del \(respaldoDescargado.creadoEl.formatted(date: .abbreviated, time: .shortened)), con \(respaldoDescargado.totalRegistros) registros.")
            }
        }
    }

    private func comprobarEstado() async {
        let cuenta = await AdministradorICloud.estadoDeCuenta()
        switch cuenta {
        case .available:
            do {
                if let fecha = try await AdministradorICloud.fechaRemota() {
                    estado = "Último respaldo: \(fecha.formatted(date: .abbreviated, time: .shortened))"
                } else {
                    estado = "Disponible · aún sin respaldo"
                }
            } catch {
                estado = "iCloud disponible"
            }
        case .noAccount: estado = "Inicia sesión en iCloud"
        case .restricted: estado = "iCloud restringido"
        case .temporarilyUnavailable: estado = "iCloud no disponible temporalmente"
        case .couldNotDetermine: estado = "No se pudo comprobar iCloud"
        @unknown default: estado = "Estado de iCloud desconocido"
        }
    }

    private func crearRespaldo() {
        trabajando = true
        mensaje = nil
        Task {
            do {
                let fecha = try await AdministradorICloud.respaldar(
                    contexto: contexto)
                estado = "Último respaldo: \(fecha.formatted(date: .abbreviated, time: .shortened))"
                mensaje = "Tus datos quedaron respaldados en tu iCloud privado."
            } catch {
                mensaje = error.localizedDescription
            }
            trabajando = false
        }
    }

    private func prepararRestauracion() {
        trabajando = true
        mensaje = nil
        Task {
            do {
                respaldoDescargado = try await AdministradorICloud
                    .descargarRespaldo()
                confirmandoRestauracion = true
            } catch {
                mensaje = error.localizedDescription
            }
            trabajando = false
        }
    }

    private func restaurar() {
        guard let respaldoDescargado else { return }
        trabajando = true
        do {
            try AdministradorRespaldos.restaurar(respaldoDescargado,
                                                  contexto: contexto)
            mensaje = "Respaldo restaurado correctamente."
        } catch {
            mensaje = "No se pudo restaurar: \(error.localizedDescription)"
        }
        self.respaldoDescargado = nil
        trabajando = false
    }
}
