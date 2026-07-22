//
//  PersonasView.swift
//  Claro — Carpeta: Vistas/Personas
//  ⚠️ REEMPLAZA al existente.
//
//  Quién te debe, cuánto, y acceso al detalle de cada persona.
//

import SwiftUI
import SwiftData

struct PersonasView: View {
    @Query(filter: #Predicate<Persona> { !$0.archivada }, sort: \Persona.nombre) private var personas: [Persona]

    @State private var mostrandoNuevaPersona = false
    @State private var mostrandoCobro = false

    private var totalTeDeben: Double {
        personas.reduce(0) { $0 + max(0, $1.saldoPendiente) }
    }

    private var totalExcedentes: Double {
        personas.reduce(0) { $0 + $1.totalExcedenteRecibido }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    NavigationLink {
                        GastosCompartidosView()
                    } label: {
                        HStack(spacing: 14) {
                                OrbeClaro(icono: "person.3.sequence.fill",
                                          color: Tema.violeta, lado: 48)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Círculos compartidos")
                                        .font(.headline)
                                        .foregroundStyle(Tema.textoPrincipal)
                                    Text("Divide gastos sin mezclar tus finanzas")
                                        .font(.caption)
                                        .foregroundStyle(Tema.textoSecundario)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Tema.violeta)
                        }
                        .padding(17)
                        .background(
                            LinearGradient(colors: [Tema.violeta.opacity(0.15),
                                                    Tema.acento.opacity(0.08),
                                                    Tema.panel],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 24,
                                                 style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24,
                                                  style: .continuous)
                            .strokeBorder(Tema.violeta.opacity(0.24), lineWidth: 0.8))
                    }
                    .buttonStyle(Presionable())

                    if personas.isEmpty {
                        estadoVacio
                    } else {
                        HStack(spacing: 16) {
                            Panel {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("TE DEBEN")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Tema.textoSecundario)
                                    Text(totalTeDeben.comoDinero)
                                        .font(.system(.title3, design: .rounded).weight(.bold))
                                        .foregroundStyle(Tema.acento)
                                }
                            }
                            Panel {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("EXCEDENTES")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Tema.textoSecundario)
                                    Text(totalExcedentes.comoDinero)
                                        .font(.system(.title3, design: .rounded).weight(.bold))
                                        .foregroundStyle(totalExcedentes > 0
                                                         ? Tema.acento : Tema.positivo)
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
                        .buttonStyle(Presionable())

                        TituloSeccion(texto: "Personas")
                        ForEach(personas) { persona in
                            NavigationLink {
                                PersonaDetalleView(persona: persona)
                            } label: {
                                filaPersona(persona)
                            }
                            .buttonStyle(Presionable())
                            .aparicionAlDesplazar()
                        }
                    }
                }
                .padding(16)
            }
            .background(FondoClaro())
            .navigationTitle("Personas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        mostrandoNuevaPersona = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Tema.positivo)
                    }
                }
            }
            .sheet(isPresented: $mostrandoNuevaPersona) { NuevaPersonaView() }
            .sheet(isPresented: $mostrandoCobro) { CobroRecibidoView() }
        }
    }

    private func filaPersona(_ persona: Persona) -> some View {
        Panel {
            HStack(spacing: 12) {
                Circle()
                    .fill(Tema.gradienteTarjeta(hex: persona.colorHex))
                    .frame(width: 42, height: 42)
                    .overlay {
                        Text(persona.inicial)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Color(hex: persona.colorHex).opacity(0.24),
                            radius: 8, y: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(persona.nombre)
                        .font(.headline)
                        .foregroundStyle(Tema.textoPrincipal)
                    if persona.saldoPendiente == 0 && persona.totalExcedenteRecibido == 0 {
                        Text("Al corriente ✓")
                            .font(.caption)
                            .foregroundStyle(Tema.positivo)
                    } else if persona.saldoPendiente == 0 {
                        Text("Ingreso adicional recibido")
                            .font(.caption)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                }
                Spacer()
                if persona.saldoPendiente > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(persona.saldoPendiente.comoDinero)
                            .font(.system(.body, design: .rounded).weight(.bold))
                            .foregroundStyle(Tema.acento)
                        Text("te debe")
                            .font(.caption2)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                } else if persona.totalExcedenteRecibido > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(persona.totalExcedenteRecibido.comoDinero)
                            .font(.system(.body, design: .rounded).weight(.bold))
                            .foregroundStyle(Tema.acento)
                        Text("excedente")
                            .font(.caption2)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                }
            }
        }
    }

    private var estadoVacio: some View {
        Panel {
            VStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Tema.acento)
                Text("Agrega a las personas con quienes compartes compras")
                    .font(.headline)
                    .foregroundStyle(Tema.textoPrincipal)
                    .multilineTextAlignment(.center)
                Text("Después podrás dividir compras con ellas y llevar la cuenta exacta de quién te debe qué.")
                    .font(.footnote)
                    .foregroundStyle(Tema.textoSecundario)
                    .multilineTextAlignment(.center)
                Button {
                    mostrandoNuevaPersona = true
                } label: {
                    Text("Agregar persona")
                        .font(.headline)
                        .foregroundStyle(Tema.fondo)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Tema.positivo, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
