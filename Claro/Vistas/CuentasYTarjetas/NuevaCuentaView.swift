//
//  NuevaCuentaView.swift
//  Claro — Carpeta: Vistas/CuentasYTarjetas
//
//  Formulario para dar de alta una cuenta (débito, ahorro o efectivo)
//  con su saldo de HOY como punto de partida del motor.
//

import SwiftUI
import SwiftData

struct NuevaCuentaView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @Query(sort: \Banco.nombre) private var bancos: [Banco]

    @State private var nombre = ""
    @State private var tipo: TipoCuenta = .debito
    @State private var bancoSeleccionado: Banco?
    @State private var saldoInicial: Double?
    @State private var fecha: Date = .now

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos de la cuenta") {
                    Picker("Banco", selection: $bancoSeleccionado) {
                        Text("Selecciona…").tag(nil as Banco?)
                        ForEach(bancos) { banco in
                            Text(banco.nombre).tag(banco as Banco?)
                        }
                    }

                    TextField("Alias (ej. Nómina, Ahorro)", text: $nombre)

                    Picker("Tipo", selection: $tipo) {
                        ForEach(TipoCuenta.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                }

                Section {
                    TextField("0.00", value: $saldoInicial, format: .number)
                        .keyboardType(.decimalPad)
                    DatePicker("Saldo al día", selection: $fecha,
                               displayedComponents: .date)
                } header: {
                    Text("Saldo inicial")
                } footer: {
                    Text("Escribe cuánto dinero tiene la cuenta hoy. Claro actualizará el saldo con cada movimiento que registres.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Nueva cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let cuenta = CuentaBancaria(
                            nombre: nombre.trimmingCharacters(in: .whitespaces),
                            tipo: tipo,
                            saldoInicial: saldoInicial ?? 0,
                            fechaSaldoInicial: fecha,
                            banco: bancoSeleccionado)
                        contexto.insert(cuenta)
                        cerrar()
                    }
                    .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty
                              || bancoSeleccionado == nil)
                }
            }
        }
        .aparienciaDeLaApp()
    }
}
