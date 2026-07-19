//
//  NuevaTarjetaView.swift
//  Claro — Carpeta: Vistas/CuentasYTarjetas
//  ⚠️ REEMPLAZA al existente.
//
//  Novedad: paleta con los colores OFICIALES de los bancos al frente.
//

import SwiftUI
import SwiftData

struct NuevaTarjetaView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @Query(sort: \Banco.nombre) private var bancos: [Banco]

    @State private var nombre = ""
    @State private var ultimosDigitos = ""
    @State private var bancoSeleccionado: Banco?
    @State private var limiteCredito: Double?
    @State private var diaCorte = 15
    @State private var diaLimitePago = 5
    @State private var deudaActual: Double?
    @State private var tasaAnual: Double?
    @State private var cat: Double?
    @State private var colorHex = "004481"

    private let coloresDisponibles: [String] =
        ["004481", "EB0029", "820AD1", "6C8CFF",
         "4ADE9C", "F5B14C", "FF8CC8", "1C2230"]

    private var puedeGuardar: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty
        && bancoSeleccionado != nil
        && (limiteCredito ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos de la tarjeta") {
                    Picker("Banco", selection: $bancoSeleccionado) {
                        Text("Selecciona…").tag(nil as Banco?)
                        ForEach(bancos) { b in
                            Text(b.nombre).tag(b as Banco?)
                        }
                    }
                    TextField("Alias (ej. BBVA Azul)", text: $nombre)
                    TextField("Últimos 4 dígitos (opcional)", text: $ultimosDigitos)
                        .keyboardType(.numberPad)
                    TextField("Límite de crédito", value: $limiteCredito, format: .number)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Picker("Día de corte", selection: $diaCorte) {
                        ForEach(1...31, id: \.self) { Text("Día \($0)").tag($0) }
                    }
                    Picker("Día límite de pago", selection: $diaLimitePago) {
                        ForEach(1...31, id: \.self) { Text("Día \($0)").tag($0) }
                    }
                } header: {
                    Text("Calendario de la tarjeta")
                } footer: {
                    Text("Estos días son orientativos para recordatorios. Las fechas exactas de cada periodo las capturarás al registrar o importar cada corte.")
                }

                Section {
                    TextField("0.00", value: $deudaActual, format: .number)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Deuda actual de la tarjeta")
                } footer: {
                    Text("¿Cuánto debe la tarjeta HOY en total? Este es su punto de partida; desde aquí el motor calculará la deuda con cada compra y pago (Ley 1). Si está en ceros, deja 0.")
                }
                Section("Costo del crédito (opcional)") {
                    TextField("Tasa anual %", value: $tasaAnual, format: .number).keyboardType(.decimalPad)
                    TextField("CAT %", value: $cat, format: .number).keyboardType(.decimalPad)
                }

                Section {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4),
                              spacing: 14) {
                        ForEach(coloresDisponibles, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    if colorHex == hex {
                                        Image(systemName: "checkmark")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Color")
                } footer: {
                    Text("Los tres primeros son los colores oficiales de BBVA, Banorte y Nu.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Nueva tarjeta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let tarjeta = TarjetaCredito(
                            nombre: nombre.trimmingCharacters(in: .whitespaces),
                            ultimosDigitos: ultimosDigitos,
                            limiteCredito: limiteCredito ?? 0,
                            diaCorte: diaCorte,
                            diaLimitePago: diaLimitePago,
                            saldoInicial: deudaActual ?? 0,
                            fechaSaldoInicial: .now,
                            colorHex: colorHex,
                            banco: bancoSeleccionado,
                            tasaAnual: tasaAnual, cat: cat)
                        contexto.insert(tarjeta)
                        cerrar()
                    }
                    .disabled(!puedeGuardar)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
