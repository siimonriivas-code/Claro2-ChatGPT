//
//  PlanificacionStore.swift
//  Claro
//

import Foundation
import Observation

struct PresupuestoCategoria: Codable, Identifiable, Hashable {
    var id = UUID()
    var categoria: String
    var limiteMensual: Double
}

struct MetaAhorro: Codable, Identifiable, Hashable {
    var id = UUID()
    var nombre: String
    var objetivo: Double
    var acumulado: Double
    var fechaObjetivo: Date?
}

struct DatosPlanificacion: Codable {
    var presupuestos: [PresupuestoCategoria] = []
    var metas: [MetaAhorro] = []
}

@Observable
final class PlanificacionStore {
    private static let clave = "planificacionClaro"

    var datos: DatosPlanificacion {
        didSet { guardar() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.clave),
           let guardados = try? JSONDecoder().decode(DatosPlanificacion.self,
                                                      from: data) {
            datos = guardados
        } else {
            datos = DatosPlanificacion()
        }
    }

    func guardar() {
        guard let data = try? JSONEncoder().encode(datos) else { return }
        UserDefaults.standard.set(data, forKey: Self.clave)
    }

    func guardarPresupuesto(_ presupuesto: PresupuestoCategoria) {
        var presupuesto = presupuesto
        presupuesto.limiteMensual = presupuesto.limiteMensual.redondeadoAMoneda
        if let indice = datos.presupuestos.firstIndex(where: {
            $0.categoria == presupuesto.categoria
        }) {
            datos.presupuestos[indice] = presupuesto
        } else {
            datos.presupuestos.append(presupuesto)
        }
    }

    func eliminarPresupuesto(_ presupuesto: PresupuestoCategoria) {
        datos.presupuestos.removeAll { $0.id == presupuesto.id }
    }

    func guardarMeta(_ meta: MetaAhorro) {
        var meta = meta
        meta.objetivo = meta.objetivo.redondeadoAMoneda
        meta.acumulado = meta.acumulado.redondeadoAMoneda
        if let indice = datos.metas.firstIndex(where: { $0.id == meta.id }) {
            datos.metas[indice] = meta
        } else {
            datos.metas.append(meta)
        }
    }

    func eliminarMeta(_ meta: MetaAhorro) {
        datos.metas.removeAll { $0.id == meta.id }
    }
}
