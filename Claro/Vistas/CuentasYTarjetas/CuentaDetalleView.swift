//
//  CuentaDetalleView.swift
//  Claro — Carpeta: Vistas/CuentasYTarjetas
//  ⚠️ REEMPLAZA al existente.
//
//  Novedad: menú ••• para EDITAR la cuenta o ELIMINARLA (con aviso de
//  cuántos movimientos se van con ella).
//

import SwiftUI
import SwiftData

struct CuentaDetalleView: View {
    let cuenta: CuentaBancaria

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @State private var mostrandoEdicion = false
    @State private var mostrandoFusion = false
    @State private var mostrandoImportacion = false
    @State private var confirmandoEliminacion = false

    private var movimientosOrdenados: [Movimiento] {
        (cuenta.movimientos + cuenta.movimientosEntrantes)
            .sorted { $0.fecha > $1.fecha }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Panel {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SALDO ACTUAL")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Tema.textoSecundario)
                        Text(cuenta.saldoCalculado.comoDinero)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(cuenta.saldoCalculado >= 0
                                             ? Tema.positivo : Tema.urgente)
                        Text("Saldo inicial \(cuenta.saldoInicial.comoDinero) el \(cuenta.fechaSaldoInicial.formatted(date: .abbreviated, time: .omitted)) + movimientos")
                            .font(.caption2)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                }

                TituloSeccion(texto: "Movimientos")

                Button { mostrandoImportacion = true } label: {
                    Label("Importar estado de cuenta (PDF)", systemImage: "doc.text.viewfinder")
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                }
                .buttonStyle(.borderedProminent).tint(Tema.acento)

                if movimientosOrdenados.isEmpty {
                    Panel {
                        Text("Aún no hay movimientos en esta cuenta.\nRegistra el primero desde la pestaña Registrar.")
                            .font(.footnote)
                            .foregroundStyle(Tema.textoSecundario)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Panel {
                        VStack(spacing: 0) {
                            ForEach(movimientosOrdenados) { movimiento in
                                FilaMovimiento(movimiento: movimiento,
                                               perspectiva: cuenta)
                                if movimiento.id != movimientosOrdenados.last?.id {
                                    Divider().overlay(Tema.panelElevado)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Tema.fondo.ignoresSafeArea())
        .navigationTitle(cuenta.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        mostrandoEdicion = true
                    } label: {
                        Label("Editar cuenta", systemImage: "pencil")
                    }
                    Button {
                        mostrandoFusion = true
                    } label: {
                        Label("Fusionar con otra cuenta",
                              systemImage: "arrow.triangle.merge")
                    }
                    Divider()
                    Button(role: .destructive) {
                        confirmandoEliminacion = true
                    } label: {
                        Label("Eliminar cuenta", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Tema.textoSecundario)
                }
            }
        }
        .sheet(isPresented: $mostrandoEdicion) {
            EditarCuentaView(cuenta: cuenta)
        }
       .sheet(isPresented: $mostrandoFusion) {
            FusionarCuentaView(cuentaOrigen: cuenta) {
                cerrar()
       }
        .sheet(isPresented: $mostrandoImportacion) {
            ImportarEstadoDebitoView(cuenta: cuenta)
        }
        }
        .confirmationDialog("¿Eliminar esta cuenta?",
                            isPresented: $confirmandoEliminacion,
                            titleVisibility: .visible) {
            Button("Sí, eliminar cuenta y sus \(cuenta.movimientos.count) movimientos",
                   role: .destructive) { eliminarCuenta() }
            Button("No", role: .cancel) { }
        } message: {
            Text("Se eliminará la cuenta y todos sus movimientos (con sus divisiones de dueños). Esta acción no se puede deshacer.")
        }
    }

    private func eliminarCuenta() {
        // Movimientos donde esta cuenta es la principal: fuera, con limpieza
        for movimiento in cuenta.movimientos {
            if let compartida = movimiento.compraCompartida {
                for parte in compartida.participaciones { contexto.delete(parte) }
                movimiento.compraCompartida = nil
                contexto.delete(compartida)
            }
            contexto.delete(movimiento)   // su bitácora se va en cascada
        }
        // Transferencias que le llegaban: quedan como salidas sin destino
        for movimiento in cuenta.movimientosEntrantes {
            movimiento.cuentaDestino = nil
        }
        contexto.delete(cuenta)
        cerrar()
    }
}
