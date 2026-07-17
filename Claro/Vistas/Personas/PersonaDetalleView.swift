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
    @State private var mostrandoEdicion = false
    @State private var confirmandoEliminacion = false

    private var participacionesOrdenadas: [Participacion] {
        persona.participaciones
            .filter { $0.compra?.movimiento?.cuentaParaCalculos ?? false }
            .sorted { ($0.compra?.movimiento?.fecha ?? .distantPast)
                    > ($1.compra?.movimiento?.fecha ?? .distantPast) }
    }

    private var cobros: [Movimiento] {
        persona.movimientos
            .filter { $0.cuentaParaCalculos && $0.tipo == .cobroRecibido }
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
                        Text("De \(persona.totalQueTeDebe.comoDinero) en compras, te ha pagado \(persona.totalQueTeHaPagado.comoDinero)")
                            .font(.caption)
                            .foregroundStyle(Tema.textoSecundario)
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

                TituloSeccion(texto: "Pagos que te ha hecho")
                if cobros.isEmpty {
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
                            ForEach(cobros) { cobro in
                                FilaMovimiento(movimiento: cobro)
                                if cobro.id != cobros.last?.id {
                                    Divider().overlay(Tema.panelElevado)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Tema.fondo.ignoresSafeArea())
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
                        Label("Eliminar persona", systemImage: "trash")
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
        .sheet(isPresented: $mostrandoEdicion) {
            EditarPersonaView(persona: persona)
        }
        .confirmationDialog("¿Eliminar a \(persona.nombre)?",
                            isPresented: $confirmandoEliminacion,
                            titleVisibility: .visible) {
            Button("Sí, eliminar persona", role: .destructive) { eliminarPersona() }
            Button("No", role: .cancel) { }
        } message: {
            Text("Se eliminarán también sus partes en compras compartidas y los cobros que te haya hecho. Las compras originales NO se tocan. Esta acción no se puede deshacer.")
        }
    }

    private func eliminarPersona() {
        for parte in persona.participaciones {
            contexto.delete(parte)
        }
        for movimiento in persona.movimientos {
            contexto.delete(movimiento)
        }
        contexto.delete(persona)
        cerrar()
    }
}
