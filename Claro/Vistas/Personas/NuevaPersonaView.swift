//
//  NuevaPersonaView.swift
//  Claro — Carpeta: Vistas/Personas
//
//  Alta de una persona con la que compartes compras.
//

import SwiftUI
import SwiftData

struct NuevaPersonaView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @State private var nombre = ""
    @State private var colorHex = "6C8CFF"

    private let colores = ["6C8CFF", "4ADE9C", "F26D6D", "F5B14C",
                           "9B8CFF", "FF8CC8", "4CC9F5", "D9A66C"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos") {
                    TextField("Nombre (ej. Hermano, Nombre de tu novia)", text: $nombre)
                }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4),
                              spacing: 14) {
                        ForEach(colores, id: \.self) { hex in
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
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Nueva persona")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        contexto.insert(Persona(
                            nombre: nombre.trimmingCharacters(in: .whitespaces),
                            colorHex: colorHex))
                        cerrar()
                    }
                    .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .aparienciaDeLaApp()
    }
}
