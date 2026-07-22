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
    @State private var mostrandoComprobacion = false
    @State private var mostrandoImportacion = false
    @State private var confirmandoEliminacion = false
    @State private var filtro: FiltroMovimientosCuenta = .todos
    @State private var busqueda = ""

    private var movimientosOrdenados: [Movimiento] {
        let inicioHoy = Calendar.current.startOfDay(for: FechaAnalisisClaro.actual)
        let inicioManana = Calendar.current.date(
            byAdding: .day, value: 1, to: inicioHoy) ?? FechaAnalisisClaro.actual
        let todos = (cuenta.movimientos + cuenta.movimientosEntrantes)
            .sorted { $0.fecha > $1.fecha }
        let filtrados = todos.filter { movimiento in
            switch filtro {
            case .todos:
                return movimiento.fecha < inicioManana
            case .entradas:
                return movimiento.cuentaDestino === cuenta
                    || [.ingreso, .cobroRecibido, .bonificacion].contains(movimiento.tipo)
            case .salidas:
                return movimiento.cuenta === cuenta
                    && [.gasto, .pagoTarjeta, .transferencia, .abonoDeuda].contains(movimiento.tipo)
            case .programados:
                return movimiento.fecha >= inicioManana
            }
        }
        guard !busqueda.trimmingCharacters(in: .whitespaces).isEmpty else {
            return filtrados
        }
        return filtrados.filter {
            $0.detalle.localizedCaseInsensitiveContains(busqueda)
                || $0.tipo.rawValue.localizedCaseInsensitiveContains(busqueda)
        }
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

                Button { mostrandoComprobacion = true } label: {
                    Label("Comprobar saldo con el banco", systemImage: "checkmark.seal")
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                }
                .buttonStyle(.borderedProminent).tint(Tema.acento)

                Picker("Filtro", selection: $filtro) {
                    ForEach(FiltroMovimientosCuenta.allCases) { opcion in
                        Text(opcion.rawValue).tag(opcion)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Buscar movimiento", text: $busqueda)
                    .textFieldStyle(.roundedBorder)

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
                    Button {
                        mostrandoImportacion = true
                    } label: {
                        Label("Importar movimientos desde PDF (avanzado)",
                              systemImage: "doc.text.viewfinder")
                    }
                    Divider()
                    Button(role: .destructive) {
                        confirmandoEliminacion = true
                    } label: {
                        Label("Archivar cuenta", systemImage: "archivebox")
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
        .sheet(isPresented: $mostrandoComprobacion) {
            ComprobarSaldoCuentaView(cuenta: cuenta)
        }
        }
        .confirmationDialog("¿Archivar esta cuenta?",
                            isPresented: $confirmandoEliminacion,
                            titleVisibility: .visible) {
            Button("Archivar y conservar el historial") { archivarCuenta() }
            Button("No", role: .cancel) { }
        } message: {
            Text("Dejará de aparecer y no podrá usarse en operaciones nuevas. Sus movimientos y su efecto histórico se conservarán.")
        }
    }

    private func archivarCuenta() {
        cuenta.archivada = true
        try? contexto.save()
        cerrar()
    }
}

private enum FiltroMovimientosCuenta: String, CaseIterable, Identifiable {
    case todos = "Todos"
    case entradas = "Entradas"
    case salidas = "Salidas"
    case programados = "Futuros"
    var id: String { rawValue }
}
