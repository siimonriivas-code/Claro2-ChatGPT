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
    static let fondo         = Color(claro: "F5F7FC", oscuro: "070A11")
    static let panel         = Color(claro: "FFFFFF", oscuro: "111722")
    static let panelElevado  = Color(claro: "E9EEF8", oscuro: "192231")
    static let panelProfundo = Color(claro: "E2E8F4", oscuro: "0C111B")

    // Texto
    static let textoPrincipal  = Color(claro: "111827", oscuro: "F7F9FC")
    static let textoSecundario = Color(claro: "667085", oscuro: "909BB0")

    // Acentos con significado (más profundos en claro para que contrasten)
    static let positivo    = Color(claro: "078C68", oscuro: "55EDB5")
    static let advertencia = Color(claro: "B86B00", oscuro: "FFB84D")
    static let urgente     = Color(claro: "D43C55", oscuro: "FF667D")
    static let acento      = Color(claro: "315BE8", oscuro: "7594FF")
    static let cyan        = Color(claro: "007E99", oscuro: "48D7F0")
    static let violeta     = Color(claro: "7546D8", oscuro: "B493FF")
    static let coral       = Color(claro: "D9573F", oscuro: "FF8B72")
    static let oro         = Color(claro: "A66A00", oscuro: "FFD275")

    // Panel protagonista del Inicio (Disponible real)
    static let heroSuperior = Color(claro: "DDEBFF", oscuro: "122A38")
    static let heroInferior = Color(claro: "F2ECFF", oscuro: "151426")
    static let heroBorde    = Color(claro: "C7D7F3", oscuro: "2A3A52")
    static let heroTexto    = Color(claro: "4C6689", oscuro: "AABBD2")

    static let gradienteMarca = LinearGradient(
        colors: [positivo, cyan, acento, violeta],
        startPoint: .topLeading,
        endPoint: .bottomTrailing)

    static let gradienteAccion = LinearGradient(
        colors: [Color(claro: "087F68", oscuro: "36CFA0"),
                 Color(claro: "176D9F", oscuro: "3199C9")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing)

    /// Gradiente "de plástico" para las tarjetas de crédito:
    /// del color del banco hacia su versión muy oscura.
    static func gradientePlastico(hex: String) -> LinearGradient {
        gradienteTarjeta(hex: hex)
    }

    /// Conserva la identidad del banco y añade una tinta vecina y profundidad.
    static func coloresPrismaticos(hex: String) -> [Color] {
        let base = UIColor(hexString: hex)
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard base.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return [Color(hex: hex), Color(hex: hex, brillo: 0.30)]
        }
        let saturacion = max(0.55, s)
        let secundaria = UIColor(
            hue: (h + 0.09).truncatingRemainder(dividingBy: 1),
            saturation: min(1, saturacion + 0.12),
            brightness: max(0.50, b * 0.84), alpha: 1)
        let profunda = UIColor(
            hue: (h + 0.98).truncatingRemainder(dividingBy: 1),
            saturation: min(1, saturacion + 0.18),
            brightness: max(0.16, b * 0.30), alpha: 1)
        return [Color(uiColor: base), Color(uiColor: secundaria),
                Color(uiColor: profunda)]
    }

    static func gradienteTarjeta(hex: String) -> LinearGradient {
        LinearGradient(colors: coloresPrismaticos(hex: hex),
                       startPoint: UnitPoint(x: 0.04, y: 0.02),
                       endPoint: UnitPoint(x: 0.96, y: 1))
    }

    static let gradienteBorde = LinearGradient(
        colors: [.white.opacity(0.36), acento.opacity(0.18),
                 positivo.opacity(0.12), .white.opacity(0.03)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing)

    /// Gradiente del panel protagonista del Inicio (Disponible real).
    static let gradienteHero = LinearGradient(
        colors: [heroSuperior, heroInferior],
        startPoint: .topLeading,
        endPoint: .bottomTrailing)
}

/// Fondo oficial de contenido. Las auroras son tenues para no competir con
/// cifras, estados ni gráficas.
struct FondoClaro: View {
    @Environment(\.colorScheme) private var esquema

    var body: some View {
        ZStack {
            Tema.fondo
            Circle()
                .fill(Tema.acento.opacity(esquema == .dark ? 0.13 : 0.09))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: 170, y: -330)
            Circle()
                .fill(Tema.positivo.opacity(esquema == .dark ? 0.10 : 0.08))
                .frame(width: 320, height: 320)
                .blur(radius: 100)
                .offset(x: -190, y: 260)
            Circle()
                .fill(Tema.violeta.opacity(esquema == .dark ? 0.08 : 0.05))
                .frame(width: 280, height: 280)
                .blur(radius: 110)
                .offset(x: 180, y: 610)
        }
        .ignoresSafeArea()
    }
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
