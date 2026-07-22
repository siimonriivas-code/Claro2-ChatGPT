//
//  HistorialImportacionesView.swift
//  Claro
//

import SwiftUI
import SwiftData

struct HistorialImportacionesView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \EstadoDeCuenta.fechaCorte, order: .reverse)
    private var estados: [EstadoDeCuenta]

    @State private var porDeshacer: EstadoDeCuenta?
    @State private var mensajeError: String?

    private var importaciones: [EstadoDeCuenta] {
        estados.filter { $0.importacionID != nil }
    }

    var body: some View {
        List {
            if importaciones.isEmpty {
                ContentUnavailableView(
                    "Sin importaciones recientes",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Aquí aparecerán los estados de cuenta que importes."))
            } else {
                ForEach(importaciones) { estado in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(estado.tarjeta?.nombre ?? "Tarjeta")
                                    .font(.headline)
                                Text("Corte: \(estado.fechaCorte.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(Tema.textoSecundario)
                            }
                            Spacer()
                            Text(estado.saldoAlCorte.comoDinero)
                                .font(.subheadline.weight(.semibold))
                        }

                        if let archivo = estado.archivoOrigen, !archivo.isEmpty {
                            Label(archivo, systemImage: "doc.fill")
                                .font(.caption2)
                                .foregroundStyle(Tema.textoSecundario)
                                .lineLimit(1)
                        }

                        Button(role: .destructive) {
                            porDeshacer = estado
                        } label: {
                            Label("Deshacer esta importación",
                                  systemImage: "arrow.uturn.backward.circle")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if let mensajeError {
                Text(mensajeError)
                    .font(.footnote)
                    .foregroundStyle(Tema.urgente)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tema.fondo.ignoresSafeArea())
        .navigationTitle("Importaciones")
        .confirmationDialog("¿Deshacer esta importación?",
                            isPresented: Binding(
                                get: { porDeshacer != nil },
                                set: { if !$0 { porDeshacer = nil } }
                            ),
                            titleVisibility: .visible,
                            presenting: porDeshacer) { estado in
            Button("Sí, deshacer", role: .destructive) {
                deshacer(estado)
            }
            Button("No", role: .cancel) { porDeshacer = nil }
        } message: { estado in
            Text("Se retirarán el corte y los movimientos creados por ese PDF. Los datos capturados por separado no se tocarán.")
        }
    }

    private func deshacer(_ estado: EstadoDeCuenta) {
        defer { porDeshacer = nil }
        guard let id = estado.importacionID else { return }
        do {
            try AdministradorImportaciones.deshacer(id: id, contexto: contexto)
            mensajeError = nil
        } catch {
            mensajeError = "No se pudo deshacer. Tus datos se conservaron; vuelve a intentarlo."
        }
    }
}
