//
//  ExtractorPDF.swift
//  Claro — Carpeta: Motor
//
//  Extrae el texto de un PDF (estado de cuenta) usando PDFKit,
//  la herramienta nativa y gratuita de Apple. Todo ocurre en el iPhone.
//

import Foundation
import CryptoKit
import PDFKit
import UIKit
import Vision

enum ExtractorPDF {

    /// Huella irreversible del archivo para reconocer el mismo estado de
    /// cuenta sin conservar el PDF ni exponer sus datos.
    static func huellaSHA256(de url: URL) async -> String? {
        await Task.detached(priority: .utility) {
            let accesoConcedido = url.startAccessingSecurityScopedResource()
            defer {
                if accesoConcedido { url.stopAccessingSecurityScopedResource() }
            }
            guard let datos = try? Data(contentsOf: url,
                                        options: [.mappedIfSafe]) else { return nil }
            return SHA256.hash(data: datos)
                .map { String(format: "%02x", $0) }
                .joined()
        }.value
    }

    /// Devuelve el texto del PDF, página por página. PDFKit es la primera
    /// opción; Vision entra automáticamente cuando el documento es una
    /// imagen (Liverpool) o cuando la disposición visual de las tablas es
    /// más fiable que el orden interno del PDF (Hey Banco).
    static func paginas(de url: URL) async -> [String] {
        await Task.detached(priority: .userInitiated) {
            paginasSincrono(de: url)
        }.value
    }

    private nonisolated static func paginasSincrono(de url: URL) -> [String] {
        // Permiso temporal para leer el archivo elegido por el usuario
        let accesoConcedido = url.startAccessingSecurityScopedResource()
        defer {
            if accesoConcedido { url.stopAccessingSecurityScopedResource() }
        }

        guard let documento = PDFDocument(url: url) else { return [] }

        let textosDigitales: [String] = (0..<documento.pageCount).map { indice in
            documento.page(at: indice)?.string ?? ""
        }
        let textoDocumento = normalizar(textosDigitales.joined(separator: "\n"))
        let esHeyBanco = textoDocumento.contains("HEY BANCO")
            || textoDocumento.contains("HEYBANCO")

        var resultado: [String] = []
        for indice in 0..<documento.pageCount {
            guard let pagina = documento.page(at: indice) else { continue }
            let textoDigital = textosDigitales[indice]
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let necesitaOCR = esHeyBanco || !tieneTextoUtil(textoDigital)
            if necesitaOCR,
               let textoOCR = reconocerTexto(en: pagina),
               tieneTextoUtil(textoOCR) {
                resultado.append(textoOCR)
            } else if !textoDigital.isEmpty {
                resultado.append(textoDigital)
            }
        }
        return resultado
    }

    private nonisolated static func tieneTextoUtil(_ texto: String) -> Bool {
        let caracteresUtiles = texto.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        }.count
        return caracteresUtiles >= 40
    }

    private nonisolated static func reconocerTexto(en pagina: PDFPage) -> String? {
        autoreleasepool {
            let limites = pagina.bounds(for: .mediaBox)
            guard limites.width > 0, limites.height > 0 else { return nil }

            // Unas 2,600 px en el lado mayor mantienen legible la letra
            // pequeña de los estados de cuenta sin disparar la memoria.
            let escala = min(3.0, 2_600.0 / max(limites.width, limites.height))
            let tamano = CGSize(width: limites.width * escala,
                                height: limites.height * escala)
            let imagen = pagina.thumbnail(of: tamano, for: .mediaBox)
            guard let cgImage = imagen.cgImage else { return nil }

            let solicitud = VNRecognizeTextRequest()
            solicitud.recognitionLevel = .accurate
            solicitud.recognitionLanguages = ["es-MX", "en-US"]
            solicitud.usesLanguageCorrection = true
            solicitud.minimumTextHeight = 0.006
            solicitud.customWords = [
                "Liverpool", "Hey Banco", "Telcel", "CFE",
                "pago mínimo", "saldo al corte"
            ]

            let manejador = VNImageRequestHandler(cgImage: cgImage,
                                                   orientation: .up,
                                                   options: [:])
            do {
                try manejador.perform([solicitud])
            } catch {
                return nil
            }

            let elementos: [ElementoOCR] = (solicitud.results ?? []).compactMap { observacion in
                guard let candidato = observacion.topCandidates(1).first else { return nil }
                return ElementoOCR(texto: candidato.string,
                                   rectangulo: observacion.boundingBox)
            }
            guard !elementos.isEmpty else { return nil }
            return reconstruirRenglones(elementos)
        }
    }

    private struct ElementoOCR {
        let texto: String
        let rectangulo: CGRect
    }

    /// Vision puede devolver la etiqueta y el importe como observaciones
    /// separadas. Se vuelven a unir usando su posición para conservar las
    /// filas que una persona ve en la tabla.
    private nonisolated static func reconstruirRenglones(_ elementos: [ElementoOCR]) -> String {
        var renglones: [[ElementoOCR]] = []
        let ordenados = elementos.sorted {
            if abs($0.rectangulo.midY - $1.rectangulo.midY) > 0.004 {
                return $0.rectangulo.midY > $1.rectangulo.midY
            }
            return $0.rectangulo.minX < $1.rectangulo.minX
        }

        for elemento in ordenados {
            if let indice = renglones.lastIndex(where: { renglon in
                guard let referencia = renglon.first else { return false }
                let tolerancia = max(elemento.rectangulo.height,
                                     referencia.rectangulo.height) * 0.55
                return abs(elemento.rectangulo.midY
                           - referencia.rectangulo.midY) <= tolerancia
            }) {
                renglones[indice].append(elemento)
            } else {
                renglones.append([elemento])
            }
        }

        return renglones
            .sorted { renglon1, renglon2 in
                (renglon1.map(\.rectangulo.midY).max() ?? 0)
                    > (renglon2.map(\.rectangulo.midY).max() ?? 0)
            }
            .map { renglon in
                renglon.sorted { $0.rectangulo.minX < $1.rectangulo.minX }
                    .map(\.texto)
                    .joined(separator: " ")
            }
            .joined(separator: "\n")
    }

    private nonisolated static func normalizar(_ texto: String) -> String {
        texto.folding(options: [.diacriticInsensitive, .caseInsensitive],
                      locale: Locale(identifier: "es_MX"))
            .uppercased()
    }
}
