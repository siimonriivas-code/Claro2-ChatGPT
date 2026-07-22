//
//  TransferenciaView.swift
//  Claro — Carpeta: Vistas/Registrar
//
//  Mover dinero entre tus propias cuentas: sale de una, entra a otra,
//  y tu dinero total no cambia.
//

import SwiftUI
import SwiftData

struct TransferenciaView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @Query(filter: #Predicate<CuentaBancaria> { !$0.archivada }, sort: \CuentaBancaria.nombre) private var cuentas: [CuentaBancaria]

    @State private var monto: Double?
    @State private var origen: CuentaBancaria?
    @State private var destino: CuentaBancaria?
    @State private var fecha: Date = .now
    @State private var detalle = ""

    private var puedeGuardar: Bool {
        (monto ?? 0) > 0
        && origen != nil
        && destino != nil
        && origen != destino
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Monto") {
                    TextField("0.00", value: $monto, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.bold))
                }

                Section("Movimiento") {
                    Picker("De la cuenta", selection: $origen) {
                        Text("Selecciona…").tag(nil as CuentaBancaria?)
                        ForEach(cuentas) { c in
                            Text("\(c.banco?.nombre ?? "") · \(c.nombre)")
                                .tag(c as CuentaBancaria?)
                        }
                    }
                    Picker("A la cuenta", selection: $destino) {
                        Text("Selecciona…").tag(nil as CuentaBancaria?)
                        ForEach(cuentas) { c in
                            Text("\(c.banco?.nombre ?? "") · \(c.nombre)")
                                .tag(c as CuentaBancaria?)
                        }
                    }
                    DatePicker("Fecha", selection: $fecha,
                               displayedComponents: .date)
                    TextField("Descripción (opcional)", text: $detalle)
                }

                if origen != nil && origen == destino {
                    Section {
                        Label("La cuenta de origen y destino no pueden ser la misma.",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Tema.advertencia)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Transferencia")
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

    private func guardar() {
        let movimiento = Movimiento(tipo: .transferencia,
                                    monto: monto ?? 0,
                                    fecha: fecha,
                                    detalle: detalle.trimmingCharacters(in: .whitespaces),
                                    cuenta: origen,
                                    cuentaDestino: destino)
        contexto.insert(movimiento)
        cerrar()
    }
}
