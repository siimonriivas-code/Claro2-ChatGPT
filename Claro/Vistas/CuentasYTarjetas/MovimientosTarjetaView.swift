//
//  MovimientosTarjetaView.swift
//  Claro — Carpeta: Vistas/CuentasYTarjetas
//
//  La lista COMPLETA de movimientos de una tarjeta: compras regulares,
//  a meses, pagos, todo. Toca cualquiera para editarlo o dividirlo
//  entre personas (hermanos, novia, etc.).
//

import SwiftUI
import SwiftData

struct MovimientosTarjetaView: View {
    let tarjeta: TarjetaCredito

    private var movimientosOrdenados: [Movimiento] {
        tarjeta.movimientos.sorted { $0.fecha > $1.fecha }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Panel {
                    Label("Toca cualquier movimiento para editarlo, cancelarlo o dividirlo entre personas.",
                          systemImage: "hand.tap.fill")
                        .font(.footnote)
                        .foregroundStyle(Tema.textoSecundario)
                }

                if movimientosOrdenados.isEmpty {
                    Panel {
                        Text("Esta tarjeta aún no tiene movimientos.")
                            .font(.footnote)
                            .foregroundStyle(Tema.textoSecundario)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Panel {
                        VStack(spacing: 0) {
                            ForEach(movimientosOrdenados) { movimiento in
                                FilaMovimiento(movimiento: movimiento)
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
        .navigationTitle("Movimientos")
        .navigationBarTitleDisplayMode(.inline)
    }
}
