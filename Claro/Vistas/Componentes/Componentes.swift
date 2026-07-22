//
//  Componentes.swift
//  Claro — Carpeta: Vistas/Componentes
//
//  Bloques de diseño reutilizables. Toda la app usa estas mismas piezas
//  para que el estilo sea coherente en cada pantalla.
//

import SwiftUI
import UIKit

/// Panel base: el contenedor tipo "tarjeta" con esquinas redondeadas
/// que usa toda la app.
struct Panel<Contenido: View>: View {
    @Environment(\.colorScheme) private var esquema
    @ViewBuilder var contenido: () -> Contenido

    var body: some View {
        contenido()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Tema.panel)
                    .overlay {
                        LinearGradient(
                            colors: [.white.opacity(esquema == .dark ? 0.035 : 0.55),
                                     Tema.acento.opacity(0.025), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing)
                            .clipShape(RoundedRectangle(cornerRadius: 24,
                                                       style: .continuous))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Tema.gradienteBorde, lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(esquema == .dark ? 0.22 : 0.07),
                    radius: 16, x: 0, y: 8)
    }
}

/// Etiqueta pequeña tipo píldora, por ejemplo "5 días".
struct Pildora: View {
    let texto: String
    var color: Color = Tema.acento

    var body: some View {
        Text(texto)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
            .overlay(Capsule().stroke(color.opacity(0.24), lineWidth: 0.7))
    }
}

/// Título de sección en mayúsculas pequeñas (ej. "PAGOS PRÓXIMOS").
struct TituloSeccion: View {
    let texto: String

    var body: some View {
        Text(texto.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(1.25)
            .foregroundStyle(Tema.textoSecundario)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 7)
    }
}

/// Acción protagonista común a toda la app.
struct BotonPrincipalClaro: View {
    let titulo: String
    var subtitulo: String? = nil
    var icono: String = "plus"
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack(spacing: 12) {
                Image(systemName: icono)
                    .font(.headline.weight(.bold))
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.18), in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(titulo).font(.headline)
                    if let subtitulo {
                        Text(subtitulo)
                            .font(.caption)
                            .opacity(0.78)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .opacity(0.72)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Tema.gradienteAccion,
                        in: RoundedRectangle(cornerRadius: 20,
                                             style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 0.8)
            }
            .shadow(color: Tema.positivo.opacity(0.20), radius: 18, y: 8)
        }
        .buttonStyle(Presionable())
    }
}

/// Identificador cromático para métricas y accesos; evita círculos planos.
struct OrbeClaro: View {
    let icono: String
    var color: Color = Tema.acento
    var lado: CGFloat = 44

    var body: some View {
        Image(systemName: icono)
            .font(.system(size: lado * 0.38, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: lado, height: lado)
            .background(
                LinearGradient(colors: [color, color.opacity(0.62), Tema.violeta],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: lado * 0.34,
                                     style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: lado * 0.34, style: .continuous)
                    .strokeBorder(.white.opacity(0.26), lineWidth: 0.8)
            }
            .shadow(color: color.opacity(0.26), radius: 12, y: 6)
    }
}

/// Logo del banco. Si en Assets existe una imagen llamada
/// "logo_<nombre del banco>" (minúsculas, sin acentos, espacios como _),
/// la usa: p. ej. "logo_banamex", "logo_bbva", "logo_nu".
/// Si no, muestra la inicial sobre el color de marca del banco.
struct LogoBanco: View {
    let banco: Banco
    var lado: CGFloat = 28

    private var nombreAsset: String {
        "logo_" + banco.nombre
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
    }

    var body: some View {
        if UIImage(named: nombreAsset) != nil {
            Image(nombreAsset)
                .resizable()
                .scaledToFill()
                .frame(width: lado, height: lado)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
        } else {
            Text(String(banco.nombre.prefix(1)).uppercased())
                .font(.system(size: lado * 0.45, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: lado, height: lado)
                .background(Color(hex: banco.colorHex), in: Circle())
        }
    }
}

/// Estilo de botón con respuesta táctil: al presionar, el contenido
/// se encoge ligeramente y se atenúa, como una tarjeta física.
/// Úsalo en cualquier fila o tarjeta tocable: .buttonStyle(Presionable())
struct Presionable: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

extension View {
    /// Al hacer scroll, los paneles entran y salen con un ligero
    /// desvanecimiento y escala en los bordes de la pantalla.
    func aparicionAlDesplazar() -> some View {
        scrollTransition(.interactive) { contenido, fase in
            contenido
                .opacity(fase.isIdentity ? 1 : 0.55)
                .scaleEffect(fase.isIdentity ? 1 : 0.96)
        }
    }
}
