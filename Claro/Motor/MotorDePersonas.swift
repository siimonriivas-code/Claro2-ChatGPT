//
//  MotorDePersonas.swift
//  Claro — Carpeta: Motor
//
//  Ley 1 aplicada a personas: lo que te deben nunca se escribe a mano;
//  se calcula = sus partes en compras compartidas − cobros que te pagaron.
//

import Foundation

extension Movimiento {
    /// TU parte real de una compra: el total menos las partes ajenas.
    /// Si no es compartida, tu parte es el total.
    var montoPropio: Double {
        guard let compartida = compraCompartida else { return monto }
        let ajeno = compartida.participaciones.reduce(0) { $0 + $1.monto }
        return max(0, monto - ajeno)
    }
}

extension Persona {

    /// Suma de sus partes en compras compartidas (solo compras activas).
    var totalQueTeDebe: Double {
        participaciones
            .filter { $0.compra?.movimiento?.cuentaParaCalculos ?? false }
            .reduce(0) { $0 + $1.monto }
    }

    /// Parte de sus depósitos que se aplicó a compras compartidas.
    var totalAplicadoADeuda: Double {
        movimientos
            .filter { $0.cuentaParaCalculos && $0.tipo == .cobroRecibido }
            .reduce(0) { $0 + $1.monto }
    }

    /// Dinero adicional recibido de esta persona y registrado como ingreso.
    var totalExcedenteRecibido: Double {
        movimientos
            .filter { $0.cuentaParaCalculos && $0.tipo == .ingreso }
            .reduce(0) { $0 + $1.monto }
    }

    /// Todo lo recibido de la persona: deuda liquidada más excedentes.
    var totalQueTeHaPagado: Double {
        totalAplicadoADeuda + totalExcedenteRecibido
    }

    /// Lo que le falta pagarte HOY.
    var saldoPendiente: Double {
        max(0, totalQueTeDebe - totalAplicadoADeuda)
    }
}

struct DistribucionCobroPersona: Equatable {
    let aplicadoADeuda: Double
    let excedenteComoIngreso: Double
}

enum MotorDePersonas {
    static func distribuirCobro(monto: Double,
                                saldoPendiente: Double) -> DistribucionCobroPersona {
        let total = max(0, monto).redondeadoAMoneda
        let pendiente = max(0, saldoPendiente).redondeadoAMoneda
        let aplicado = min(total, pendiente).redondeadoAMoneda
        return DistribucionCobroPersona(
            aplicadoADeuda: aplicado,
            excedenteComoIngreso: max(0, total - aplicado).redondeadoAMoneda)
    }
}

// MARK: - Comprobante compartible

/// Construye el texto que la persona recibirá al compartirle un cobro.
/// El saldo sigue calculándose con la misma fuente de verdad de Personas:
/// participaciones activas menos cobros recibidos activos.
enum GeneradorResumenCobro {
    static func texto(para persona: Persona) -> String {
        let partes = persona.participaciones.filter {
            $0.compra?.movimiento?.cuentaParaCalculos ?? false
        }

        let introduccion = """
        Hola, \(persona.nombre).

        Te comparto el desglose de lo registrado en Claro para que puedas revisar qué conceptos integran el cobro:
        """

        guard !partes.isEmpty else {
            return """
            \(introduccion)

            No hay compras pendientes registradas a tu nombre.

            Total pendiente: \(dinero(0))
            """
        }

        // Las mensualidades de un mismo plan comparten el movimiento ancla.
        // Se agrupan para que el mensaje sea verificable sin repetir decenas
        // de veces el mismo comercio.
        let grupos = Dictionary(grouping: partes) {
            $0.compra!.movimiento!.id
        }
        let conceptos = grupos.values.compactMap { grupo -> ConceptoCobro? in
            guard let movimiento = grupo.first?.compra?.movimiento else {
                return nil
            }
            return ConceptoCobro(
                detalle: movimiento.detalle.trimmingCharacters(
                    in: .whitespacesAndNewlines).isEmpty
                    ? "Compra compartida"
                    : movimiento.detalle,
                fecha: movimiento.fecha,
                tarjeta: movimiento.tarjeta?.nombre,
                esMSI: movimiento.planMSI != nil,
                cantidadPartes: grupo.count,
                monto: grupo.reduce(0) { $0 + $1.monto })
        }
        .sorted {
            if $0.fecha == $1.fecha { return $0.detalle < $1.detalle }
            return $0.fecha < $1.fecha
        }

        let lineas = conceptos.enumerated().map { indice, concepto in
            var datos: [String] = [fecha(concepto.fecha)]
            if let tarjeta = concepto.tarjeta, !tarjeta.isEmpty {
                datos.append(tarjeta)
            }
            if concepto.esMSI {
                let descripcion = concepto.cantidadPartes == 1
                    ? "1 mensualidad MSI registrada"
                    : "\(concepto.cantidadPartes) mensualidades MSI registradas"
                datos.append(descripcion)
            }
            return "\(indice + 1). \(concepto.detalle)\n   \(datos.joined(separator: " · ")) — \(dinero(concepto.monto))"
        }
        .joined(separator: "\n")

        let compras = persona.totalQueTeDebe
        let pagos = persona.totalAplicadoADeuda
        let pendiente = max(0, persona.saldoPendiente)
        let estado = pendiente > 0
            ? "Total pendiente: \(dinero(pendiente))"
            : "Estado: cubierto. No tienes saldo pendiente."

        return """
        \(introduccion)

        \(lineas)

        Subtotal de tus partes: \(dinero(compras))
        Pagos ya registrados: −\(dinero(pagos))
        \(estado)

        Si algo no coincide, avísame para revisarlo antes del pago.
        """
    }

    private struct ConceptoCobro {
        let detalle: String
        let fecha: Date
        let tarjeta: String?
        let esMSI: Bool
        let cantidadPartes: Int
        let monto: Double
    }

    private static func dinero(_ monto: Double) -> String {
        let formato = NumberFormatter()
        formato.numberStyle = .currency
        formato.locale = Locale(identifier: "es_MX")
        formato.minimumFractionDigits = 2
        formato.maximumFractionDigits = 2
        return formato.string(from: NSNumber(value: monto.redondeadoAMoneda))
            ?? "$0.00"
    }

    private static func fecha(_ fecha: Date) -> String {
        let formato = DateFormatter()
        formato.locale = Locale(identifier: "es_MX")
        formato.dateFormat = "d MMM yyyy"
        return formato.string(from: fecha)
    }
}
