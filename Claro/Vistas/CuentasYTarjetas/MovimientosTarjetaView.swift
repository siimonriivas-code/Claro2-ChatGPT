//
//  MovimientosTarjetaView.swift
//  Claro — Carpeta: Vistas/CuentasYTarjetas
//
//  Historial filtrable de una tarjeta. Por defecto enseña únicamente el
//  corte vigente para no mezclarlo con compras y pagos de cortes anteriores.
//

import SwiftUI
import SwiftData

private enum PeriodoMovimientos: Hashable {
    case corteVigente
    case periodoActual
    case corteAnterior(Date)
    case historialCompleto
}

private enum TipoMovimientos: String, CaseIterable {
    case todos = "Todos"
    case compras = "Compras"
    case pagos = "Pagos"
    case ajustes = "Ajustes"

    var icono: String {
        switch self {
        case .todos: return "line.3.horizontal.decrease.circle"
        case .compras: return "cart.fill"
        case .pagos: return "checkmark.circle.fill"
        case .ajustes: return "slider.horizontal.3"
        }
    }
}

private enum EstadoMovimientos: String, CaseIterable {
    case activos = "Activos"
    case cancelados = "Cancelados"
    case ambos = "Todos"
}

struct MovimientosTarjetaView: View {
    let tarjeta: TarjetaCredito

    @State private var periodo: PeriodoMovimientos = .corteVigente
    @State private var tipo: TipoMovimientos = .todos
    @State private var estado: EstadoMovimientos = .activos
    @State private var busqueda = ""

    private var cortesOrdenados: [EstadoDeCuenta] {
        tarjeta.estadosDeCuenta.sorted { $0.fechaCorte > $1.fechaCorte }
    }

    private var movimientosDelPeriodo: [Movimiento] {
        switch periodo {
        case .corteVigente:
            guard let corte = cortesOrdenados.first else {
                return tarjeta.movimientosDelPeriodoActual
            }
            return tarjeta.movimientos(asociadosA: corte)
        case .periodoActual:
            return tarjeta.movimientosDelPeriodoActual
        case .corteAnterior(let fecha):
            guard let corte = cortesOrdenados.first(where: {
                Calendar.current.isDate($0.fechaCorte, inSameDayAs: fecha)
            }) else { return [] }
            return tarjeta.movimientos(asociadosA: corte)
        case .historialCompleto:
            return tarjeta.movimientos.sorted { $0.fecha > $1.fecha }
        }
    }

    private var movimientosFiltrados: [Movimiento] {
        movimientosDelPeriodo.filter { movimiento in
            let coincideTipo: Bool
            switch tipo {
            case .todos:
                coincideTipo = true
            case .compras:
                coincideTipo = movimiento.tipo == .compraCredito
            case .pagos:
                coincideTipo = movimiento.tipo == .pagoTarjeta
            case .ajustes:
                coincideTipo = movimiento.tipo == .ajuste
                    || movimiento.tipo == .bonificacion
            }

            let coincideEstado: Bool
            switch estado {
            case .activos:
                coincideEstado = movimiento.estado == .activo
            case .cancelados:
                coincideEstado = movimiento.estado == .cancelado
            case .ambos:
                coincideEstado = true
            }

            let texto = busqueda.trimmingCharacters(in: .whitespacesAndNewlines)
            let coincideBusqueda = texto.isEmpty
                || movimiento.detalle.localizedStandardContains(texto)
                || movimiento.tipo.rawValue.localizedStandardContains(texto)
                || (movimiento.categoria?.nombre.localizedStandardContains(texto) ?? false)
            return coincideTipo && coincideEstado && coincideBusqueda
        }
    }

    private var tituloPeriodo: String {
        switch periodo {
        case .corteVigente:
            return "Corte vigente"
        case .periodoActual:
            return "Periodo actual"
        case .corteAnterior(let fecha):
            return "Corte " + fecha.formatted(date: .abbreviated, time: .omitted)
        case .historialCompleto:
            return "Todo el historial"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                panelFiltros

                if movimientosFiltrados.isEmpty {
                    Panel {
                        VStack(spacing: 8) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title2)
                                .foregroundStyle(Tema.textoSecundario)
                            Text("No hay movimientos con estos filtros.")
                                .font(.footnote)
                                .foregroundStyle(Tema.textoSecundario)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    Panel {
                        VStack(spacing: 0) {
                            ForEach(movimientosFiltrados) { movimiento in
                                FilaMovimiento(movimiento: movimiento)
                                if movimiento.id != movimientosFiltrados.last?.id {
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
        .navigationTitle("Movimientos")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if cortesOrdenados.isEmpty { periodo = .periodoActual }
        }
    }

    private var panelFiltros: some View {
        Panel {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Menu {
                        opcionPeriodo("Corte vigente", valor: .corteVigente)
                        opcionPeriodo("Periodo actual (sin cortar)", valor: .periodoActual)
                        ForEach(Array(cortesOrdenados.dropFirst()), id: \.id) { corte in
                            opcionPeriodo(
                                "Corte " + corte.fechaCorte.formatted(
                                    date: .abbreviated, time: .omitted),
                                valor: .corteAnterior(corte.fechaCorte))
                        }
                        Divider()
                        opcionPeriodo("Todo el historial", valor: .historialCompleto)
                    } label: {
                        etiquetaFiltro(tituloPeriodo, icono: "calendar")
                    }

                    Menu {
                        ForEach(TipoMovimientos.allCases, id: \.self) { opcion in
                            Button {
                                tipo = opcion
                            } label: {
                                Label(opcion.rawValue,
                                      systemImage: tipo == opcion
                                      ? "checkmark" : opcion.icono)
                            }
                        }
                    } label: {
                        etiquetaFiltro(tipo.rawValue, icono: tipo.icono)
                    }
                }

                HStack(spacing: 10) {
                    Menu {
                        ForEach(EstadoMovimientos.allCases, id: \.self) { opcion in
                            Button {
                                estado = opcion
                            } label: {
                                Label(opcion.rawValue,
                                      systemImage: estado == opcion
                                      ? "checkmark" : "circle")
                            }
                        }
                    } label: {
                        etiquetaFiltro(estado.rawValue, icono: "checkmark.circle")
                    }

                    Spacer()
                    Text("\(movimientosFiltrados.count) resultado" +
                         (movimientosFiltrados.count == 1 ? "" : "s"))
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Tema.textoSecundario)
                    TextField("Buscar comercio o categoría", text: $busqueda)
                        .textInputAutocapitalization(.never)
                    if !busqueda.isEmpty {
                        Button {
                            busqueda = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Tema.textoSecundario)
                        }
                    }
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Tema.panelElevado,
                            in: RoundedRectangle(cornerRadius: 12,
                                                 style: .continuous))
            }
        }
    }

    private func opcionPeriodo(_ titulo: String,
                               valor: PeriodoMovimientos) -> some View {
        Button {
            periodo = valor
        } label: {
            Label(titulo, systemImage: periodo == valor ? "checkmark" : "calendar")
        }
    }

    private func etiquetaFiltro(_ titulo: String, icono: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icono)
            Text(titulo).lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Tema.acento)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Tema.acento.opacity(0.12), in: Capsule())
    }
}
