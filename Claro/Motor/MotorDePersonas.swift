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

/// Una línea pendiente del comprobante. La participación conserva el corte
/// que la generó mediante `importacionID`; así una mensualidad antigua jamás
/// vuelve a aparecer como si perteneciera al corte vigente.
private struct ConceptoPendientePersona {
    let clave: String
    let detalle: String
    let fecha: Date
    let tarjeta: String?
    let fechaCorte: Date?
    let etiquetaMSI: String?
    let clasificacion: ClasificacionCargoPersona
    var montoOriginal: Double
    var montoPendiente: Double
}

private enum ClasificacionCargoPersona: String {
    case corteVigente
    case saldoAnterior
    case otroExigible
    case sinCortar
}

private struct CargoPersona {
    let clave: String
    let detalle: String
    let fecha: Date
    let tarjeta: String?
    let fechaCorte: Date?
    let etiquetaMSI: String?
    let clasificacion: ClasificacionCargoPersona
    let monto: Double
    var pendiente: Double
}

struct ResumenCobroPersona {
    fileprivate let conceptos: [ConceptoPendientePersona]
    let cargosCorteVigente: Double
    let pendienteCorteVigente: Double
    let saldoAnteriorPendiente: Double
    let otrosPendientes: Double
    let comprasSinCortar: Double

    var totalAPagarAhora: Double {
        (
            pendienteCorteVigente
            + saldoAnteriorPendiente
            + otrosPendientes
        ).redondeadoAMoneda
    }
}

/// Construye el texto que la persona recibirá al compartirle un cobro.
/// Primero aplica todos los cobros registrados a los cargos más antiguos.
/// Después muestra el corte vigente, arrastra únicamente saldos anteriores
/// que de verdad continúan pendientes y deja las compras sin cortar fuera
/// del total exigible.
enum GeneradorResumenCobro {
    static func calcular(para persona: Persona) -> ResumenCobroPersona {
        var cargos = persona.participaciones.compactMap {
            cargo(para: $0)
        }
        .sorted {
            if $0.fecha == $1.fecha { return $0.clave < $1.clave }
            return $0.fecha < $1.fecha
        }

        // Los pagos recibidos no tenían una relación con cada compra en las
        // versiones anteriores. Se concilian con FIFO: primero se liquida lo
        // más antiguo y nunca se resucita en un comprobante posterior.
        var pagosDisponibles = persona.totalAplicadoADeuda
            .redondeadoAMoneda
        for indice in cargos.indices where pagosDisponibles > 0 {
            let aplicado = min(cargos[indice].pendiente, pagosDisponibles)
                .redondeadoAMoneda
            cargos[indice].pendiente =
                max(0, cargos[indice].pendiente - aplicado)
                    .redondeadoAMoneda
            pagosDisponibles =
                max(0, pagosDisponibles - aplicado).redondeadoAMoneda
        }

        let agrupados = agrupar(cargos)
        let cargosVigentes = cargos
            .filter { $0.clasificacion == .corteVigente }
            .reduce(0) { $0 + $1.monto }
            .redondeadoAMoneda

        func pendiente(_ clasificacion: ClasificacionCargoPersona) -> Double {
            cargos
                .filter { $0.clasificacion == clasificacion }
                .reduce(0) { $0 + $1.pendiente }
                .redondeadoAMoneda
        }

        return ResumenCobroPersona(
            conceptos: agrupados,
            cargosCorteVigente: cargosVigentes,
            pendienteCorteVigente: pendiente(.corteVigente),
            saldoAnteriorPendiente: pendiente(.saldoAnterior),
            otrosPendientes: pendiente(.otroExigible),
            comprasSinCortar: pendiente(.sinCortar)
        )
    }

    static func montoPendienteAlCorte(para persona: Persona) -> Double {
        calcular(para: persona).totalAPagarAhora
    }

    static func texto(para persona: Persona) -> String {
        let resumen = calcular(para: persona)
        var secciones: [String] = ["""
        Hola, \(persona.nombre).

        Te comparto únicamente lo pendiente de los cortes vigentes. Las compras de cortes ya liquidados no se vuelven a cobrar.
        """]

        agregarSeccion(
            titulo: "CORTES VIGENTES",
            clasificacion: .corteVigente,
            conceptos: resumen.conceptos,
            en: &secciones
        )
        agregarSeccion(
            titulo: "SALDO ANTERIOR REALMENTE PENDIENTE",
            clasificacion: .saldoAnterior,
            conceptos: resumen.conceptos,
            en: &secciones
        )
        agregarSeccion(
            titulo: "OTROS CARGOS PENDIENTES",
            clasificacion: .otroExigible,
            conceptos: resumen.conceptos,
            en: &secciones
        )

        if resumen.totalAPagarAhora == 0 {
            secciones.append(
                "Estado: cubierto. No tienes saldo pendiente al corte."
            )
        } else {
            var totales: [String] = []
            if resumen.cargosCorteVigente > 0 {
                totales.append(
                    "Cargos asignados en cortes vigentes: "
                    + dinero(resumen.cargosCorteVigente)
                )
                let aplicado = max(
                    0,
                    resumen.cargosCorteVigente
                        - resumen.pendienteCorteVigente
                ).redondeadoAMoneda
                if aplicado > 0 {
                    totales.append(
                        "Pagos aplicados a esos cargos: −"
                        + dinero(aplicado)
                    )
                }
            }
            if resumen.saldoAnteriorPendiente > 0 {
                totales.append(
                    "Saldo anterior pendiente: "
                    + dinero(resumen.saldoAnteriorPendiente)
                )
            }
            if resumen.otrosPendientes > 0 {
                totales.append(
                    "Otros cargos pendientes: "
                    + dinero(resumen.otrosPendientes)
                )
            }
            totales.append(
                "TOTAL A PAGAR AHORA: "
                + dinero(resumen.totalAPagarAhora)
            )
            secciones.append(totales.joined(separator: "\n"))
        }

        if resumen.comprasSinCortar > 0 {
            secciones.append(
                "Compras todavía sin cortar: "
                + dinero(resumen.comprasSinCortar)
                + "\nSon informativas y no están incluidas en el total a pagar ahora."
            )
        }

        secciones.append(
            "Si algo no coincide, avísame para revisarlo antes del pago."
        )
        return secciones.joined(separator: "\n\n")
    }

    private static func cargo(
        para parte: Participacion
    ) -> CargoPersona? {
        guard parte.monto > 0,
              let movimiento = parte.compra?.movimiento,
              movimiento.cuentaParaCalculos else { return nil }

        let estado = estadoAsociado(
            a: parte,
            movimiento: movimiento
        )
        let clasificacion: ClasificacionCargoPersona
        if let estado, let tarjeta = movimiento.tarjeta {
            if let vigente = tarjeta.estadoDeCuentaVigente,
               Calendar.current.isDate(
                   vigente.fechaCorte,
                   inSameDayAs: estado.fechaCorte
               ) {
                clasificacion = .corteVigente
            } else {
                clasificacion = .saldoAnterior
            }
        } else if movimiento.tarjeta != nil {
            clasificacion = .sinCortar
        } else {
            clasificacion = .otroExigible
        }

        let detalleLimpio = movimiento.detalle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let fechaReferencia = estado?.fechaCorte ?? movimiento.fecha
        return CargoPersona(
            clave: [
                String(describing: movimiento.id),
                estado.map {
                    String($0.fechaCorte.timeIntervalSinceReferenceDate)
                } ?? clasificacion.rawValue
            ].joined(separator: "|"),
            detalle: detalleLimpio.isEmpty
                ? "Compra compartida"
                : detalleLimpio,
            fecha: fechaReferencia,
            tarjeta: movimiento.tarjeta?.nombre,
            fechaCorte: estado?.fechaCorte,
            etiquetaMSI: etiquetaMSI(
                movimiento.planMSI,
                en: estado
            ),
            clasificacion: clasificacion,
            monto: parte.monto.redondeadoAMoneda,
            pendiente: parte.monto.redondeadoAMoneda
        )
    }

    private static func estadoAsociado(
        a parte: Participacion,
        movimiento: Movimiento
    ) -> EstadoDeCuenta? {
        guard let tarjeta = movimiento.tarjeta else { return nil }

        if let lote = parte.importacionID,
           let exacto = tarjeta.estadosDeCuenta.first(
               where: { $0.importacionID == lote }
           ) {
            return exacto
        }
        if let lote = movimiento.importacionID,
           let exacto = tarjeta.estadosDeCuenta.first(
               where: { $0.importacionID == lote }
           ) {
            return exacto
        }

        let calendario = Calendar.current
        return tarjeta.estadosDeCuenta
            .filter { estado in
                let fin = calendario.date(
                    byAdding: .day,
                    value: 1,
                    to: calendario.startOfDay(for: estado.finPeriodo)
                ) ?? estado.finPeriodo
                return movimiento.fecha >= estado.inicioPeriodo
                    && movimiento.fecha < fin
            }
            .max { $0.fechaCorte < $1.fechaCorte }
    }

    private static func etiquetaMSI(
        _ plan: PlanMSI?,
        en estado: EstadoDeCuenta?
    ) -> String? {
        guard let plan else { return nil }
        guard let estado,
              let mensualidad = plan.mensualidades.first(where: {
                  guard let corte = $0.estadoDeCuenta else { return false }
                  return Calendar.current.isDate(
                      corte.fechaCorte,
                      inSameDayAs: estado.fechaCorte
                  )
              }) else {
            return "MSI"
        }
        return "MSI \(mensualidad.numero)/\(plan.numeroMeses)"
    }

    private static func agrupar(
        _ cargos: [CargoPersona]
    ) -> [ConceptoPendientePersona] {
        var resultado: [ConceptoPendientePersona] = []
        var indices: [String: Int] = [:]

        for cargo in cargos {
            if let indice = indices[cargo.clave] {
                resultado[indice].montoOriginal += cargo.monto
                resultado[indice].montoPendiente += cargo.pendiente
                resultado[indice].montoOriginal =
                    resultado[indice].montoOriginal.redondeadoAMoneda
                resultado[indice].montoPendiente =
                    resultado[indice].montoPendiente.redondeadoAMoneda
            } else {
                indices[cargo.clave] = resultado.count
                resultado.append(ConceptoPendientePersona(
                    clave: cargo.clave,
                    detalle: cargo.detalle,
                    fecha: cargo.fecha,
                    tarjeta: cargo.tarjeta,
                    fechaCorte: cargo.fechaCorte,
                    etiquetaMSI: cargo.etiquetaMSI,
                    clasificacion: cargo.clasificacion,
                    montoOriginal: cargo.monto,
                    montoPendiente: cargo.pendiente
                ))
            }
        }
        return resultado.sorted {
            if $0.fecha == $1.fecha { return $0.detalle < $1.detalle }
            return $0.fecha < $1.fecha
        }
    }

    private static func agregarSeccion(
        titulo: String,
        clasificacion: ClasificacionCargoPersona,
        conceptos: [ConceptoPendientePersona],
        en secciones: inout [String]
    ) {
        let pendientes = conceptos.filter {
            $0.clasificacion == clasificacion && $0.montoPendiente > 0
        }
        guard !pendientes.isEmpty else { return }

        let lineas = pendientes.enumerated().map { indice, concepto in
            var datos: [String] = []
            if let tarjeta = concepto.tarjeta, !tarjeta.isEmpty {
                datos.append(tarjeta)
            }
            if let corte = concepto.fechaCorte {
                datos.append("corte " + fecha(corte))
            } else {
                datos.append(fecha(concepto.fecha))
            }
            if let etiqueta = concepto.etiquetaMSI {
                datos.append(etiqueta)
            }
            let importe: String
            if concepto.montoPendiente < concepto.montoOriginal {
                importe = dinero(concepto.montoPendiente)
                    + " pendiente de "
                    + dinero(concepto.montoOriginal)
            } else {
                importe = dinero(concepto.montoPendiente)
            }
            return "\(indice + 1). \(concepto.detalle)\n   \(datos.joined(separator: " · ")) — \(importe)"
        }
        .joined(separator: "\n")
        secciones.append("\(titulo)\n\(lineas)")
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
