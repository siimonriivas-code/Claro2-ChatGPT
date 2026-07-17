//
//  CobroRecibidoView.swift
//  Claro — Carpeta: Vistas/Registrar
//
//  Registrar que alguien te pagó. Doble efecto automático:
//  baja lo que te debe Y sube el saldo de la cuenta donde recibiste.
//

import SwiftUI
import SwiftData

struct CobroRecibidoView: View {
    var personaInicial: Persona? = nil

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @Query(sort: \Persona.nombre) private var personas: [Persona]
    @Query(sort: \CuentaBancaria.nombre) private var cuentas: [CuentaBancaria]

    @State private var monto: Double?
    @State private var personaSeleccionada: Persona?
    @State private var cuentaDestino: CuentaBancaria?
    @State private var fecha: Date = .now
    @State private var detalle = ""

    init(personaInicial: Persona? = nil) {
        self.personaInicial = personaInicial
        _personaSeleccionada = State(initialValue: personaInicial)
    }

    private var puedeGuardar: Bool {
        (monto ?? 0) > 0 && personaSeleccionada != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Monto recibido") {
                    TextField("0.00", value: $monto, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.bold))

                    if let p = personaSeleccionada, p.saldoPendiente > 0 {
                        Button {
                            monto = p.saldoPendiente
                        } label: {
                            Label("Usar saldo pendiente: \(p.saldoPendiente.comoDinero)",
                                  systemImage: "wand.and.stars")
                                .font(.footnote)
                        }
                    }
                }

                Section("Detalles") {
                    Picker("Quién te pagó", selection: $personaSeleccionada) {
                        Text("Selecciona…").tag(nil as Persona?)
                        ForEach(personas) { p in
                            Text(p.nombre).tag(p as Persona?)
                        }
                    }

                    Picker("Cuenta donde lo recibiste", selection: $cuentaDestino) {
                        Text("Efectivo / fuera de la app").tag(nil as CuentaBancaria?)
                        ForEach(cuentas) { c in
                            Text("\(c.banco?.nombre ?? "") · \(c.nombre)")
                                .tag(c as CuentaBancaria?)
                        }
                    }

                    DatePicker("Fecha", selection: $fecha,
                               displayedComponents: .date)

                    TextField("Descripción (opcional)", text: $detalle)
                }

                if let p = personaSeleccionada, let m = monto, m > p.saldoPendiente {
                    Section {
                        Label("Estás registrando más (\(m.comoDinero)) de lo que \(p.nombre) te debe (\(max(0, p.saldoPendiente).comoDinero)). Puedes continuar, pero revísalo.",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Tema.advertencia)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Cobro recibido")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let movimiento = Movimiento(
                            tipo: .cobroRecibido,
                            monto: monto ?? 0,
                            fecha: fecha,
                            detalle: detalle.trimmingCharacters(in: .whitespaces),
                            cuenta: cuentaDestino,
                            persona: personaSeleccionada)
                        contexto.insert(movimiento)
                        cerrar()
                    }
                    .disabled(!puedeGuardar)
                }
            }
        }
        .aparienciaDeLaApp()
    }
}
