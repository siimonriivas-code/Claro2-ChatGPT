//
//  TarjetaVisual.swift
//  Claro — Carpeta: Vistas/Componentes
//  ⚠️ REEMPLAZA al existente.
//
//  La tarjeta como objeto físico premium (diseño "Claro Premium"):
//  proporción real 1.586:1, chip dorado EMV, holograma iridiscente,
//  reflejo de vidrio, filo de luz, contactless, dígitos mono y píldora
//  de estado en vidrio esmerilado con el semáforo REAL de la tarjeta.
//

import SwiftUI

struct TarjetaVisual: View {
    let tarjeta: TarjetaCredito

    /// Proporción física real de una tarjeta de crédito (ancho/alto).
    /// La usan otras vistas (ej. MazoTarjetas) para calcular alturas.
    static let proporcion: CGFloat = 1.586

    private var colorBase: Color { Color(hex: tarjeta.colorHex) }

    /// Versión oscurecida del color del banco (para el gradiente).
    private func oscurecido(_ factor: Double) -> Color {
        let limpio = tarjeta.colorHex.trimmingCharacters(
            in: CharacterSet.alphanumerics.inverted)
        var valor: UInt64 = 0
        Scanner(string: limpio).scanHexInt64(&valor)
        let r = Double((valor >> 16) & 0xFF) / 255 * factor
        let g = Double((valor >> 8) & 0xFF) / 255 * factor
        let b = Double(valor & 0xFF) / 255 * factor
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    /// La píldora dice la verdad del semáforo.
    private var estado: (texto: String, color: Color) {
        if tarjeta.deudaCalculada <= 0 {
            return ("Sin deuda", Tema.positivo)
        }
        guard let vigente = tarjeta.estadoDeCuentaVigente else {
            return ("Al corriente", Tema.positivo)
        }
        switch vigente.situacion {
        case .cubierto:
            return ("Al corriente", Tema.positivo)
        case .vencidoSinCubrir:
            return ("Vencida", Tema.urgente)
        case .vencidoParcialmenteCubierto:
            return ("Vencida · falta \(vigente.faltaPorCubrir.comoDinero)",
                    Tema.urgente)
        case .pendiente, .parcialmenteCubierto:
            let fecha = vigente.fechaLimitePago
                .formatted(.dateTime.day().month(.abbreviated))
            return ("Vence \(fecha)",
                    vigente.diasParaVencer <= 3 ? Tema.urgente : Tema.advertencia)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            filaSuperior
            Spacer()
            chipDorado
            Spacer()
            filaInferior
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .aspectRatio(Self.proporcion, contentMode: .fit)
        .background(
            LinearGradient(colors: [colorBase, oscurecido(0.32)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        )
        // Reflejo de vidrio + brillo inferior sutil
        .overlay {
            LinearGradient(colors: [.white.opacity(0.18), .clear],
                           startPoint: .topLeading,
                           endPoint: UnitPoint(x: 0.42, y: 0.42))
            RadialGradient(colors: [.white.opacity(0.07), .clear],
                           center: UnitPoint(x: 0.85, y: 1.15),
                           startRadius: 0, endRadius: 220)
        }
        // Holograma iridiscente
        .overlay(alignment: .trailing) {
            Circle()
                .fill(AngularGradient(
                    colors: [.white.opacity(0.4),
                             Color(hex: "8CF5B1").opacity(0.28),
                             Color(hex: "6C8CFF").opacity(0.32),
                             Color(hex: "FF8CC8").opacity(0.28),
                             .white.opacity(0.4)],
                    center: .center,
                    angle: .degrees(210)))
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                .frame(width: 26, height: 26)
                .opacity(0.5)
                .padding(.trailing, 20)
                .offset(y: -6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        // Filo de luz: highlight arriba que se desvanece
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.35),
                                            .white.opacity(0.08)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1)
        }
    }

    // MARK: - Fila superior: logo + banco + contactless
    private var filaSuperior: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(oscurecido(0.5))
                .frame(width: 26, height: 26)
                .overlay {
                    Text(String((tarjeta.banco?.nombre ?? "?").prefix(1)).uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 0.5))

            Text((tarjeta.banco?.nombre ?? "").uppercased())
                .font(.footnote.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.92))

            Text("· \(tarjeta.nombre.uppercased())")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)

            Spacer()

            Image(systemName: "wave.3.right")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    // MARK: - Chip dorado EMV
    private var chipDorado: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(LinearGradient(
                stops: [.init(color: Color(hex: "F2DCA0"), location: 0),
                        .init(color: Color(hex: "C9A24B"), location: 0.55),
                        .init(color: Color(hex: "E9CD8A"), location: 1)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 44, height: 32)
            .overlay {
                GeometryReader { geo in
                    let negro = Color.black.opacity(0.22)
                    Rectangle().fill(negro)
                        .frame(height: 1)
                        .offset(y: geo.size.height * 0.33)
                    Rectangle().fill(negro)
                        .frame(height: 1)
                        .offset(y: geo.size.height * 0.66)
                    Rectangle().fill(negro)
                        .frame(width: 1)
                        .offset(x: geo.size.width * 0.5)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(.black.opacity(0.18), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    // MARK: - Fila inferior: dígitos + estado / deuda
    private var filaInferior: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text(tarjeta.ultimosDigitos.isEmpty
                     ? "••••  ••••  ••••  ••••"
                     : "••••  ••••  ••••  \(tarjeta.ultimosDigitos)")
                    .font(.system(.subheadline, design: .monospaced).weight(.medium))
                    .monospacedDigit()
                    .tracking(1.0)
                    .foregroundStyle(.white.opacity(0.85))

                Text(estado.texto)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(estado.color)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background {
                        ZStack {
                            Capsule().fill(.ultraThinMaterial)
                            Capsule().fill(Color.black.opacity(0.20))
                        }
                    }
                    .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 0.5))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("DEUDA")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.65))
                Text(tarjeta.deudaCalculada.comoDinero)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(tarjeta.deudaCalculada <= 0
                                     ? Tema.positivo : .white)
            }
        }
    }
}
