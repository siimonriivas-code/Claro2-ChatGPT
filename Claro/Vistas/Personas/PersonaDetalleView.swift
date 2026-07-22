//
//  PersonaDetalleView.swift
//  Claro — Carpeta: Vistas/Personas
//
//  Cuánto te debe una persona, de qué compras viene la deuda
//  y qué pagos te ha hecho. Todo calculado (Ley 1).
//

import SwiftUI
import SwiftData

struct PersonaDetalleView: View {
    let persona: Persona

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @State private var mostrandoCobro = false
    @State private var mostrandoRecordatorio = false
    @State private var mostrandoEdicion = false
    @State private var confirmandoEliminacion = false

    private var participacionesOrdenadas: [Participacion] {
        persona.participaciones
            .filter { $0.compra?.movimiento?.cuentaParaCalculos ?? false }
            .sorted { ($0.compra?.movimiento?.fecha ?? .distantPast)
                    > ($1.compra?.movimiento?.fecha ?? .distantPast) }
    }

    private var cobrosEIngresos: [Movimiento] {
        persona.movimientos
            .filter {
                $0.cuentaParaCalculos
                    && ($0.tipo == .cobroRecibido || $0.tipo == .ingreso)
            }
            .sorted { $0.fecha > $1.fecha }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Panel {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TE DEBE")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Tema.textoSecundario)
                        Text(max(0, persona.saldoPendiente).comoDinero)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(persona.saldoPendiente > 0
                                             ? Tema.advertencia : Tema.positivo)
                        Text("De \(persona.totalQueTeDebe.comoDinero) en compras, se aplicaron \(persona.totalAplicadoADeuda.comoDinero)")
                            .font(.caption)
                            .foregroundStyle(Tema.textoSecundario)
                        if persona.totalExcedenteRecibido > 0 {
                            Label("Además recibiste \(persona.totalExcedenteRecibido.comoDinero) como ingreso excedente.",
                                  systemImage: "plus.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Tema.acento)
                        }
                    }
                }

                Button {
                    mostrandoCobro = true
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Registrar pago recibido")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Tema.positivo)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Tema.positivo.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                HStack(spacing: 10) {
                    ShareLink(item: mensajeDeCobro) {
                        Label("Compartir cobro", systemImage: "square.and.arrow.up")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Tema.panel,
                                        in: RoundedRectangle(cornerRadius: 13,
                                                             style: .continuous))
                    }

                    Button {
                        mostrandoRecordatorio = true
                    } label: {
                        Label("Recordármelo", systemImage: "bell.badge")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Tema.panel,
                                        in: RoundedRectangle(cornerRadius: 13,
                                                             style: .continuous))
                    }
                }
                .foregroundStyle(Tema.acento)

                TituloSeccion(texto: "Sus partes en compras")
                if participacionesOrdenadas.isEmpty {
                    Panel {
                        Text("Sin compras compartidas con esta persona todavía.")
                            .font(.footnote)
                            .foregroundStyle(Tema.textoSecundario)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Panel {
                        VStack(spacing: 0) {
                            ForEach(participacionesOrdenadas) { parte in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(parte.compra?.movimiento?.detalle.isEmpty == false
                                             ? parte.compra!.movimiento!.detalle
                                             : "Compra compartida")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Tema.textoPrincipal)
                                        if let fecha = parte.compra?.movimiento?.fecha {
                                            Text(fecha.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption)
                                                .foregroundStyle(Tema.textoSecundario)
                                        }
                                    }
                                    Spacer()
                                    Text(parte.monto.comoDinero)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Tema.textoPrincipal)
                                }
                                .padding(.vertical, 6)
                                if parte.id != participacionesOrdenadas.last?.id {
                                    Divider().overlay(Tema.panelElevado)
                                }
                            }
                        }
                    }
                }

                TituloSeccion(texto: "Pagos e ingresos recibidos")
                if cobrosEIngresos.isEmpty {
                    Panel {
                        Text("Aún no registras pagos de esta persona.")
                            .font(.footnote)
                            .foregroundStyle(Tema.textoSecundario)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Panel {
                        VStack(spacing: 0) {
                            ForEach(cobrosEIngresos) { cobro in
                                FilaMovimiento(movimiento: cobro)
                                if cobro.id != cobrosEIngresos.last?.id {
                                    Divider().overlay(Tema.panelElevado)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(FondoClaro())
        .navigationTitle(persona.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        mostrandoEdicion = true
                    } label: {
                        Label("Editar persona", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) {
                        confirmandoEliminacion = true
                    } label: {
                        Label("Archivar persona", systemImage: "archivebox")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Tema.textoSecundario)
                }
            }
        }
        .sheet(isPresented: $mostrandoCobro) {
            CobroRecibidoView(personaInicial: persona)
        }
        .sheet(isPresented: $mostrandoRecordatorio) {
            RecordatorioCobroView(persona: persona)
        }
        .sheet(isPresented: $mostrandoEdicion) {
            EditarPersonaView(persona: persona)
        }
        .confirmationDialog("¿Archivar a \(persona.nombre)?",
                            isPresented: $confirmandoEliminacion,
                            titleVisibility: .visible) {
            Button("Archivar y conservar el historial") { archivarPersona() }
            Button("No", role: .cancel) { }
        } message: {
            Text("Dejará de aparecer para compras y cobros nuevos. Sus participaciones, pagos y excedentes históricos se conservarán.")
        }
    }

    private func archivarPersona() {
        persona.archivada = true
        try? contexto.save()
        cerrar()
    }

    private var mensajeDeCobro: String {
        "Hola, \(persona.nombre). Te comparto el recordatorio del saldo pendiente de \(max(0, persona.saldoPendiente).comoDinero). Gracias."
    }
}

private struct RecordatorioCobroView: View {
    let persona: Persona

    @Environment(\.dismiss) private var cerrar
    @State private var fecha: Date
    @State private var guardando = false
    @State private var mensajeError: String?

    init(persona: Persona) {
        self.persona = persona
        let calendario = Calendar.current
        let manana = calendario.date(byAdding: .day, value: 1, to: .now) ?? .now
        var componentes = calendario.dateComponents([.year, .month, .day],
                                                     from: manana)
        componentes.hour = 10
        _fecha = State(initialValue: calendario.date(from: componentes) ?? manana)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recordatorio para \(persona.nombre)") {
                    LabeledContent("Saldo") {
                        Text(max(0, persona.saldoPendiente).comoDinero)
                    }
                    DatePicker("Fecha y hora",
                               selection: $fecha,
                               in: Date.now...,
                               displayedComponents: [.date, .hourAndMinute])
                }

                if let mensajeError {
                    Section {
                        Label(mensajeError,
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Tema.advertencia)
                    }
                }
            }
            .navigationTitle("Recordar cobro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(guardando ? "Guardando…" : "Programar") {
                        programar()
                    }
                    .disabled(guardando || fecha <= .now)
                }
            }
        }
        .aparienciaDeLaApp()
    }

    private func programar() {
        guardando = true
        mensajeError = nil
        Task {
            do {
                try await ProgramadorDeNotificaciones.programarCobro(
                    persona: persona,
                    fecha: fecha
                )
                await MainActor.run { cerrar() }
            } catch {
                await MainActor.run {
                    mensajeError = error.localizedDescription
                    guardando = false
                }
            }
        }
    }
}
