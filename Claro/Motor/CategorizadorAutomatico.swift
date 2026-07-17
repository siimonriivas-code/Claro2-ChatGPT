//
//  CategorizadorAutomatico.swift
//  Claro — Carpeta: Motor
//
//  Sugiere una categoría según el nombre del comercio
//  (OXXO → Súper, UBER → Transporte, etc.). Gratis y local.
//

import Foundation

enum CategorizadorAutomatico {

    /// Palabras clave → nombre de categoría (de las predefinidas).
    private static let reglas: [(claves: [String], categoria: String)] = [
        (["OXXO", "SEVEN", "7-ELEVEN", "KIOSKO", "EXTRA "], "Súper"),
        (["WALMART", "WAL-MART", "SORIANA", "CHEDRAUI", "BODEGA AURRERA", "AURRERA", "COSTCO", "SAMS", "SAM'S", "LEY ", "CALIMAX", "HEB"], "Súper"),
        (["UBER", "DIDI", "CABIFY", "INDRIVER", "TAXI"], "Transporte"),
        (["PEMEX", "GASOL", "OXXO GAS", "BP ", "SHELL", "MOBIL", "ARCO"], "Transporte"),
        (["FARMACIA", "GUADALAJARA", "DEL AHORRO", "BENAVIDES", "SIMILARES", "DOCTOR", "HOSPITAL", "CLINICA", "LABORATORIO", "DENTAL"], "Salud"),
        (["CFE", "TELMEX", "IZZI", "TOTALPLAY", "MEGACABLE", "TELCEL", "AT&T", "MOVISTAR", "AGUA ", "CIAPACOV", "GAS NATURAL"], "Servicios"),
        (["NETFLIX", "SPOTIFY", "DISNEY", "HBO", "MAX ", "PRIME VIDEO", "APPLE.COM", "YOUTUBE", "CINEPOLIS", "CINEMEX", "STEAM", "PLAYSTATION", "XBOX", "NINTENDO"], "Entretenimiento"),
        (["RESTAURAN", "TACOS", "TAQUERIA", "SUSHI", "PIZZA", "BURGER", "KFC", "MCDONALD", "STARBUCKS", "CAFE", "COMEDOR", "MARISCOS", "POLLO", "RAPPI", "DIDIFOOD", "UBER EATS", "UBEREATS"], "Comida"),
        (["AMAZON", "MERCADOLIBRE", "MERCADO LIBRE", "SHEIN", "TEMU", "ALIEXPRESS", "LIVERPOOL", "COPPEL", "ELEKTRA", "SEARS", "SUBURBIA"], "Hogar"),
        (["ZARA", "BERSHKA", "PULL", "C&A", "OLD NAVY", "NIKE", "ADIDAS", "SHASA", "CUIDADO CON EL PERRO"], "Ropa"),
        (["ESCUELA", "COLEGIO", "UNIVERSIDAD", "COLEGIATURA", "CURSO", "UDEMY", "PLATZI", "LIBRERIA", "GANDHI"], "Educación"),
        (["VETERINAR", "PETCO", "MASCOTA", "PET "], "Mascotas")
    ]

    /// Devuelve la categoría sugerida para un comercio, o nil si no reconoce.
    static func sugerir(para comercio: String,
                        entre categorias: [Categoria]) -> Categoria? {
        let texto = comercio.uppercased()
        for regla in reglas {
            if regla.claves.contains(where: { texto.contains($0) }) {
                return categorias.first { $0.nombre == regla.categoria }
            }
        }
        return nil
    }
}
