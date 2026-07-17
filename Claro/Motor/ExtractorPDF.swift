//
//  ExtractorPDF.swift
//  Claro — Carpeta: Motor
//
//  Extrae el texto de un PDF (estado de cuenta) usando PDFKit,
//  la herramienta nativa y gratuita de Apple. Todo ocurre en el iPhone.
//

import Foundation
import PDFKit

enum ExtractorPDF {

    /// Devuelve el texto del PDF, página por página.
    static func paginas(de url: URL) -> [String] {
        // Permiso temporal para leer el archivo elegido por el usuario
        let accesoConcedido = url.startAccessingSecurityScopedResource()
        defer {
            if accesoConcedido { url.stopAccessingSecurityScopedResource() }
        }

        guard let documento = PDFDocument(url: url) else { return [] }

        var resultado: [String] = []
        for indice in 0..<documento.pageCount {
            if let texto = documento.page(at: indice)?.string,
               !texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resultado.append(texto)
            }
        }
        return resultado
    }
}
