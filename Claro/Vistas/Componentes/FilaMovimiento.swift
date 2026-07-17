//
//  FilaMovimiento.swift
//  Claro — Carpeta: Vistas/Componentes
//  ⚠️ REEMPLAZA al existente.
//
//  Novedad (Ley 4): ahora CUALQUIER movimiento de cualquier lista se
//  puede tocar para abrir su detalle, editarlo o cancelarlo.
//

import SwiftUI

struct FilaMovimiento: View {
    let movimiento: Movimiento

    /// Cuenta desde cuya "perspectiva" se mira (para saber si una
    /// transferencia entra o sale de ella). Puede omitirse.
    var perspectiva: CuentaBancaria? = nil

    @State private var mostrandoDetalle = false

    private var esEntrada: Bool {
        switch movimiento.tipo {
        case .ingreso, .cobroRecibido, .bonificacion:
            return true
        case .transferencia:
            return movimiento.cuentaDestino != nil
                && movimiento.cuentaDestino == perspectiva
        case .ajuste:
            return movimiento.monto >= 0
        default:
            return false
        }
    }

    private var icono: String {
        if let cat = movimiento.categoria { return cat.icono }
        switch movimiento.tipo {
        case .ingreso:        return "arrow.down.circle.fill"
        case .transferencia:  return "arrow.left.arrow.right.circle.fill"
        case .pagoTarjeta:    return "creditcard.circle.fill"
        case .cobroRecibido:  return "person.crop.circle.badge.checkmark"
        case .ajuste:         return "slider.horizontal.3"
        default:              return "circle.fill"
        }
    }

    private var colorIcono: Color {
        if let cat = movimiento.categoria { return Color(hex: cat.colorHex) }
        return esEntrada ? Tema.positivo : Tema.acento
    }

    private var cancelado: Bool { movimiento.estado == .cancelado }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icono)
                .font(.title3)
                .foregroundStyle(colorIcono)
                .frame(width: 36, height: 36)
                .background(colorIcono.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(movimiento.detalle.isEmpty ? movimiento.tipo.rawValue
                                                : movimiento.detalle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Tema.textoPrincipal)
                    .strikethrough(cancelado)

                Text(movimiento.fecha.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
            }

            Spacer()

            Text((esEntrada ? "+" : "−") + abs(movimiento.monto).comoDinero)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(esEntrada ? Tema.positivo : Tema.textoPrincipal)
                .strikethrough(cancelado)
        }
        .opacity(cancelado ? 0.45 : 1)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { mostrandoDetalle = true }
        .sheet(isPresented: $mostrandoDetalle) {
            MovimientoDetalleView(movimiento: movimiento)
        }
    }
}
