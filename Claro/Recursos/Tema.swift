//
//  Tema.swift
//  Claro — Carpeta: Recursos
//
//  Paleta de la app en DOS modos: cada color tiene su versión clara
//  y oscura, y cambia solo según la apariencia elegida en Configuración
//  (Sistema / Claro / Oscuro).
//
//  También: modo privacidad. Cuando "Ocultar montos" está activo,
//  TODOS los montos de la app se muestran como "$ ••••".
//

import SwiftUI
import UIKit

// MARK: - Crear colores con código hexadecimal (ej. "0B0E14")

extension UIColor {
    /// `brillo` multiplica cada canal: 1 = color tal cual, 0.3 = muy oscuro.
    convenience init(hexString: String, brillo: Double = 1) {
        let limpio = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var valor: UInt64 = 0
        Scanner(string: limpio).scanHexInt64(&valor)
        self.init(red: Double((valor >> 16) & 0xFF) / 255 * brillo,
                  green: Double((valor >> 8) & 0xFF) / 255 * brillo,
                  blue: Double(valor & 0xFF) / 255 * brillo,
                  alpha: 1)
    }
}

extension Color {
    /// Color fijo desde hex. `brillo` lo oscurece (0.3 = muy oscuro).
    init(hex: String, brillo: Double = 1) {
        self.init(uiColor: UIColor(hexString: hex, brillo: brillo))
    }

    /// Color que se adapta solo al modo: un hex para claro, otro para oscuro.
    init(claro: String, oscuro: String) {
        self.init(uiColor: UIColor { rasgos in
            rasgos.userInterfaceStyle == .dark
                ? UIColor(hexString: oscuro)
                : UIColor(hexString: claro)
        })
    }
}

// MARK: - Paleta oficial de la app (adaptable a claro/oscuro)

enum Tema {
    // Fondos
    static let fondo        = Color(claro: "F2F4F8", oscuro: "0B0E14")
    static let panel        = Color(claro: "FFFFFF", oscuro: "151A23")
    static let panelElevado = Color(claro: "E9EDF4", oscuro: "1C2230")

    // Texto
    static let textoPrincipal  = Color(claro: "141A26", oscuro: "F2F5F9")
    static let textoSecundario = Color(claro: "5F6877", oscuro: "8A93A6")

    // Acentos con significado (más profundos en claro para que contrasten)
    static let positivo    = Color(claro: "0E9D6B", oscuro: "4ADE9C")  // verde
    static let advertencia = Color(claro: "C4790A", oscuro: "F5B14C")  // ámbar
    static let urgente     = Color(claro: "D64545", oscuro: "F26D6D")  // rojo
    static let acento      = Color(claro: "3E63E8", oscuro: "6C8CFF")  // azul

    // Panel protagonista del Inicio (Disponible real)
    static let heroSuperior = Color(claro: "DCE9F7", oscuro: "18324A")
    static let heroInferior = Color(claro: "EDF3FA", oscuro: "111826")
    static let heroBorde    = Color(claro: "C3D4E8", oscuro: "26364A")
    static let heroTexto    = Color(claro: "5B7797", oscuro: "9FB4C9")

    /// Gradiente "de plástico" para las tarjetas de crédito:
    /// del color del banco hacia su versión muy oscura.
    static func gradientePlastico(hex: String) -> LinearGradient {
        LinearGradient(colors: [Color(hex: hex),
                                Color(hex: hex, brillo: 0.30)],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }

    /// Gradiente del panel protagonista del Inicio (Disponible real).
    static let gradienteHero = LinearGradient(
        colors: [heroSuperior, heroInferior],
        startPoint: .topLeading,
        endPoint: .bottomTrailing)
}

// MARK: - Apariencia elegida por el usuario (Configuración)

enum Apariencia: String, CaseIterable {
    case sistema, claro, oscuro

    var titulo: String {
        switch self {
        case .sistema: return "Sistema"
        case .claro:   return "Claro"
        case .oscuro:  return "Oscuro"
        }
    }

    var esquema: ColorScheme? {
        switch self {
        case .sistema: return nil     // sigue al iPhone
        case .claro:   return .light
        case .oscuro:  return .dark
        }
    }
}

extension View {
    /// Aplica la apariencia elegida en Configuración.
    /// Úsalo en la raíz y en cada sheet (los sheets no la heredan).
    func aparienciaDeLaApp() -> some View {
        modifier(ModificadorApariencia())
    }
}

private struct ModificadorApariencia: ViewModifier {
    @AppStorage("apariencia") private var apariencia = Apariencia.oscuro.rawValue

    func body(content: Content) -> some View {
        content.preferredColorScheme(
            Apariencia(rawValue: apariencia)?.esquema ?? .dark)
    }
}

// MARK: - Formato de dinero (pesos mexicanos)

extension Double {
    /// Normaliza el valor a centavos antes de guardarlo o calcular con él.
    /// Conserva compatibilidad con la base existente y evita fracciones
    /// invisibles de centavo propias de los números de punto flotante.
    var redondeadoAMoneda: Double {
        guard isFinite else { return 0 }
        return (self * 100).rounded() / 100
    }

    /// Convierte 4250.5 en "$4,250.50".
    /// Si el modo privacidad está activo (ojo 👁️ en Inicio o en
    /// Configuración), devuelve "$ ••••" en TODA la app.
    var comoDinero: String {
        if UserDefaults.standard.bool(forKey: "montosOcultos") {
            return "$ ••••"
        }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "es_MX")
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: redondeadoAMoneda)) ?? "$0.00"
    }
}
