import Foundation
import SwiftData

enum MigradorDatosClaro {
    private static let clave = "versionModeloDatosClaro"
    static let versionActual = 5

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
        if version < 4 {
            // El módulo de gastos compartidos nace vacío y aislado. SwiftData
            // agrega sus modelos mediante migración ligera.
            try? contexto.save()
            version = 4
            UserDefaults.standard.set(version, forKey: clave)
        }
        if version < 5 {
            do {
                try repararPagosReutilizados(contexto: contexto)
                try contexto.save()
                version = 5
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

    /// Repara el caso histórico detectado al importar un corte nuevo: un pago
    /// ya registrado antes de esa importación tenía una fecha capturada
    /// posterior al corte y coincidía exactamente con el PNGI anterior. La
    /// coincidencia de importe + orden de creación evita reasignar pagos
    /// legítimos del corte actual.
    @MainActor private static func repararPagosReutilizados(
        contexto: ModelContext
    ) throws {
        let tarjetas = try contexto.fetch(FetchDescriptor<TarjetaCredito>())
        let calendario = Calendar.current

        for tarjeta in tarjetas {
            let estados = tarjeta.estadosDeCuenta.sorted {
                $0.fechaCorte < $1.fechaCorte
            }
            guard estados.count >= 2 else { continue }

            for indice in 1..<estados.count {
                let anterior = estados[indice - 1]
                let actual = estados[indice]
                guard let loteActual = actual.importacionID,
                      let importadoEl = tarjeta.movimientos
                        .filter({ $0.importacionID == loteActual })
                        .map(\.creadoEl).min()
                else { continue }

                let inicioActual = calendario.startOfDay(for: actual.fechaCorte)
                let candidatos = tarjeta.movimientos.filter {
                    $0.cuentaParaCalculos
                        && $0.tipo == .pagoTarjeta
                        && $0.fechaCorteObjetivoPago == nil
                        && $0.creadoEl < importadoEl
                        && calendario.startOfDay(for: $0.fecha) >= inicioActual
                }
                let total = candidatos.reduce(0) { $0 + $1.monto }
                    .redondeadoAMoneda
                guard !candidatos.isEmpty,
                      abs(total - anterior.pagoParaNoGenerarIntereses) <= 1.0
                else { continue }

                for pago in candidatos {
                    pago.fechaCorteObjetivoPago = anterior.fechaCorte
                }
            }
        }
    }
}
