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
    @Environment(\.dismiss) private var cerrar

    enum Hoja: String, Identifiable {
        case ingreso, gasto, transferencia, compraCredito, pagoTarjeta, cobro, abonoDeuda
        var id: String { rawValue }
    }

    @State private var hojaActiva: Hoja?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MOVIMIENTO RÁPIDO")
                            .font(.caption2.weight(.bold))
                            .tracking(1.35)
                            .foregroundStyle(Tema.positivo)
                        Text("¿Qué pasó con tu dinero?")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Tema.textoPrincipal)
                        Text("Elige una acción; Claro conectará cuentas, tarjetas y personas.")
                            .font(.footnote)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                    .padding(.bottom, 4)

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
            .background(FondoClaro())
            .navigationTitle("Registrar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { cerrar() }
                }
            }
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
                OrbeClaro(icono: icono, color: color, lado: 40)
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
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [color.opacity(0.35), .clear],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing), lineWidth: 0.8)
            }
            .shadow(color: color.opacity(0.08), radius: 12, y: 6)
        }
        .buttonStyle(Presionable())
    }
}

#Preview {
    RegistrarView()
        .aparienciaDeLaApp()
}
