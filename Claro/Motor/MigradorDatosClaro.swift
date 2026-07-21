import Foundation
import SwiftData

enum MigradorDatosClaro {
    private static let clave = "versionModeloDatosClaro"
    static let versionActual = 3

    /// Las etapas son idempotentes: interrumpir la app no deja una migración
    /// a medias y volver a abrirla es seguro.
    @MainActor static func ejecutarSiHaceFalta(contexto: ModelContext) {
        var version = UserDefaults.standard.integer(forKey: clave)
        if version < 1 {
            // La versión original no almacenaba número de esquema.
            version = 1
            UserDefaults.standard.set(version, forKey: clave)
        }
        if version < 2 {
            // Los nuevos campos financieros son opcionales y los modelos
            // avanzados nacen vacíos; SwiftData realiza la migración ligera.
            // Esta etapa deja el punto explícito para futuras normalizaciones.
            try? contexto.save()
            version = 2
            UserDefaults.standard.set(version, forKey: clave)
        }
        if version < 3 {
            do {
                try reclasificarExcedentesHistoricos(contexto: contexto)
                try contexto.save()
                version = 3
                UserDefaults.standard.set(version, forKey: clave)
            } catch {
                return
            }
        }
    }

    /// Versiones anteriores restaban el depósito completo a la persona. Si
    /// alguien pagaba más que sus compras capturadas, aparecía como si el
    /// usuario le debiera. Conservamos el dinero en la cuenta, aplicamos solo
    /// lo adeudado y convertimos el resto en un ingreso vinculado a la persona.
    @MainActor private static func reclasificarExcedentesHistoricos(
        contexto: ModelContext
    ) throws {
        let personas = try contexto.fetch(FetchDescriptor<Persona>())
        for persona in personas {
            let cobros = persona.movimientos
                .filter { $0.cuentaParaCalculos && $0.tipo == .cobroRecibido }
                .sorted {
                    if $0.fecha != $1.fecha { return $0.fecha < $1.fecha }
                    return $0.creadoEl < $1.creadoEl
                }
            var aplicadoAnterior = 0.0

            for cobro in cobros {
                let deudaDisponible = persona.participaciones
                    .filter {
                        guard let movimiento = $0.compra?.movimiento else {
                            return false
                        }
                        return movimiento.cuentaParaCalculos
                            && movimiento.fecha <= cobro.fecha
                    }
                    .reduce(0) { $0 + $1.monto }
                let distribucion = MotorDePersonas.distribuirCobro(
                    monto: cobro.monto,
                    saldoPendiente: max(0, deudaDisponible - aplicadoAnterior))
                aplicadoAnterior += distribucion.aplicadoADeuda

                guard distribucion.excedenteComoIngreso > 0 else { continue }
                let detalleAnterior = cobro.detalle
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let concepto = detalleAnterior.isEmpty
                    ? "Excedente recibido de \(persona.nombre)"
                    : "\(detalleAnterior) · excedente"

                if distribucion.aplicadoADeuda > 0 {
                    cobro.monto = distribucion.aplicadoADeuda
                    cobro.editadoEl = .now
                    let ingreso = Movimiento(
                        tipo: .ingreso,
                        monto: distribucion.excedenteComoIngreso,
                        fecha: cobro.fecha,
                        detalle: concepto,
                        cuenta: cobro.cuenta,
                        persona: persona)
                    ingreso.importacionID = cobro.importacionID
                    contexto.insert(ingreso)
                } else {
                    cobro.tipo = .ingreso
                    cobro.detalle = concepto
                    cobro.editadoEl = .now
                }
            }
        }
    }
}
