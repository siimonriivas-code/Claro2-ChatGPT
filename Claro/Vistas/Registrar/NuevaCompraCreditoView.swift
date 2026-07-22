//
//  NuevaCompraCreditoView.swift
//  Claro — Carpeta: Vistas/Registrar
//  ⚠️ REEMPLAZA al existente.
//
//  Novedad: interruptores de MSI (crea el plan y sus mensualidades,
//  Ley 3) y de compra compartida (divide entre personas).
//

import SwiftUI
import SwiftData

struct NuevaCompraCreditoView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @Query(filter: #Predicate<TarjetaCredito> { !$0.archivada }, sort: \TarjetaCredito.nombre) private var tarjetas: [TarjetaCredito]
    @Query(sort: \Categoria.nombre) private var categorias: [Categoria]
    @Query(filter: #Predicate<Persona> { !$0.archivada }, sort: \Persona.nombre) private var personas: [Persona]

    @State private var monto: Double?
    @State private var tarjetaSeleccionada: TarjetaCredito?
    @State private var categoriaSeleccionada: Categoria?
    @State private var fecha: Date = .now
    @State private var detalle = ""

    // MSI / a meses
    @State private var esMSI = false
    @State private var meses = 3
    @State private var pagoCongelado: Double?
    private let opcionesMeses = [2, 3, 4, 6, 9, 12, 13, 14, 18, 24, 36]

    // Compartida
    @State private var esCompartida = false
    @State private var montosPorPersona: [PersistentIdentifier: Double] = [:]

    private var sumaAjena: Double {
        montosPorPersona.values.reduce(0, +)
    }

    private var tuParte: Double {
        max(0, (monto ?? 0) - sumaAjena)
    }

    private var divisionValida: Bool {
        !esCompartida || sumaAjena <= (monto ?? 0)
    }

    private var congeladoValido: Bool {
        !esMSI || (pagoCongelado ?? 0) < (monto ?? 0)
    }

    private var puedeGuardar: Bool {
        (monto ?? 0) > 0
        && tarjetaSeleccionada != nil
        && divisionValida
        && congeladoValido
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Monto") {
                    TextField("0.00", value: $monto, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.bold))
                }

                Section("Detalles") {
                    Picker("Tarjeta", selection: $tarjetaSeleccionada) {
                        Text("Selecciona…").tag(nil as TarjetaCredito?)
                        ForEach(tarjetas) { t in
                            Text(t.nombre).tag(t as TarjetaCredito?)
                        }
                    }
                    Picker("Categoría", selection: $categoriaSeleccionada) {
                        Text("Sin categoría").tag(nil as Categoria?)
                        ForEach(categorias) { cat in
                            Label(cat.nombre, systemImage: cat.icono)
                                .tag(cat as Categoria?)
                        }
                    }
                    DatePicker("Fecha", selection: $fecha,
                               displayedComponents: .date)
                    TextField("Descripción (ej. Pantalla, Cena)", text: $detalle)
                }

                // ── Meses sin intereses ──
                Section {
                    Toggle("Compra a meses (con o sin intereses)", isOn: $esMSI)
                    if esMSI {
                        Picker("Meses", selection: $meses) {
                            ForEach(opcionesMeses, id: \.self) {
                                Text("\($0) meses").tag($0)
                            }
                        }
                        TextField("Pago final congelado (opcional)",
                                  value: $pagoCongelado, format: .number)
                            .keyboardType(.decimalPad)
                        if let m = monto, m > 0 {
                            let congelado = pagoCongelado ?? 0
                            if congelado > 0 && congelado < m {
                                Text("Se crearán \(meses) mensualidades de \(((m - congelado) / Double(meses)).comoDinero) + 1 pago congelado de \(congelado.comoDinero) al final.")
                                    .font(.footnote)
                                    .foregroundStyle(Tema.acento)
                            } else if congelado >= m {
                                Label("El pago congelado debe ser menor al total de la compra.",
                                      systemImage: "exclamationmark.triangle.fill")
                                    .font(.footnote)
                                    .foregroundStyle(Tema.advertencia)
                            } else {
                                Text("Se crearán \(meses) mensualidades de \((m / Double(meses)).comoDinero).")
                                    .font(.footnote)
                                    .foregroundStyle(Tema.acento)
                            }
                        }
                    }
                } footer: {
                    if esMSI {
                        Text("Cada mensualidad quedará pendiente al incluirse en un corte y se cubrirá con el pago correspondiente. Si existe un pago final diferido, se agregará como la última mensualidad del plan.")
                    }
                }

                // ── Compartida ──
                Section {
                    Toggle("Compra compartida", isOn: $esCompartida)
                    if esCompartida {
                        if personas.isEmpty {
                            Text("Primero crea personas en la pestaña Personas.")
                                .font(.footnote)
                                .foregroundStyle(Tema.advertencia)
                        } else {
                            ForEach(personas) { p in
                                HStack {
                                    Text(p.nombre)
                                    Spacer()
                                    TextField("0", value: bindingPara(p), format: .number)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 110)
                                }
                            }
                            HStack {
                                Text("Tu parte")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(tuParte.comoDinero)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Tema.positivo)
                            }
                            if !divisionValida {
                                Label("Las partes de otras personas (\(sumaAjena.comoDinero)) superan el total de la compra.",
                                      systemImage: "exclamationmark.triangle.fill")
                                    .font(.footnote)
                                    .foregroundStyle(Tema.advertencia)
                            }
                        }
                    }
                } footer: {
                    if esCompartida {
                        Text("Escribe cuánto corresponde a cada persona. La tarjeta cargará el total, pero tu gasto personal solo registrará TU parte, y lo demás quedará como deuda de cada quien contigo.")
                    }
                }

                if let t = tarjetaSeleccionada, let m = monto, m > 0 {
                    Section {
                        Label("La deuda de \(t.nombre) pasará de \(t.deudaCalculada.comoDinero) a \((t.deudaCalculada + m).comoDinero).",
                              systemImage: "info.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Tema.acento)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Compra a crédito")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }
                        .disabled(!puedeGuardar)
                }
            }
        }
        .aparienciaDeLaApp()
    }

    private func bindingPara(_ p: Persona) -> Binding<Double?> {
        Binding(
            get: { montosPorPersona[p.id] },
            set: { montosPorPersona[p.id] = $0 }
        )
    }

    private func guardar() {
        let movimiento = Movimiento(
            tipo: .compraCredito,
            monto: monto ?? 0,
            fecha: fecha,
            detalle: detalle.trimmingCharacters(in: .whitespaces),
            tarjeta: tarjetaSeleccionada,
            categoria: categoriaSeleccionada)
        contexto.insert(movimiento)

        // Plan a meses con sus mensualidades (todas "por generar", Ley 3).
        // Si hay pago congelado, se agrega como la última mensualidad.
        if esMSI, let m = monto, meses > 0 {
            let congelado = pagoCongelado ?? 0
            let tieneCongelado = congelado > 0 && congelado < m
            let totalMeses = meses + (tieneCongelado ? 1 : 0)
            let mensualidadNormal = (m - (tieneCongelado ? congelado : 0)) / Double(meses)

            let plan = PlanMSI(detalle: detalle.isEmpty ? "Compra a meses" : detalle,
                               montoTotal: m,
                               numeroMeses: totalMeses,
                               fechaCompra: fecha,
                               tarjeta: tarjetaSeleccionada)
            contexto.insert(plan)
            movimiento.planMSI = plan
            for numero in 1...meses {
                contexto.insert(MensualidadMSI(numero: numero,
                                               monto: mensualidadNormal,
                                               plan: plan))
            }
            if tieneCongelado {
                contexto.insert(MensualidadMSI(numero: meses + 1,
                                               monto: congelado,
                                               plan: plan))
            }
        }

        // División compartida
        if esCompartida && sumaAjena > 0 {
            let compartida = CompraCompartida()
            contexto.insert(compartida)
            movimiento.compraCompartida = compartida
            for persona in personas {
                if let parte = montosPorPersona[persona.id], parte > 0 {
                    contexto.insert(Participacion(monto: parte,
                                                  persona: persona,
                                                  compra: compartida))
                }
            }
        }

        cerrar()
    }
}
