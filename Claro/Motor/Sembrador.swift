//
//  Sembrador.swift
//  Claro — Carpeta: Motor
//
//  Siembra los datos iniciales la primera vez que se abre la app:
//  por ahora, las categorías predefinidas. Si ya existen, no hace nada.
//

import Foundation
import SwiftData

enum Sembrador {

    static func sembrarSiHaceFalta(contexto: ModelContext) {
        let cuantas = (try? contexto.fetchCount(FetchDescriptor<Categoria>())) ?? 0
        guard cuantas == 0 else { return }   // ya hay categorías: no duplicar

        for c in Categoria.predefinidas {
            let categoria = Categoria(nombre: c.nombre,
                                      icono: c.icono,
                                      colorHex: c.colorHex,
                                      esPredefinida: true)
            contexto.insert(categoria)
        }
    }
}
