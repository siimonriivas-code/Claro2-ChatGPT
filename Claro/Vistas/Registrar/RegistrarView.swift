//
//  RegistrarView.swift
//  Claro — Carpeta: Vistas/Registrar
//  ⚠️ REEMPLAZA al existente.
//
//  Novedad: cobro recibido activado. Los MSI y las compras compartidas
//  ahora viven como interruptores DENTRO de "Compra con tarjeta".
//

import SwiftUI

struct RegistrarView: View {

    enum Hoja: String, Identifiable {
        case ingreso, gasto, transferencia, compraCredito, pagoTarjeta, cobro, abonoDeuda
        var id: String { rawValue }
    }

    @State private var hojaActiva: Hoja?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("¿Qué quieres registrar hoy?")
                        .font(.footnote)
                        .foregroundStyle(Tema.textoSecundario)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                        GridItem(.flexible())],
                              spacing: 12) {
                        opcion(titulo: "Gasto",
                               subtitulo: "Débito o efectivo",
                               icono: "arrow.up.right",
                               color: Tema.urgente) { hojaActiva = .gasto }

                        opcion(titulo: "Ingreso",
                               subtitulo: "Cualquier entrada",
                               icono: "arrow.down.left",
                               color: Tema.positivo) { hojaActiva = .ingreso }

                        opcion(titulo: "Compra a crédito",
                               subtitulo: "Normal, MSI o compartida",
                               icono: "creditcard.fill",
                               color: Tema.advertencia) { hojaActiva = .compraCredito }

                        opcion(titulo: "Pago de tarjeta",
                               subtitulo: "Abona a tu deuda",
                               icono: "checkmark.circle.fill",
                               color: Tema.acento) { hojaActiva = .pagoTarjeta }

                        opcion(titulo: "Transferencia",
                               subtitulo: "Entre tus cuentas",
                               icono: "arrow.left.arrow.right",
                               color: Tema.acento) { hojaActiva = .transferencia }

                        opcion(titulo: "Cobro recibido",
                               subtitulo: "Te pagaron algo",
                               icono: "hand.thumbsup.fill",
                               color: Tema.positivo) { hojaActiva = .cobro }

                        opcion(titulo: "Abono a deuda",
                               subtitulo: "Préstamos propios",
                               icono: "banknote.fill",
                               color: Tema.advertencia) { hojaActiva = .abonoDeuda }
                    }
                }
                .padding(16)
            }
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Registrar")
            .sheet(item: $hojaActiva) { hoja in
                switch hoja {
                case .ingreso:       NuevoMovimientoView(tipo: .ingreso)
                case .gasto:         NuevoMovimientoView(tipo: .gasto)
                case .transferencia: TransferenciaView()
                case .compraCredito: NuevaCompraCreditoView()
                case .pagoTarjeta:   PagoTarjetaView()
                case .cobro:         CobroRecibidoView()
                case .abonoDeuda:    AbonoDeudaView()
                }
            }
        }
    }

    private func opcion(titulo: String, subtitulo: String, icono: String,
                        color: Color, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icono)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 12,
                                                     style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Tema.textoPrincipal)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(subtitulo)
                        .font(.caption2)
                        .foregroundStyle(Tema.textoSecundario)
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tema.panel,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(Presionable())
    }
}

#Preview {
    RegistrarView()
        .aparienciaDeLaApp()
}
