//
//  NuevoBancoView.swift
//  Claro — Carpeta: Vistas/CuentasYTarjetas
//  ⚠️ REEMPLAZA al existente.
//
//  Novedad: paleta con los colores OFICIALES de los bancos mexicanos
//  (BBVA, Banorte, Nu) al frente.
//

import SwiftUI
import SwiftData

struct NuevoBancoView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @State private var nombre = ""
    @State private var colorHex = "004481"

    private let coloresDisponibles: [(nombre: String, hex: String)] = [
        ("BBVA",    "004481"), ("Banorte", "EB0029"),
        ("Nu",      "820AD1"), ("Azul",    "6C8CFF"),
        ("Verde",   "4ADE9C"), ("Ámbar",   "F5B14C"),
        ("Rosa",    "FF8CC8"), ("Dorado",  "D9A66C")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos del banco") {
                    TextField("Nombre (ej. BBVA, Banorte, Nu)", text: $nombre)
                }

                Section {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4),
                              spacing: 14) {
                        ForEach(coloresDisponibles, id: \.hex) { color in
                            Circle()
                                .fill(Color(hex: color.hex))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    if colorHex == color.hex {
                                        Image(systemName: "checkmark")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { colorHex = color.hex }
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Color de identidad")
                } footer: {
                    Text("Los tres primeros son los colores oficiales de BBVA, Banorte y Nu.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Nuevo banco")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let banco = Banco(nombre: nombre.trimmingCharacters(in: .whitespaces),
                                          colorHex: colorHex)
                        contexto.insert(banco)
                        cerrar()
                    }
                    .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
