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
    @ViewBuilder var contenido: () -> Contenido

    var body: some View {
        contenido()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Tema.panel,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                // Filo de luz sutil: da el acabado premium en toda la app
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Tema.panelElevado.opacity(0.6), lineWidth: 1)
            )
    }
}

/// Etiqueta pequeña tipo píldora, por ejemplo "5 días".
struct Pildora: View {
    let texto: String
    var color: Color = Tema.acento

    var body: some View {
        Text(texto)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}

/// Título de sección en mayúsculas pequeñas (ej. "PAGOS PRÓXIMOS").
struct TituloSeccion: View {
    let texto: String

    var body: some View {
        Text(texto.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(Tema.textoSecundario)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
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
