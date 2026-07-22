//
//  NuevoMovimientoView.swift
//  Claro — Carpeta: Vistas/Registrar
//  ⚠️ REEMPLAZA al existente.
//
//  Novedad: los GASTOS (débito/efectivo) ahora también pueden ser
//  compartidos — para servicios como luz, agua, internet que se
//  dividen entre varias personas.
//

import SwiftUI
import SwiftData

struct NuevoMovimientoView: View {
    let tipo: TipoMovimiento   // .ingreso o .gasto

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @Query(filter: #Predicate<CuentaBancaria> { !$0.archivada }, sort: \CuentaBancaria.nombre) private var cuentas: [CuentaBancaria]
    @Query(sort: \Categoria.nombre) private var categorias: [Categoria]
    @Query(filter: #Predicate<Persona> { !$0.archivada }, sort: \Persona.nombre) private var personas: [Persona]

    @State private var monto: Double?
    @State private var cuentaSeleccionada: CuentaBancaria?
    @State private var categoriaSeleccionada: Categoria?
    @State private var fecha: Date = .now
    @State private var detalle = ""

    // Gasto compartido (servicios, etc.)
    @State private var esCompartido = false
    @State private var partes: [PersistentIdentifier: Double] = [:]
    @State private var mostrandoDivision = false

    private var esIngreso: Bool { tipo == .ingreso }

    private var sumaAjena: Double { partes.values.reduce(0, +) }
    private var tuParte: Double { max(0, (monto ?? 0) - sumaAjena) }

    private var resumenDivision: String {
        let nombres = personas
            .filter { partes[$0.id] ?? 0 > 0 }
            .map(\.nombre)
        guard !nombres.isEmpty else { return "Toca para dividir entre personas" }
        return "Compartido con \(nombres.joined(separator: ", ")) · tu parte: \(tuParte.comoDinero)"
    }

    private var puedeGuardar: Bool {
        (monto ?? 0) > 0
        && cuentaSeleccionada != nil
        && (!esCompartido || sumaAjena <= (monto ?? 0))
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
                    Picker(esIngreso ? "Cuenta donde entró" : "Cuenta de donde salió",
                           selection: $cuentaSeleccionada) {
                        Text("Selecciona…").tag(nil as CuentaBancaria?)
                        ForEach(cuentas) { cuenta in
                            Text("\(cuenta.banco?.nombre ?? "") · \(cuenta.nombre) · \(cuenta.saldoCalculado.comoDinero)")
                                .tag(cuenta as CuentaBancaria?)
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

                    TextField(esIngreso ? "Descripción (ej. Pensión junio)"
                                        : "Descripción (ej. Recibo de luz CFE)",
                              text: $detalle)

                    if esIngreso {
                        Text("Una misma cuenta puede recibir varios ingresos. Usa la descripción para distinguir pensión, nómina u otra fuente.")
                            .font(.footnote)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                }

                // ── Gasto compartido (solo para gastos) ──
                if !esIngreso {
                    Section {
                        Toggle("Gasto compartido", isOn: $esCompartido)
                        if esCompartido {
                            if personas.isEmpty {
                                Text("Primero crea personas en la pestaña Personas.")
                                    .font(.footnote)
                                    .foregroundStyle(Tema.advertencia)
                            } else {
                                Button {
                                    mostrandoDivision = true
                                } label: {
                                    Label(resumenDivision,
                                          systemImage: "person.2.fill")
                                        .font(.footnote)
                                }
                                .disabled((monto ?? 0) <= 0)
                            }
                        }
                    } footer: {
                        if esCompartido {
                            Text("Ideal para servicios como luz, agua o internet. Tú pagas el total desde tu cuenta, pero tu gasto personal solo registra TU parte; lo demás queda como deuda de cada persona contigo.")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle(esIngreso ? "Nuevo ingreso" : "Nuevo gasto")
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
            .sheet(isPresented: $mostrandoDivision) {
                AsignacionCompartidaView(
                    titulo: detalle.isEmpty ? "Gasto compartido" : detalle,
                    montoBase: monto ?? 0,
                    esMensual: false,
                    personas: personas,
                    partes: $partes)
            }
        }
        .aparienciaDeLaApp()
        .onAppear { seleccionarCuentaUnica() }
        .onChange(of: cuentas.count) { _, _ in seleccionarCuentaUnica() }
    }

    private func seleccionarCuentaUnica() {
        if cuentaSeleccionada == nil, cuentas.count == 1 {
            cuentaSeleccionada = cuentas[0]
        }
    }

    private func guardar() {
        let movimiento = Movimiento(tipo: tipo,
                                    monto: monto ?? 0,
                                    fecha: fecha,
                                    detalle: detalle.trimmingCharacters(in: .whitespaces),
                                    cuenta: cuentaSeleccionada,
                                    categoria: categoriaSeleccionada)
        contexto.insert(movimiento)

        // División del gasto compartido
        let conMonto = partes.filter { $0.value > 0 }
        if !esIngreso && esCompartido && !conMonto.isEmpty {
            let compartida = CompraCompartida()
            contexto.insert(compartida)
            movimiento.compraCompartida = compartida
            for persona in personas {
                if let parte = conMonto[persona.id], parte > 0 {
                    contexto.insert(Participacion(monto: parte,
                                                  persona: persona,
                                                  compra: compartida))
                }
            }
        }
        cerrar()
    }
}
