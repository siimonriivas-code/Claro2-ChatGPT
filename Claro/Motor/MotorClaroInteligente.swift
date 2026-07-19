//
//  MotorClaroInteligente.swift
//  Claro
//
//  Las cuentas se hacen aquí, de forma determinista. El modelo de lenguaje
//  solo recibe resultados ya calculados para explicarlos con naturalidad.
//

import Foundation

enum NivelRiesgoFinanciero: String {
    case bajo = "Bajo"
    case moderado = "Moderado"
    case alto = "Alto"
    case critico = "Crítico"
}

struct DetalleCuentaClaro {
    let nombre: String
    let banco: String
    let tipo: String
    let saldo: Double
}

struct DetallePersonaClaro {
    let nombre: String
    let pendiente: Double
}

struct DetalleDeudaClaro {
    let acreedor: String
    let saldo: Double
    let tasaAnual: Double?
    let cat: Double?
    let mensualidad: Double?
}

struct DetalleTarjetaClaro {
    let nombre: String
    let deuda: Double
    let limite: Double
    let creditoDisponible: Double
    let saldoAlCorte: Double?
    let pagoParaNoGenerarIntereses: Double?
    let pagoMinimo: Double?
    let pagadoDelCorte: Double?
    let faltaCorte: Double
    let fechaCorte: Date?
    let fechaLimite: Date?
    let diasParaVencer: Int?
    let tasaAnual: Double?
    let cat: Double?
}

struct DetalleMovimientoClaro {
    let fecha: Date
    let tipo: String
    let detalle: String
    let monto: Double
    let cuenta: String?
    let cuentaDestino: String?
    let tarjeta: String?
    let categoria: String?
    let persona: String?

    var clave: String {
        "\(fecha.timeIntervalSinceReferenceDate)|\(tipo)|\(detalle)|\(monto)"
    }

    var textoParaModelo: String {
        var relaciones: [String] = []
        if let cuenta { relaciones.append("cuenta: \(cuenta)") }
        if let cuentaDestino { relaciones.append("destino: \(cuentaDestino)") }
        if let tarjeta { relaciones.append("tarjeta: \(tarjeta)") }
        if let categoria { relaciones.append("categoría: \(categoria)") }
        if let persona { relaciones.append("persona: \(persona)") }
        let conexiones = relaciones.isEmpty ? "" : "; " + relaciones.joined(separator: ", ")
        let concepto = detalle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "sin descripción" : detalle
        return "\(fecha.formatted(date: .abbreviated, time: .omitted)); \(tipo); "
            + "\(concepto); \(dinero(monto))\(conexiones)"
    }

    func relevancia(para consulta: String) -> Int {
        let base = [tipo, detalle, cuenta, cuentaDestino, tarjeta, categoria, persona]
            .compactMap { $0 }
            .joined(separator: " ")
        let texto = MotorClaroInteligente.normalizarParaBusqueda(base)
        let palabras = MotorClaroInteligente.palabrasSignificativas(consulta)
        return palabras.reduce(0) { parcial, palabra in
            parcial + (texto.contains(palabra) ? 1 : 0)
        }
    }
}

struct ResumenFinancieroClaro {
    let generadoEl: Date
    let saldoLiquido: Double
    let comprometidoTarjetas: Double
    let disponibleReal: Double
    let deudaTarjetas: Double
    let limiteTarjetas: Double
    let utilizacionCredito: Double?
    let deudasPersonales: Double
    let porCobrar: Double
    let patrimonio: Double

    let ingresoMesActual: Double
    let gastoMesActual: Double
    let ingresoMensualEstimado: Double
    let ingresosRecurrentesEsperados: Double
    let ingresosRecurrentesPendientes: Double
    let gastoMensualEstimado: Double
    let flujoMensualEstimado: Double
    let proyeccionFinDeMes: Double
    let pagosAntesDeFinDeMes: Double
    let pagosProximos30Dias: Double

    let cargaMinimaDeudaMensual: Double
    let capacidadMensualPrestamo: Double
    let mesesDeColchon: Double?
    let compromisoFuturoMSI: Double
    let compromisoMensualMSI: Double

    let estadosVencidos: Int
    let movimientosAnalizados: Int
    let mesesConHistoria: Int
    let usaEstimacionPorHistoriaCorta: Bool
    let nivelRiesgo: NivelRiesgoFinanciero
    let puntuacionRiesgo: Int
    let confianza: String
    let factoresRiesgo: [String]
    let fortalezas: [String]
    let categoriasPrincipales: [(nombre: String, monto: Double)]
    let cargosRecurrentes: [CargoRecurrenteDetectado]
    let detalleTarjetas: [DetalleTarjetaClaro]
    let detalleCuentas: [DetalleCuentaClaro]
    let detallePersonas: [DetallePersonaClaro]
    let detalleDeudas: [DetalleDeudaClaro]
    let detalleMovimientos: [DetalleMovimientoClaro]

    func contextoParaModelo(consulta: String) -> String {
        let uso = utilizacionCredito.map { porcentaje($0) } ?? "sin límite registrado"
        let colchon = mesesDeColchon.map { String(format: "%.1f meses", $0) }
            ?? "no calculable por falta de gasto histórico"
        let tarjetasTexto = detalleTarjetas.isEmpty ? "ninguna" : detalleTarjetas.map {
            let vencimiento = $0.diasParaVencer.map { "\($0) días" }
                ?? "sin corte vigente"
            let datosCorte: String
            if let saldo = $0.saldoAlCorte,
               let pngi = $0.pagoParaNoGenerarIntereses,
               let minimo = $0.pagoMinimo,
               let pagado = $0.pagadoDelCorte,
               let fechaCorte = $0.fechaCorte,
               let fechaLimite = $0.fechaLimite {
                datosCorte = "; saldo al corte \(dinero(saldo)); PNGI \(dinero(pngi)); "
                    + "pago mínimo \(dinero(minimo)); pagado \(dinero(pagado)); "
                    + "fecha de corte \(fechaCorte.formatted(date: .abbreviated, time: .omitted)); "
                    + "fecha límite \(fechaLimite.formatted(date: .abbreviated, time: .omitted))"
            } else {
                datosCorte = "; sin estado de cuenta vigente"
            }
            let costo = $0.cat.map { "; CAT \($0)%" } ?? $0.tasaAnual.map { "; tasa anual \($0)%" } ?? ""
            return "\($0.nombre): deuda \(dinero($0.deuda)); límite \(dinero($0.limite)); "
                + "crédito disponible \(dinero($0.creditoDisponible)); falta del corte "
                + "\(dinero($0.faltaCorte)); vencimiento \(vencimiento)\(datosCorte)\(costo)"
        }.joined(separator: " | ")
        let categorias = categoriasPrincipales.isEmpty ? "sin datos" : categoriasPrincipales
            .map { "\($0.nombre) \(dinero($0.monto))" }.joined(separator: ", ")
        let recurrentes = cargosRecurrentes.isEmpty ? "ninguno detectado" : cargosRecurrentes
            .prefix(6).map { "\($0.comercio) ~\(dinero($0.promedio))/mes" }
            .joined(separator: ", ")
        let cuentasTexto = detalleCuentas.isEmpty ? "ninguna" : detalleCuentas.map {
            "\($0.nombre) (\($0.banco), \($0.tipo)): \(dinero($0.saldo))"
        }.joined(separator: " | ")
        let personasTexto = detallePersonas.isEmpty ? "ninguna" : detallePersonas.map {
            "\($0.nombre): \(dinero($0.pendiente)) pendiente"
        }.joined(separator: " | ")
        let deudasTexto = detalleDeudas.isEmpty ? "ninguna" : detalleDeudas.map {
            "\($0.acreedor): \(dinero($0.saldo)) restante" + ($0.cat.map { "; CAT \($0)%" } ?? $0.tasaAnual.map { "; tasa anual \($0)%" } ?? "")
        }.joined(separator: " | ")
        let movimientos = movimientosParaModelo(consulta: consulta)
        let movimientosTexto = movimientos.isEmpty ? "ninguno" : movimientos
            .map { String($0.textoParaModelo.prefix(320)) }
            .joined(separator: "\n- ")
        let riesgos = factoresRiesgo.isEmpty ? "ninguno relevante" : factoresRiesgo.joined(separator: " | ")
        let positivos = fortalezas.isEmpty ? "ninguno comprobable" : fortalezas.joined(separator: " | ")

        let contexto = """
        FECHA DEL ANÁLISIS: \(generadoEl.formatted(date: .long, time: .shortened))
        LIQUIDEZ: cuentas \(dinero(saldoLiquido)); comprometido en cortes \(dinero(comprometidoTarjetas)); disponible real \(dinero(disponibleReal)).
        DEUDAS: tarjetas \(dinero(deudaTarjetas)); utilización \(uso); otras deudas \(dinero(deudasPersonales)); por cobrar \(dinero(porCobrar)).
        PATRIMONIO ESTIMADO: \(dinero(patrimonio)).
        MES ACTUAL: ingresos registrados \(dinero(ingresoMesActual)); gastos de consumo \(dinero(gastoMesActual)).
        RITMO MENSUAL ESTIMADO: ingresos \(dinero(ingresoMensualEstimado)); gastos \(dinero(gastoMensualEstimado)); flujo \(dinero(flujoMensualEstimado)).
        INGRESOS HABITUALES: esperados este mes \(dinero(ingresosRecurrentesEsperados)); aún pendientes de llegar \(dinero(ingresosRecurrentesPendientes)).
        PROYECCIÓN CONSERVADORA DE EFECTIVO AL FIN DE MES: \(dinero(proyeccionFinDeMes)); pagos de tarjetas antes de fin de mes \(dinero(pagosAntesDeFinDeMes)); pagos en próximos 30 días \(dinero(pagosProximos30Dias)).
        CAPACIDAD INDICATIVA PARA UNA NUEVA MENSUALIDAD: hasta \(dinero(capacidadMensualPrestamo)); carga mínima mensual de deuda actual \(dinero(cargaMinimaDeudaMensual)); colchón líquido \(colchon).
        MSI: compromiso futuro total \(dinero(compromisoFuturoMSI)); mensualidad futura aproximada \(dinero(compromisoMensualMSI)).
        RIESGO: \(nivelRiesgo.rawValue) (\(puntuacionRiesgo)/100); cortes vencidos \(estadosVencidos); confianza \(confianza).
        FACTORES DE RIESGO: \(riesgos).
        FORTALEZAS: \(positivos).
        CUENTAS BANCARIAS: \(cuentasTexto).
        TARJETAS: \(tarjetasTexto).
        PERSONAS QUE TE DEBEN: \(personasTexto).
        OTRAS DEUDAS PROPIAS: \(deudasTexto).
        MAYORES CATEGORÍAS DEL MES: \(categorias).
        CARGOS RECURRENTES: \(recurrentes).
        COBERTURA DE DATOS: \(movimientosAnalizados) movimientos; \(mesesConHistoria) meses con historia; estimación por historia corta: \(usaEstimacionPorHistoriaCorta ? "sí" : "no").
        MOVIMIENTOS RELEVANTES Y RECIENTES (selección local de \(movimientos.count) de \(detalleMovimientos.count)):
        - \(movimientosTexto)
        """
        // Solo se conservan líneas completas: una cifra o fecha nunca queda
        // cortada a la mitad. El límite final por tokens se verifica de nuevo
        // con el tokenizador real de Qwen justo antes del prefill.
        let maximoCaracteres = 12_000
        var lineasSeguras: [String] = []
        var usados = 0
        for linea in contexto.split(separator: "\n", omittingEmptySubsequences: false) {
            let texto = String(linea)
            let costo = texto.count + (lineasSeguras.isEmpty ? 0 : 1)
            guard usados + costo <= maximoCaracteres else { break }
            lineasSeguras.append(texto)
            usados += costo
        }
        if lineasSeguras.count < contexto.split(
            separator: "\n", omittingEmptySubsequences: false).count {
            lineasSeguras.append(
                "[Se omitieron movimientos secundarios por límite de memoria]")
        }
        return lineasSeguras.joined(separator: "\n")
    }

    private func movimientosParaModelo(consulta: String) -> [DetalleMovimientoClaro] {
        let ordenados = detalleMovimientos.sorted { $0.fecha > $1.fecha }
        let relacionados = ordenados
            .map { ($0, $0.relevancia(para: consulta)) }
            .filter { $0.1 > 0 }
            .sorted {
                if $0.1 == $1.1 { return $0.0.fecha > $1.0.fecha }
                return $0.1 > $1.1
            }
            .prefix(14)
            .map(\.0)

        var resultado: [DetalleMovimientoClaro] = []
        var claves: Set<String> = []
        for movimiento in relacionados + Array(ordenados.prefix(10)) {
            if claves.insert(movimiento.clave).inserted {
                resultado.append(movimiento)
            }
            if resultado.count == 20 { break }
        }
        return resultado.sorted { $0.fecha > $1.fecha }
    }
}

enum MotorClaroInteligente {

    static func resumir(cuentas: [CuentaBancaria],
                        tarjetas: [TarjetaCredito],
                        personas: [Persona],
                        planes: [PlanMSI],
                        deudas: [Deuda],
                        movimientos: [Movimiento],
                        ingresosRecurrentes: [IngresoRecurrente] = [],
                        ocurrenciasIngreso: [OcurrenciaIngresoRecurrente] = [],
                        ahora: Date = .now) -> ResumenFinancieroClaro {
        let calendario = Calendar.current
        let activos = movimientos.filter { $0.cuentaParaCalculos && $0.fecha <= ahora }
        let inicioMes = calendario.dateInterval(of: .month, for: ahora)?.start ?? ahora
        let finMes = calendario.dateInterval(of: .month, for: ahora)?.end ?? ahora
        let delMes = activos.filter { $0.fecha >= inicioMes && $0.fecha < finMes }

        let ingresoMes = delMes.filter { $0.tipo == .ingreso }
            .reduce(0) { $0 + $1.monto }
        let gastoMes = delMes.filter { $0.tipo == .gasto || $0.tipo == .compraCredito }
            .reduce(0) { $0 + $1.montoPropio }
        let gastoEfectivoMes = delMes.filter { $0.tipo == .gasto }
            .reduce(0) { $0 + $1.montoPropio }

        let historico = promediosHistoricos(movimientos: activos, ahora: ahora)
        let proporcionMes = max(0.25, proporcionTranscurridaDelMes(ahora, calendario: calendario))
        let historiaCorta = historico.meses == 0
        let recurrentesActivos = ingresosRecurrentes.filter(\.activo)
        let esperadoRecurrente = recurrentesActivos.reduce(0) { $0 + $1.montoEsperado }
        let recibidosExplicitos = ocurrenciasIngreso.filter {
            $0.estado == .recibido && calendario.isDate($0.mes, equalTo: ahora, toGranularity: .month)
        }
        let pendientesRecurrentes = recurrentesActivos.filter { ingreso in
            let explicito = recibidosExplicitos.contains { $0.ingreso === ingreso }
            let inferido = delMes.contains { movimiento in
                movimiento.tipo == .ingreso && normalizarParaBusqueda(movimiento.detalle)
                    .contains(normalizarParaBusqueda(ingreso.nombre))
            }
            return !explicito && !inferido
        }.reduce(0) { $0 + $1.montoEsperado }
        let estimacionBase = historiaCorta ? ingresoMes / proporcionMes : historico.ingresos
        let ingresoEstimado = max(estimacionBase, ingresoMes + pendientesRecurrentes)
        let gastoEstimado = historiaCorta ? gastoMes / proporcionMes : historico.gastos
        let gastoEfectivoEstimado = historiaCorta
            ? gastoEfectivoMes / proporcionMes : historico.gastosEfectivo

        // Todas las cifras de esta fotografía respetan `ahora`. Las
        // propiedades generales de los modelos representan el presente real
        // y, por diseño, incluyen cualquier movimiento activo; usarlas aquí
        // hacía que una operación futura alterara una consulta histórica.
        let saldosCuenta = cuentas.map { saldoDeCuenta($0, hasta: ahora) }
        let deudasTarjeta = tarjetas.map { deudaDeTarjeta($0, hasta: ahora) }
        let cortesCalculados = tarjetas.compactMap {
            corteCalculado(de: $0, hasta: ahora)
        }
        let saldosPersonas = personas.map { saldoDePersona($0, hasta: ahora) }
        let saldosDeudas = deudas.map { saldoDeDeuda($0, hasta: ahora) }

        let saldoLiquido = saldosCuenta.reduce(0, +)
        let comprometido = cortesCalculados.reduce(0) { $0 + $1.falta }
        let disponible = saldoLiquido - comprometido
        let deudaTarjetas = deudasTarjeta.reduce(0) { $0 + max(0, $1) }
        let limiteTarjetas = tarjetas.reduce(0) { $0 + max(0, $1.limiteCredito) }
        let utilizacion = limiteTarjetas > 0 ? deudaTarjetas / limiteTarjetas : nil
        let otrasDeudas = saldosDeudas.reduce(0) { $0 + max(0, $1) }
        let porCobrar = saldosPersonas.reduce(0) { $0 + max(0, $1) }
        let patrimonio = saldoLiquido + porCobrar - deudaTarjetas - otrasDeudas

        let pendientes = cortesCalculados.filter { $0.falta > 0 }
        let finMesInclusivo = finMes.addingTimeInterval(-1)
        // Un corte vencido sigue siendo una salida inmediata hasta que exista
        // un pago real. Excluir fechas pasadas hacía que el chat pudiera
        // reportar liquidez negativa y, al mismo tiempo, un colchón ficticio.
        let pagosFinMes = pendientes.filter {
            $0.estado.fechaLimitePago <= finMesInclusivo
        }.reduce(0) { $0 + $1.falta }
        let limite30 = calendario.date(byAdding: .day, value: 30, to: ahora) ?? ahora
        let pagos30 = pendientes.filter {
            $0.estado.fechaLimitePago <= limite30
        }.reduce(0) { $0 + $1.falta }
        let vencidos = pendientes.filter { $0.vencido }.count
        let cargaMinima = cortesCalculados.reduce(0) {
            $0 + ($1.falta <= 0 ? 0 : max(0, $1.estado.pagoMinimo - $1.pagado))
        }

        let ingresoRestante = max(pendientesRecurrentes, max(0, ingresoEstimado - ingresoMes))
        let gastoEfectivoRestante = max(0, gastoEfectivoEstimado - gastoEfectivoMes)
        let proyeccion = saldoLiquido + ingresoRestante - gastoEfectivoRestante - pagosFinMes

        let planesActivos = planes.filter { !$0.estaConcluidoReal }
        let futuroMSI = planesActivos.reduce(0) { $0 + $1.compromisoFuturo }
        let mensualMSI = planesActivos.reduce(0) {
            $0 + ($1.siguientePendienteDeGenerar?.monto ?? 0)
        }
        let flujo = ingresoEstimado - gastoEstimado
        let espacioPorFlujo = max(0, flujo) * 0.60
        let espacioPorIngreso = max(0, ingresoEstimado * 0.30 - cargaMinima)
        let capacidad = min(espacioPorFlujo, espacioPorIngreso)
        let colchon = gastoEstimado > 0
            ? max(0, saldoLiquido - pagos30) / gastoEstimado : nil

        let evaluacion = evaluarRiesgo(
            ingreso: ingresoEstimado,
            gasto: gastoEstimado,
            disponible: disponible,
            proyeccion: proyeccion,
            deuda: deudaTarjetas + otrasDeudas,
            patrimonio: patrimonio,
            utilizacion: utilizacion,
            cargaMinima: cargaMinima,
            colchon: colchon,
            vencidos: vencidos)

        let categorias = categoriasPrincipales(movimientos: delMes)
        let recurrentes = MotorPredictivo.recurrentes(movimientos: activos)
        let meses = max(historico.meses, activos.isEmpty ? 0 : 1)
        let confianza: String
        if activos.count >= 40 && meses >= 3 { confianza = "alta" }
        else if activos.count >= 10 || meses >= 2 { confianza = "media" }
        else { confianza = "inicial" }

        let detalleTarjetas = tarjetas.enumerated().map { indice, tarjeta in
            let corte = cortesCalculados.first { $0.tarjeta === tarjeta }
            let deuda = max(0, deudasTarjeta[indice])
            return DetalleTarjetaClaro(
                nombre: tarjeta.nombre,
                deuda: deuda,
                limite: max(0, tarjeta.limiteCredito),
                creditoDisponible: max(0, tarjeta.limiteCredito - deuda),
                saldoAlCorte: corte?.estado.saldoAlCorte,
                pagoParaNoGenerarIntereses:
                    corte?.estado.pagoParaNoGenerarIntereses,
                pagoMinimo: corte?.estado.pagoMinimo,
                pagadoDelCorte: corte?.pagado,
                faltaCorte: corte?.falta ?? 0,
                fechaCorte: corte?.estado.fechaCorte,
                fechaLimite: corte?.estado.fechaLimitePago,
                diasParaVencer: corte?.dias,
                tasaAnual: tarjeta.tasaAnual,
                cat: tarjeta.cat)
        }
        let detalleCuentas = cuentas.enumerated().map { indice, cuenta in
            DetalleCuentaClaro(
                nombre: cuenta.nombre,
                banco: cuenta.banco?.nombre ?? "sin banco indicado",
                tipo: cuenta.tipo.rawValue,
                saldo: saldosCuenta[indice])
        }
        // Un cobro mayor a lo compartido no significa que la persona tenga
        // una "deuda negativa". Para el análisis por cobrar, el piso es cero.
        let detallePersonas = personas.enumerated().map { indice, persona in
            DetallePersonaClaro(nombre: persona.nombre,
                                pendiente: max(0, saldosPersonas[indice]))
        }
        let detalleDeudas = deudas.enumerated().map { indice, deuda in
            DetalleDeudaClaro(acreedor: deuda.acreedor,
                              saldo: saldosDeudas[indice],
                              tasaAnual: deuda.tasaAnual,
                              cat: deuda.cat,
                              mensualidad: deuda.mensualidad)
        }
        let detalleMovimientos = activos.map {
            DetalleMovimientoClaro(
                fecha: $0.fecha,
                tipo: $0.tipo.rawValue,
                detalle: $0.detalle,
                monto: $0.monto,
                cuenta: $0.cuenta?.nombre,
                cuentaDestino: $0.cuentaDestino?.nombre,
                tarjeta: $0.tarjeta?.nombre,
                categoria: $0.categoria?.nombre,
                persona: $0.persona?.nombre)
        }

        return ResumenFinancieroClaro(
            generadoEl: ahora,
            saldoLiquido: saldoLiquido,
            comprometidoTarjetas: comprometido,
            disponibleReal: disponible,
            deudaTarjetas: deudaTarjetas,
            limiteTarjetas: limiteTarjetas,
            utilizacionCredito: utilizacion,
            deudasPersonales: otrasDeudas,
            porCobrar: porCobrar,
            patrimonio: patrimonio,
            ingresoMesActual: ingresoMes,
            gastoMesActual: gastoMes,
            ingresoMensualEstimado: ingresoEstimado,
            ingresosRecurrentesEsperados: esperadoRecurrente,
            ingresosRecurrentesPendientes: pendientesRecurrentes,
            gastoMensualEstimado: gastoEstimado,
            flujoMensualEstimado: flujo,
            proyeccionFinDeMes: proyeccion,
            pagosAntesDeFinDeMes: pagosFinMes,
            pagosProximos30Dias: pagos30,
            cargaMinimaDeudaMensual: cargaMinima,
            capacidadMensualPrestamo: capacidad,
            mesesDeColchon: colchon,
            compromisoFuturoMSI: futuroMSI,
            compromisoMensualMSI: mensualMSI,
            estadosVencidos: vencidos,
            movimientosAnalizados: activos.count,
            mesesConHistoria: meses,
            usaEstimacionPorHistoriaCorta: historiaCorta,
            nivelRiesgo: evaluacion.nivel,
            puntuacionRiesgo: evaluacion.puntos,
            confianza: confianza,
            factoresRiesgo: evaluacion.riesgos,
            fortalezas: evaluacion.fortalezas,
            categoriasPrincipales: categorias,
            cargosRecurrentes: recurrentes,
            detalleTarjetas: detalleTarjetas,
            detalleCuentas: detalleCuentas,
            detallePersonas: detallePersonas,
            detalleDeudas: detalleDeudas,
            detalleMovimientos: detalleMovimientos)
    }

    private struct CorteCalculadoClaro {
        let tarjeta: TarjetaCredito
        let estado: EstadoDeCuenta
        let pagado: Double
        let falta: Double
        let dias: Int
        let vencido: Bool
    }

    private static func saldoDeCuenta(
        _ cuenta: CuentaBancaria, hasta fecha: Date
    ) -> Double {
        var saldo = cuenta.fechaSaldoInicial <= fecha ? cuenta.saldoInicial : 0
        for movimiento in cuenta.movimientos
            where movimiento.cuentaParaCalculos && movimiento.fecha <= fecha {
            switch movimiento.tipo {
            case .ingreso, .cobroRecibido, .bonificacion:
                saldo += movimiento.monto
            case .gasto, .pagoTarjeta, .transferencia, .abonoDeuda:
                saldo -= movimiento.monto
            case .ajuste:
                saldo += movimiento.monto
            case .compraCredito:
                break
            }
        }
        for movimiento in cuenta.movimientosEntrantes
            where movimiento.cuentaParaCalculos
                && movimiento.tipo == .transferencia
                && movimiento.fecha <= fecha {
            saldo += movimiento.monto
        }
        return saldo
    }

    private static func deudaDeTarjeta(
        _ tarjeta: TarjetaCredito, hasta fecha: Date
    ) -> Double {
        var deuda = tarjeta.fechaSaldoInicial <= fecha ? tarjeta.saldoInicial : 0
        for movimiento in tarjeta.movimientos
            where movimiento.cuentaParaCalculos && movimiento.fecha <= fecha {
            switch movimiento.tipo {
            case .compraCredito:
                deuda += movimiento.monto
            case .pagoTarjeta, .bonificacion:
                deuda -= movimiento.monto
            case .ajuste:
                deuda += movimiento.monto
            default:
                break
            }
        }
        return deuda
    }

    private static func saldoDePersona(
        _ persona: Persona, hasta fecha: Date
    ) -> Double {
        let compartido = persona.participaciones
            .filter {
                guard let movimiento = $0.compra?.movimiento else { return false }
                return movimiento.cuentaParaCalculos && movimiento.fecha <= fecha
            }
            .reduce(0) { $0 + $1.monto }
        let pagado = persona.movimientos
            .filter {
                $0.cuentaParaCalculos && $0.tipo == .cobroRecibido
                    && $0.fecha <= fecha
            }
            .reduce(0) { $0 + $1.monto }
        return compartido - pagado
    }

    private static func saldoDeDeuda(
        _ deuda: Deuda, hasta fecha: Date
    ) -> Double {
        guard deuda.fecha <= fecha else { return 0 }
        let abonado = deuda.abonos
            .filter {
                $0.cuentaParaCalculos && $0.tipo == .abonoDeuda
                    && $0.fecha <= fecha
            }
            .reduce(0) { $0 + $1.monto }
        return max(0, deuda.montoOriginal - abonado)
    }

    private static func corteCalculado(
        de tarjeta: TarjetaCredito, hasta ahora: Date
    ) -> CorteCalculadoClaro? {
        guard let estado = tarjeta.estadosDeCuenta
            .filter({ $0.fechaCorte <= ahora })
            .max(by: { $0.fechaCorte < $1.fechaCorte }) else { return nil }
        // Para el corte vigente, un pago tardío sí reduce lo pendiente. El
        // límite sirve para medir puntualidad, no para crear deuda fantasma.
        let pagado = tarjeta.movimientos
            .filter {
                $0.cuentaParaCalculos && $0.tipo == .pagoTarjeta
                    && $0.fecha >= estado.fechaCorte && $0.fecha <= ahora
            }
            .reduce(0) { $0 + $1.monto }
        let falta = max(0, estado.pagoParaNoGenerarIntereses - pagado)
        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: ahora)
        let limite = calendario.startOfDay(for: estado.fechaLimitePago)
        let dias = calendario.dateComponents([.day], from: hoy, to: limite).day ?? 0
        return CorteCalculadoClaro(
            tarjeta: tarjeta,
            estado: estado,
            pagado: pagado,
            falta: falta,
            dias: dias,
            vencido: falta > 0 && hoy > limite)
    }

    static func responderConReglas(
        intencion: IntencionConsultaClaro,
        pregunta: String,
        resumen: ResumenFinancieroClaro
    ) -> String {
        if let exacta = respuestaFactualExacta(
            intencion: intencion, pregunta: pregunta, resumen: resumen) {
            return exacta
        }
        switch intencion.metrica {
        case .prestamo:
            return respuestaPrestamo(pregunta: pregunta, resumen: resumen)
        case .riesgo:
            return respuestaRiesgo(resumen)
        case .proyeccionFinDeMes:
            return respuestaProyeccion(resumen)
        case .gastos:
            return respuestaGasto(resumen)
        case .deudaTarjeta, .deudaTotalTarjetas, .prioridadDePago,
             .mayorDeudaTarjeta, .menorDeudaTarjeta:
            return respuestaDeuda(resumen)
        case .panorama:
            return respuestaPanorama(resumen)
        case .desconocida:
            return intencion.esEspecifica
                ? "Entendí que pides un dato concreto, pero no encuentro ese dato registrado con suficiente precisión."
                : "No pude producir una respuesta financiera confiable para esa pregunta; no sustituiré tu pregunta por un panorama distinto."
        default:
            return "Ese dato no está disponible con suficiente precisión en el resumen actual; prefiero no inventarlo."
        }
    }

    static func normalizarParaBusqueda(_ texto: String) -> String {
        texto
            .folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "es_MX"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func palabrasSignificativas(_ texto: String) -> [String] {
        let omitidas: Set<String> = [
            "como", "cual", "cuales", "cuanto", "cuanta", "cuantos", "cuantas",
            "donde", "cuando", "porque", "para", "pero", "esta", "este", "estos",
            "estas", "tengo", "tiene", "tienen", "quiero", "puedo", "debo", "debes",
            "dime", "saber", "sobre", "entre", "desde", "hasta", "hacia", "todo",
            "todos", "todas", "algo", "solo", "tambien", "mucho", "poco", "mas",
            "menos", "mis", "con", "sin", "por", "del", "las", "los", "una", "uno",
            "unos", "unas", "que", "hay", "fue", "son"
        ]
        return normalizarParaBusqueda(texto)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 3 && !omitidas.contains($0) }
    }

    /// Respuestas que deben salir directamente de Swift, no de una IA.
    /// Evita que una comparación exacta se convierta en una explicación
    /// genérica o que el modelo omita el nombre de la tarjeta solicitada.
    static func respuestaFactualExacta(
        intencion: IntencionConsultaClaro,
        pregunta: String,
        resumen r: ResumenFinancieroClaro
    ) -> String? {
        guard intencion.ambito == .finanzasPersonales else { return nil }
        if intencion.metricasSolicitadas.count > 1,
           let compuesta = respuestaFactualCompuesta(
            intencion: intencion, resumen: r) {
            return compuesta
        }
        let texto = normalizarConsulta(pregunta)
        let tarjetasConDeuda = r.detalleTarjetas
            .filter { $0.deuda > 0 }
            .sorted { $0.deuda > $1.deuda }

        if intencion.metrica == .mayorDeudaTarjeta {
            guard let mayor = tarjetasConDeuda.first else {
                return "No hay deuda positiva registrada en tus tarjetas."
            }
            var respuesta = """
            ## Respuesta
            La tarjeta en la que más debes es **\(mayor.nombre)**, con **\(dinero(mayor.deuda))** de deuda registrada.
            """
            if tarjetasConDeuda.count > 1 {
                respuesta += "\n\n## Comparación\n"
                for tarjeta in tarjetasConDeuda.prefix(5) {
                    respuesta += "\n- **\(tarjeta.nombre):** \(dinero(tarjeta.deuda))"
                }
            }
            if mayor.faltaCorte > 0 {
                respuesta += "\n\nDe su corte vigente faltan **\(dinero(mayor.faltaCorte))** por cubrir."
            }
            return respuesta
        }

        if intencion.metrica == .menorDeudaTarjeta {
            guard let menor = r.detalleTarjetas.min(by: { $0.deuda < $1.deuda }) else {
                return "No hay tarjetas registradas."
            }
            return "La tarjeta con menor deuda es **\(menor.nombre)**, con **\(dinero(menor.deuda))**."
        }

        if intencion.metrica == .prioridadDePago {
            let pendientes = r.detalleTarjetas
                .filter { $0.faltaCorte > 0 }
                .sorted { izquierda, derecha in
                    let diasIzquierda = izquierda.diasParaVencer ?? Int.max
                    let diasDerecha = derecha.diasParaVencer ?? Int.max
                    if diasIzquierda == diasDerecha {
                        let costoIzquierda = izquierda.cat ?? izquierda.tasaAnual ?? 0
                        let costoDerecha = derecha.cat ?? derecha.tasaAnual ?? 0
                        if costoIzquierda != costoDerecha { return costoIzquierda > costoDerecha }
                        return izquierda.faltaCorte > derecha.faltaCorte
                    }
                    return diasIzquierda < diasDerecha
                }
            guard let primera = pendientes.first else {
                return "No encuentro cortes pendientes que permitan elegir una tarjeta prioritaria."
            }
            let situacion: String
            if let dias = primera.diasParaVencer {
                situacion = dias < 0
                    ? "está vencida por \(abs(dias)) día(s)"
                    : dias == 0 ? "vence hoy" : "vence en \(dias) día(s)"
            } else {
                situacion = "no tiene fecha vigente disponible"
            }
            return "La primera prioridad es **\(primera.nombre)**: faltan **\(dinero(primera.faltaCorte))** por cubrir y \(situacion)."
        }

        if intencion.metrica == .deudaTotalTarjetas {
            return "Tu deuda total registrada en tarjetas es **\(dinero(r.deudaTarjetas))**."
        }

        if intencion.metrica == .disponibleReal {
            return "Tienes **\(dinero(r.disponibleReal))** disponibles después de apartar los cortes vigentes."
        }
        if intencion.metrica == .patrimonio {
            return "Tu patrimonio estimado con los registros actuales es **\(dinero(r.patrimonio))**."
        }
        if intencion.metrica == .ingresos {
            if let respuestaPorOrigen = respuestaExactaDeIngresos(
                pregunta: texto, intencion: intencion, resumen: r) {
                return respuestaPorOrigen
            }
            return "Este mes tienes **\(dinero(r.ingresoMesActual))** de ingresos registrados."
        }
        if intencion.metrica == .gastos, intencion.entidades.isEmpty,
           texto.contains("cuanto") {
            if let categoria = r.categoriasPrincipales.first(where: {
                contieneNombreCompleto($0.nombre, en: texto)
            }) {
                return "Este mes gastaste **\(dinero(categoria.monto))** en **\(categoria.nombre)**."
            }
            if !texto.contains(" en ") {
                return "Este mes tienes **\(dinero(r.gastoMesActual))** de gastos de consumo registrados."
            }
        }

        if intencion.metrica == .limiteCredito,
           intencion.pideComparacion,
           entidades(intencion, tipo: .tarjeta).isEmpty,
           let mayor = r.detalleTarjetas.max(by: { $0.limite < $1.limite }) {
            return "La tarjeta con el límite más alto es **\(mayor.nombre)**, con **\(dinero(mayor.limite))**."
        }

        var tarjetas = tarjetasReferidas(intencion, resumen: r)
        if tarjetas.isEmpty,
           intencion.metrica == .deudaTarjeta,
           (intencion.pideComparacion || texto.contains("mis tarjetas")) {
            tarjetas = r.detalleTarjetas.sorted { $0.deuda > $1.deuda }
        }
        if esMetricaDeTarjeta(intencion.metrica), !tarjetas.isEmpty {
            if tarjetas.count > 1,
               !intencion.pideTotal,
               !tarjetas.allSatisfy({ contieneNombreCompleto($0.nombre, en: texto) }) {
                let nombres = tarjetas.map(\.nombre).joined(separator: ", ")
                return "Encontré varias tarjetas que coinciden: **\(nombres)**. Escribe el nombre completo de la que quieres consultar."
            }
            return respuestaExactaDeTarjetas(
                tarjetas, metrica: intencion.metrica,
                sumar: intencion.pideTotal)
        }

        var personas = entidades(intencion, tipo: .persona).compactMap { referencia in
            r.detallePersonas.first { $0.nombre == referencia.nombre }
        }
        if intencion.metrica == .porCobrarPersona {
            if personas.isEmpty { personas = r.detallePersonas }
            personas = personas.filter { $0.pendiente > 0 }
            if intencion.pideComparacion || texto.contains("quien me debe mas") {
                guard let mayor = personas.max(by: { $0.pendiente < $1.pendiente }) else {
                    return "No hay saldos por cobrar registrados."
                }
                return "Quien más te debe es **\(mayor.nombre)**, con **\(dinero(mayor.pendiente))** pendiente."
            }
            guard !personas.isEmpty else {
                return "No hay saldos por cobrar registrados."
            }
            var lineas = personas.map {
                "- **\($0.nombre):** te debe \(dinero($0.pendiente))"
            }
            if personas.count > 1 || intencion.pideTotal {
                lineas.append("- **Total:** \(dinero(personas.reduce(0) { $0 + $1.pendiente }))")
            }
            return lineas.joined(separator: "\n")
        }

        let acreedores = entidades(intencion, tipo: .acreedor).compactMap { referencia in
            r.detalleDeudas.first { $0.acreedor == referencia.nombre }
        }
        if intencion.metrica == .deudaConAcreedor, !acreedores.isEmpty {
            var lineas = acreedores.map {
                "- A **\($0.acreedor)** le debes \(dinero($0.saldo))"
            }
            if acreedores.count > 1 {
                lineas.append("- **Total:** \(dinero(acreedores.reduce(0) { $0 + $1.saldo }))")
            }
            return lineas.joined(separator: "\n")
        }

        var cuentas = entidades(intencion, tipo: .cuenta).compactMap { referencia in
            r.detalleCuentas.first { $0.nombre == referencia.nombre }
        }
        if intencion.metrica == .saldoCuenta {
            if cuentas.isEmpty { cuentas = r.detalleCuentas }
            guard !cuentas.isEmpty else {
                return "No hay cuentas bancarias registradas."
            }
            var lineas = cuentas.map {
                "- **\($0.nombre):** \(dinero($0.saldo))"
            }
            if cuentas.count > 1 {
                lineas.append("- **Total:** \(dinero(cuentas.reduce(0) { $0 + $1.saldo }))")
            }
            return lineas.joined(separator: "\n")
        }

        // "¿Cuál es la deuda de Alondra?" no define quién debe a quién.
        if intencion.metrica == .deudaTarjeta,
           intencion.entidades.contains(where: { $0.tipo == .persona }) {
            return "¿Te refieres a cuánto te debe esa persona o a una deuda que tú tienes con ella? Son relaciones distintas."
        }
        return nil
    }

    /// Resuelve preguntas como «pago mínimo y pago para no generar
    /// intereses de Hey» o «¿en cuál debo más y cuándo vence?» sin dejar que
    /// un modelo elija solo una mitad de la pregunta.
    private static func respuestaFactualCompuesta(
        intencion: IntencionConsultaClaro,
        resumen r: ResumenFinancieroClaro
    ) -> String? {
        let metricas = intencion.metricasSolicitadas
        guard metricas.allSatisfy({
            esMetricaDeTarjeta($0)
                || $0 == .mayorDeudaTarjeta
                || $0 == .menorDeudaTarjeta
                || $0 == .prioridadDePago
        }) else { return nil }

        var tarjetas = tarjetasReferidas(intencion, resumen: r)
        var encabezado: String?
        if metricas.contains(.mayorDeudaTarjeta),
           let mayor = r.detalleTarjetas.filter({ $0.deuda > 0 })
            .max(by: { $0.deuda < $1.deuda }) {
            tarjetas = [mayor]
            encabezado = "La tarjeta en la que más debes es **\(mayor.nombre)**, con **\(dinero(mayor.deuda))**."
        } else if metricas.contains(.menorDeudaTarjeta),
                  let menor = r.detalleTarjetas.min(by: { $0.deuda < $1.deuda }) {
            tarjetas = [menor]
            encabezado = "La tarjeta en la que menos debes es **\(menor.nombre)**, con **\(dinero(menor.deuda))**."
        } else if metricas.contains(.prioridadDePago),
                  let prioritaria = r.detalleTarjetas
                    .filter({ $0.faltaCorte > 0 })
                    .min(by: {
                        ($0.diasParaVencer ?? Int.max)
                            < ($1.diasParaVencer ?? Int.max)
                    }) {
            tarjetas = [prioritaria]
            encabezado = "La primera prioridad es **\(prioritaria.nombre)**, con **\(dinero(prioritaria.faltaCorte))** pendiente del corte."
        }
        guard !tarjetas.isEmpty else { return nil }

        var bloques = ["## Respuesta"]
        if let encabezado { bloques.append(encabezado) }
        for metrica in metricas where esMetricaDeTarjeta(metrica) {
            // La deuda ya está incluida en los encabezados comparativos.
            if encabezado != nil && metrica == .deudaTarjeta { continue }
            bloques.append(respuestaExactaDeTarjetas(
                tarjetas, metrica: metrica, sumar: intencion.pideTotal))
        }
        return bloques.joined(separator: "\n\n")
    }

    private static func respuestaExactaDeIngresos(
        pregunta: String,
        intencion: IntencionConsultaClaro,
        resumen r: ResumenFinancieroClaro
    ) -> String? {
        let calendario = Calendar(identifier: .gregorian)
        let movimientosDelMes = r.detalleMovimientos.filter {
            calendario.isDate($0.fecha, equalTo: r.generadoEl,
                               toGranularity: .month)
                && [TipoMovimiento.ingreso.rawValue,
                    TipoMovimiento.cobroRecibido.rawValue,
                    TipoMovimiento.bonificacion.rawValue].contains($0.tipo)
        }
        guard !movimientosDelMes.isEmpty else { return nil }

        let cuentas = Set(entidades(intencion, tipo: .cuenta).map(\.nombre))
        var filtrados = cuentas.isEmpty ? movimientosDelMes : movimientosDelMes.filter {
            guard let cuenta = $0.cuenta else { return false }
            return cuentas.contains(cuenta)
        }

        if cuentas.isEmpty {
            let omitidas: Set<String> = [
                "cuanto", "llego", "recibi", "cobre", "ingreso", "ingresos",
                "este", "mes", "de", "del", "la", "el", "mi", "mis",
                "depositaron", "deposito", "nomina"
            ]
            let claves = Set(pregunta.split(separator: " ").map(String.init))
                .subtracting(omitidas)
                .filter { $0.count >= 4 }
            if !claves.isEmpty {
                let porConcepto = movimientosDelMes.filter { movimiento in
                    let fuente = normalizarConsulta([
                        movimiento.detalle, movimiento.cuenta,
                        movimiento.persona
                    ].compactMap { $0 }.joined(separator: " "))
                    return claves.contains { contieneNombreCompleto($0, en: fuente) }
                }
                if !porConcepto.isEmpty { filtrados = porConcepto }
            }
        }

        guard !filtrados.isEmpty,
              filtrados.count != movimientosDelMes.count || !cuentas.isEmpty
        else { return nil }
        let total = filtrados.reduce(0) { $0 + $1.monto }
        let origen = cuentas.isEmpty
            ? "ese origen" : cuentas.sorted().joined(separator: " y ")
        return "Este mes recibiste **\(dinero(total))** en **\(origen)**."
    }

    private static func esMetricaDeTarjeta(
        _ metrica: MetricaConsultaClaro
    ) -> Bool {
        switch metrica {
        case .deudaTarjeta, .saldoAlCorte, .pagoParaNoGenerarIntereses,
             .pagoMinimo, .pagadoDelCorte, .faltaDelCorte, .limiteCredito,
             .creditoDisponible, .fechaCorte, .fechaLimite:
            return true
        default:
            return false
        }
    }

    private static func entidades(
        _ intencion: IntencionConsultaClaro,
        tipo: TipoEntidadClaro
    ) -> [ReferenciaEntidadClaro] {
        intencion.entidades.filter { $0.tipo == tipo }
    }

    private static func tarjetasReferidas(
        _ intencion: IntencionConsultaClaro,
        resumen: ResumenFinancieroClaro
    ) -> [DetalleTarjetaClaro] {
        entidades(intencion, tipo: .tarjeta).compactMap { referencia in
            resumen.detalleTarjetas.first { $0.nombre == referencia.nombre }
        }
    }

    private static func contieneNombreCompleto(
        _ nombre: String, en textoNormalizado: String
    ) -> Bool {
        let nombreNormalizado = normalizarConsulta(nombre)
        return " \(textoNormalizado) ".contains(" \(nombreNormalizado) ")
    }

    private static func respuestaExactaDeTarjetas(
        _ tarjetas: [DetalleTarjetaClaro],
        metrica: MetricaConsultaClaro,
        sumar: Bool
    ) -> String {
        var valoresNumericos: [Double] = []
        let lineas = tarjetas.map { tarjeta -> String in
            let dato: String
            switch metrica {
            case .deudaTarjeta:
                valoresNumericos.append(tarjeta.deuda)
                dato = "deuda registrada \(dinero(tarjeta.deuda))"
            case .saldoAlCorte:
                guard let valor = tarjeta.saldoAlCorte else {
                    return "- **\(tarjeta.nombre):** sin saldo al corte registrado"
                }
                valoresNumericos.append(valor)
                dato = "saldo al corte \(dinero(valor))"
            case .pagoParaNoGenerarIntereses:
                guard let valor = tarjeta.pagoParaNoGenerarIntereses else {
                    return "- **\(tarjeta.nombre):** sin pago para no generar intereses registrado"
                }
                valoresNumericos.append(valor)
                dato = "pago para no generar intereses \(dinero(valor))"
            case .pagoMinimo:
                guard let valor = tarjeta.pagoMinimo else {
                    return "- **\(tarjeta.nombre):** sin pago mínimo registrado"
                }
                valoresNumericos.append(valor)
                dato = "pago mínimo \(dinero(valor))"
            case .pagadoDelCorte:
                guard let valor = tarjeta.pagadoDelCorte else {
                    return "- **\(tarjeta.nombre):** sin corte vigente registrado"
                }
                valoresNumericos.append(valor)
                dato = "pagado del corte \(dinero(valor))"
            case .faltaDelCorte:
                valoresNumericos.append(tarjeta.faltaCorte)
                dato = "falta por cubrir \(dinero(tarjeta.faltaCorte))"
            case .limiteCredito:
                valoresNumericos.append(tarjeta.limite)
                dato = "límite de crédito \(dinero(tarjeta.limite))"
            case .creditoDisponible:
                valoresNumericos.append(tarjeta.creditoDisponible)
                dato = "crédito disponible \(dinero(tarjeta.creditoDisponible))"
            case .fechaCorte:
                guard let fecha = tarjeta.fechaCorte else {
                    return "- **\(tarjeta.nombre):** sin fecha de corte registrada"
                }
                dato = "fecha de corte \(fecha.formatted(date: .long, time: .omitted))"
            case .fechaLimite:
                guard let fecha = tarjeta.fechaLimite else {
                    return "- **\(tarjeta.nombre):** sin fecha límite registrada"
                }
                dato = "fecha límite \(fecha.formatted(date: .long, time: .omitted))"
            default:
                dato = "dato no disponible"
            }
            return "- **\(tarjeta.nombre):** \(dato)"
        }
        var respuesta = lineas.joined(separator: "\n")
        if sumar, tarjetas.count > 1, valoresNumericos.count == tarjetas.count {
            respuesta += "\n- **Total:** \(dinero(valoresNumericos.reduce(0, +)))"
        }
        return respuesta
    }

    // MARK: - Respuestas locales directas

    private static func respuestaPanorama(_ r: ResumenFinancieroClaro) -> String {
        let veredicto: String
        switch r.nivelRiesgo {
        case .bajo: veredicto = "Vas en una posición financiera sana."
        case .moderado: veredicto = "Vas estable, pero con poco margen para errores."
        case .alto: veredicto = "Vas en una posición riesgosa y yo reduciría compromisos nuevos."
        case .critico: veredicto = "Tu posición es crítica: hoy priorizaría liquidez y pagos urgentes."
        }
        var texto = "\(veredicto) Tienes \(dinero(r.disponibleReal)) disponibles después de apartar cortes, un patrimonio estimado de \(dinero(r.patrimonio)) y tu flujo mensual estimado es \(dinero(r.flujoMensualEstimado))."
        if let riesgo = r.factoresRiesgo.first { texto += " El punto más delicado es: \(riesgo.lowercased())." }
        if let fortaleza = r.fortalezas.first { texto += " A tu favor: \(fortaleza.lowercased())." }
        texto += notaDeCalidad(r)
        return texto
    }

    private static func respuestaProyeccion(_ r: ResumenFinancieroClaro) -> String {
        let juicio = r.proyeccionFinDeMes >= 0
            ? "Sí llegas al cierre del mes con liquidez"
            : "No llegas al cierre del mes con la liquidez registrada"
        var texto = "\(juicio): la proyección conservadora termina en \(dinero(r.proyeccionFinDeMes)). Incluye \(dinero(r.pagosAntesDeFinDeMes)) de tarjetas que vencen antes de acabar el mes y el ritmo habitual de ingresos y gastos."
        if r.proyeccionFinDeMes < 0 {
            texto += " El faltante estimado es \(dinero(abs(r.proyeccionFinDeMes))); yo recortaría gastos o movería efectivo antes de tomar otro compromiso."
        }
        texto += notaDeCalidad(r)
        return texto
    }

    private static func respuestaPrestamo(pregunta: String,
                                           resumen r: ResumenFinancieroClaro) -> String {
        let textoNormalizado = normalizarConsulta(pregunta)
        let numeros = numerosEn(textoNormalizado)
        let plazo = plazoEnMeses(textoNormalizado)
        let anosMencionados = anosMencionadosEn(textoNormalizado)
        let monto = montosMonetariosEn(pregunta).max() ?? numeros
            .filter { numero in
                numero >= 500
                    && !anosMencionados.contains(Int(numero))
                    && plazo.map { abs(numero - Double($0)) > 0.01 } != false
            }
            .max()
        let tasaAnual = tasaAnualEn(pregunta)
            ?? tasaAnualEn(textoNormalizado)
        let mensualidadCotizada = mensualidadCotizadaEn(pregunta)
            ?? mensualidadCotizadaEn(textoNormalizado)
        let mensualidadCalculada: Double?
        if let mensualidadCotizada {
            mensualidadCalculada = mensualidadCotizada
        } else if let monto, let plazo, plazo > 0, let tasaAnual {
            mensualidadCalculada = pagoMensualAmortizado(
                principal: monto, tasaAnualPorcentaje: tasaAnual, meses: plazo)
        } else {
            mensualidadCalculada = nil
        }
        let cabe = mensualidadCalculada.map {
            $0 <= r.capacidadMensualPrestamo
        }
        let viableGeneral = r.capacidadMensualPrestamo > 0
            && r.nivelRiesgo != .alto && r.nivelRiesgo != .critico
            && r.proyeccionFinDeMes >= 0
        let veredicto: String
        if let cabe {
            veredicto = cabe && viableGeneral
                ? "Sí parece viable con la mensualidad y los datos actuales."
                : "Yo no tomaría ese préstamo en esas condiciones."
        } else {
            veredicto = "No puedo declarar viable ese préstamo sin conocer la tasa anual o la mensualidad final cotizada."
        }
        var texto = "\(veredicto) Tu capacidad indicativa para una mensualidad nueva es de hasta \(dinero(r.capacidadMensualPrestamo)) y tu flujo mensual estimado es \(dinero(r.flujoMensualEstimado))."
        if let mensualidadCalculada {
            let origen = mensualidadCotizada != nil
                ? "La mensualidad cotizada" : "La mensualidad amortizada estimada"
            texto += " \(origen) es \(dinero(mensualidadCalculada))."
        } else if let monto, let plazo, plazo > 0 {
            let base = monto / Double(plazo)
            texto += " Solo como piso matemático, capital entre plazo da \(dinero(base)); no es una mensualidad real porque faltan intereses y comisiones."
        }
        if let tasaAnual {
            texto += " Usé una tasa anual de \(String(format: "%.2f", tasaAnual))%."
        }
        texto += notaDeCalidad(r)
        return texto
    }

    private static func respuestaRiesgo(_ r: ResumenFinancieroClaro) -> String {
        let inicio: String
        switch r.nivelRiesgo {
        case .bajo: inicio = "No veo señales actuales de un riesgo serio de quedarte sin liquidez."
        case .moderado: inicio = "Tu riesgo de quedarte sin liquidez es moderado, no crítico."
        case .alto: inicio = "Sí hay un riesgo alto de sobreendeudamiento o falta de liquidez."
        case .critico: inicio = "Sí hay señales críticas de falta de liquidez."
        }
        var texto = "\(inicio) El indicador local está en \(r.puntuacionRiesgo) de 100, con patrimonio de \(dinero(r.patrimonio)) y proyección al cierre de \(dinero(r.proyeccionFinDeMes))."
        if !r.factoresRiesgo.isEmpty {
            texto += " Las causas principales son: \(r.factoresRiesgo.prefix(3).joined(separator: "; ").lowercased())."
        }
        texto += " Esto mide presión financiera con tus registros; no es una declaración legal de bancarrota."
        texto += notaDeCalidad(r)
        return texto
    }

    private static func respuestaGasto(_ r: ResumenFinancieroClaro) -> String {
        let margen = max(0, min(r.disponibleReal, max(0, r.proyeccionFinDeMes)))
        let juicio = margen > 0
            ? "Tienes margen, pero yo no gastaría más de \(dinero(margen)) sin alterar la proyección actual."
            : "No tienes margen prudente para gasto adicional en este momento."
        return "\(juicio) Tu disponible real es \(dinero(r.disponibleReal)) y el cierre estimado del mes es \(dinero(r.proyeccionFinDeMes))." + notaDeCalidad(r)
    }

    private static func respuestaDeuda(_ r: ResumenFinancieroClaro) -> String {
        let total = r.deudaTarjetas + r.deudasPersonales
        var texto = "Debes aproximadamente \(dinero(total)): \(dinero(r.deudaTarjetas)) en tarjetas y \(dinero(r.deudasPersonales)) en otras deudas. En los próximos 30 días faltan \(dinero(r.pagosProximos30Dias)) para cubrir cortes registrados."
        if r.estadosVencidos > 0 {
            texto += " Hay \(r.estadosVencidos) corte(s) vencido(s); eso sería mi primera prioridad."
        } else {
            texto += " No detecto cortes vencidos sin cubrir."
        }
        return texto + notaDeCalidad(r)
    }

    private static func notaDeCalidad(_ r: ResumenFinancieroClaro) -> String {
        if r.usaEstimacionPorHistoriaCorta {
            return " Estimé el ritmo mensual a partir de lo que llevas registrado este mes porque todavía no hay meses completos suficientes."
        }
        return " La estimación usa \(r.mesesConHistoria) meses de movimientos y tiene confianza \(r.confianza)."
    }

    private static func normalizarConsulta(_ texto: String) -> String {
        texto
            .folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "es_MX"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func indiceDeTarjetaCoincidente(
        nombres: [String],
        en preguntaNormalizada: String) -> Int? {
        let palabrasGenericas: Set<String> = [
            "banco", "tarjeta", "credito", "credit", "inc", "the"
        ]
        let candidatos = nombres.enumerated().compactMap { indice, nombre
            -> (indice: Int, puntos: Int)? in
            let nombreNormalizado = normalizarConsulta(nombre)
            let palabras = nombreNormalizado.split(separator: " ")
                .map(String.init)
                .filter { $0.count >= 3 && !palabrasGenericas.contains($0) }
            let coincidencias = palabras.filter {
                preguntaNormalizada.split(separator: " ").contains(Substring($0))
            }.count
            guard coincidencias > 0 else { return nil }
            let nombreCompleto = preguntaNormalizada.contains(nombreNormalizado)
            return (indice, coincidencias + (nombreCompleto ? 100 : 0))
        }.sorted { izquierda, derecha in
            izquierda.puntos > derecha.puntos
        }
        guard let primero = candidatos.first else { return nil }
        if candidatos.dropFirst().first?.puntos == primero.puntos {
            return nil
        }
        return primero.indice
    }

    private static func coincideNombre(
        _ nombre: String,
        en preguntaNormalizada: String) -> Bool {
        let palabrasGenericas: Set<String> = [
            "cuenta", "nomina", "debito", "banco", "credito", "deuda"
        ]
        let normalizado = normalizarConsulta(nombre)
        if normalizado.count >= 3, preguntaNormalizada.contains(normalizado) {
            return true
        }
        let palabras = normalizado.split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 3 && !palabrasGenericas.contains($0) }
        return palabras.contains { preguntaNormalizada.contains($0) }
    }

    // MARK: - Cálculos auxiliares

    private struct Promedios {
        var ingresos = 0.0
        var gastos = 0.0
        var gastosEfectivo = 0.0
        var meses = 0
    }

    private static func promediosHistoricos(movimientos: [Movimiento],
                                            ahora: Date) -> Promedios {
        let calendario = Calendar.current
        guard let inicioActual = calendario.dateInterval(of: .month, for: ahora)?.start else {
            return Promedios()
        }
        var meses: [(ingreso: Double, gasto: Double, efectivo: Double,
                     contieneDatos: Bool)] = []
        for retroceso in 1...6 {
            guard let fecha = calendario.date(byAdding: .month, value: -retroceso,
                                              to: inicioActual),
                  let intervalo = calendario.dateInterval(of: .month, for: fecha) else { continue }
            let delMes = movimientos.filter { $0.fecha >= intervalo.start && $0.fecha < intervalo.end }
            let ingreso = delMes.filter { $0.tipo == .ingreso }.reduce(0) { $0 + $1.monto }
            let gasto = delMes.filter { $0.tipo == .gasto || $0.tipo == .compraCredito }
                .reduce(0) { $0 + $1.montoPropio }
            let efectivo = delMes.filter { $0.tipo == .gasto }
                .reduce(0) { $0 + $1.montoPropio }
            meses.append((ingreso, gasto, efectivo, !delMes.isEmpty))
        }
        // Ignora los meses vacíos anteriores al primer registro real. Sí
        // conserva huecos entre meses con actividad, porque representan un
        // mes genuinamente sin ingresos o gastos registrados.
        guard let primero = meses.firstIndex(where: { $0.contieneDatos }),
              let ultimo = meses.lastIndex(where: { $0.contieneDatos }) else {
            return Promedios()
        }
        let resultados = Array(meses[primero...ultimo])
        guard !resultados.isEmpty else { return Promedios() }
        let divisor = Double(resultados.count)
        return Promedios(
            ingresos: resultados.reduce(0) { $0 + $1.ingreso } / divisor,
            gastos: resultados.reduce(0) { $0 + $1.gasto } / divisor,
            gastosEfectivo: resultados.reduce(0) { $0 + $1.efectivo } / divisor,
            meses: resultados.count)
    }

    private static func proporcionTranscurridaDelMes(_ fecha: Date,
                                                      calendario: Calendar) -> Double {
        let dia = calendario.component(.day, from: fecha)
        let dias = calendario.range(of: .day, in: .month, for: fecha)?.count ?? 30
        return min(1, Double(dia) / Double(dias))
    }

    private static func categoriasPrincipales(movimientos: [Movimiento])
        -> [(nombre: String, monto: Double)] {
        var acumulado: [String: Double] = [:]
        for movimiento in movimientos
            where movimiento.tipo == .gasto || movimiento.tipo == .compraCredito {
            acumulado[movimiento.categoria?.nombre ?? "Sin categoría", default: 0]
                += movimiento.montoPropio
        }
        return acumulado.map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
            .prefix(5).map { $0 }
    }

    private static func evaluarRiesgo(ingreso: Double, gasto: Double,
                                      disponible: Double, proyeccion: Double,
                                      deuda: Double, patrimonio: Double,
                                      utilizacion: Double?, cargaMinima: Double,
                                      colchon: Double?, vencidos: Int)
        -> (nivel: NivelRiesgoFinanciero, puntos: Int,
            riesgos: [String], fortalezas: [String]) {
        var puntos = 0
        var riesgos: [String] = []
        var fortalezas: [String] = []
        if vencidos > 0 {
            puntos += min(40, 25 + vencidos * 8)
            riesgos.append("Hay \(vencidos) corte(s) vencido(s) sin cubrir")
        } else { fortalezas.append("No hay cortes vencidos registrados") }
        if disponible < 0 { puntos += 25; riesgos.append("El disponible real está en negativo") }
        else if disponible > 0 { fortalezas.append("El disponible real sigue positivo") }
        if proyeccion < 0 { puntos += 20; riesgos.append("La proyección de fin de mes queda en negativo") }
        if ingreso > 0 {
            let razonGasto = gasto / ingreso
            if razonGasto > 1 { puntos += 22; riesgos.append("El gasto estimado supera al ingreso") }
            else if razonGasto >= 0.90 { puntos += 15; riesgos.append("El gasto consume al menos 90% del ingreso") }
            else if razonGasto >= 0.75 { puntos += 8; riesgos.append("El gasto consume al menos 75% del ingreso") }
            else { fortalezas.append("El gasto estimado deja margen frente al ingreso") }
            let carga = cargaMinima / ingreso
            if carga >= 0.40 { puntos += 20; riesgos.append("Los pagos mínimos consumen al menos 40% del ingreso") }
            else if carga >= 0.30 { puntos += 10; riesgos.append("Los pagos mínimos consumen al menos 30% del ingreso") }
        } else if gasto > 0 {
            puntos += 18; riesgos.append("No hay ingresos habituales suficientes registrados")
        }
        if let utilizacion {
            if utilizacion >= 0.80 { puntos += 15; riesgos.append("La utilización de crédito supera 80%") }
            else if utilizacion >= 0.50 { puntos += 8; riesgos.append("La utilización de crédito supera 50%") }
            else { fortalezas.append("La utilización de crédito está debajo de 50%") }
        }
        if let colchon {
            if colchon < 1 { puntos += 15; riesgos.append("El colchón líquido cubre menos de un mes de gasto") }
            else if colchon < 3 { puntos += 8; riesgos.append("El colchón líquido cubre menos de tres meses") }
            else { fortalezas.append("El colchón líquido cubre al menos tres meses") }
        }
        if patrimonio < 0 && deuda > 0 { puntos += 15; riesgos.append("El patrimonio estimado es negativo") }
        puntos = min(100, puntos)
        let nivel: NivelRiesgoFinanciero
        switch puntos {
        case 0..<25: nivel = .bajo
        case 25..<50: nivel = .moderado
        case 50..<75: nivel = .alto
        default: nivel = .critico
        }
        return (nivel, puntos, riesgos, fortalezas)
    }

    private static func numerosEn(_ texto: String) -> [Double] {
        guard let expresion = try? NSRegularExpression(
            pattern: #"\d[\d,.]*(?:\s*(?:mil|k))?"#,
            options: [.caseInsensitive]) else { return [] }
        let ns = texto as NSString
        return expresion.matches(in: texto, range: NSRange(location: 0, length: ns.length))
            .compactMap { coincidencia -> Double? in
                var valor = ns.substring(with: coincidencia.range).lowercased()
                    .replacingOccurrences(of: " ", with: "")
                let multiplicador = valor.hasSuffix("mil") || valor.hasSuffix("k") ? 1_000.0 : 1
                valor = valor.replacingOccurrences(of: "mil", with: "")
                    .replacingOccurrences(of: "k", with: "")
                    .replacingOccurrences(of: ",", with: "")
                return Double(valor).map { $0 * multiplicador }
            }
    }

    private static func montosMonetariosEn(_ texto: String) -> [Double] {
        guard let expresion = try? NSRegularExpression(
            pattern: #"(?i)(?:\$|MXN\s*)\s*([\d,.]+)(?:\s*(mil|k))?|([\d,.]+)\s*(mil|k)?\s*(?:pesos?|MXN)"#)
        else { return [] }
        let ns = texto as NSString
        return expresion.matches(
            in: texto, range: NSRange(location: 0, length: ns.length)
        ).compactMap { coincidencia in
            let rangoNumero = coincidencia.range(at: 1).location != NSNotFound
                ? coincidencia.range(at: 1) : coincidencia.range(at: 3)
            guard rangoNumero.location != NSNotFound else { return nil }
            let limpio = ns.substring(with: rangoNumero)
                .replacingOccurrences(of: ",", with: "")
            guard let base = Double(limpio) else { return nil }
            let rangoEscala = coincidencia.range(at: 2).location != NSNotFound
                ? coincidencia.range(at: 2) : coincidencia.range(at: 4)
            return base * (rangoEscala.location != NSNotFound ? 1_000 : 1)
        }
    }

    private static func anosMencionadosEn(_ texto: String) -> Set<Int> {
        guard let expresion = try? NSRegularExpression(
            pattern: #"(?i)(?:en|para|durante)\s+(?:el\s+)?(?:ano\s+)?(19\d{2}|20\d{2}|21\d{2})"#)
        else { return [] }
        let ns = texto as NSString
        return Set(expresion.matches(
            in: texto, range: NSRange(location: 0, length: ns.length)
        ).compactMap { coincidencia in
            guard coincidencia.numberOfRanges > 1 else { return nil }
            return Int(ns.substring(with: coincidencia.range(at: 1)))
        })
    }

    private static func plazoEnMeses(_ texto: String) -> Int? {
        if let expresion = try? NSRegularExpression(
            pattern: #"(\d{1,3})\s*(?:mes|meses)"#,
            options: [.caseInsensitive]),
           let resultado = expresion.firstMatch(
            in: texto,
            range: NSRange(location: 0, length: (texto as NSString).length)),
           resultado.numberOfRanges > 1 {
            return Int((texto as NSString).substring(with: resultado.range(at: 1)))
        }
        guard let expresionAnos = try? NSRegularExpression(
            pattern: #"(\d{1,2})\s*(?:ano|anos)"#,
            options: [.caseInsensitive]) else { return nil }
        let ns = texto as NSString
        guard let resultado = expresionAnos.firstMatch(
            in: texto, range: NSRange(location: 0, length: ns.length)),
              resultado.numberOfRanges > 1 else { return nil }
        return Int(ns.substring(with: resultado.range(at: 1))).map { $0 * 12 }
    }

    private static func tasaAnualEn(_ texto: String) -> Double? {
        let normalizado = normalizarConsulta(texto)
        let preservandoSignos = texto
            .folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "es_MX"))
            .lowercased()
        // Una tasa mensual no puede tratarse como anual: se convierte a su
        // equivalente nominal anual para calcular la mensualidad.
        if let mensual = porcentajeConPeriodo(
            en: preservandoSignos,
            periodos: ["mensual", "al mes", "por mes"]) {
            return mensual * 12
        }
        // El CAT incluye otros costos y no es la tasa amortizable del crédito.
        // Si es el único porcentaje disponible, se solicita la tasa o cuota.
        if normalizado.contains("cat")
            && !normalizado.contains("tasa anual")
            && !normalizado.contains("interes anual") {
            return nil
        }
        return porcentajeConPeriodo(
            en: preservandoSignos,
            periodos: ["anual", "al ano", "a.a."])
    }

    private static func porcentajeConPeriodo(
        en texto: String, periodos: [String]
    ) -> Double? {
        let alternativas = periodos
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        let patrones = [
            #"(?i)(\d{1,3}(?:\.\d+)?)\s*%\s*(?:"# + alternativas + ")",
            #"(?i)(?:tasa\s+|interes\s+)?(?:"# + alternativas
                + #")(?:\s+(?:de|del))?\s*(\d{1,3}(?:\.\d+)?)\s*%"#
        ]
        let ns = texto as NSString
        for patron in patrones {
            guard let expresion = try? NSRegularExpression(pattern: patron),
                  let resultado = expresion.firstMatch(
                    in: texto, range: NSRange(location: 0, length: ns.length)),
                  resultado.numberOfRanges > 1 else { continue }
            return Double(ns.substring(with: resultado.range(at: 1)))
        }
        return nil
    }

    private static func mensualidadCotizadaEn(_ texto: String) -> Double? {
        guard let expresion = try? NSRegularExpression(
            pattern: #"(?i)mensualidad(?:\s+(?:de|es|seria|queda))?\s*(?:de\s*)?(?:\$|MXN\s*)\s*([\d,.]+)"#),
              let resultado = expresion.firstMatch(
                in: texto,
                range: NSRange(location: 0, length: (texto as NSString).length)),
              resultado.numberOfRanges > 1 else { return nil }
        let limpio = (texto as NSString).substring(with: resultado.range(at: 1))
            .replacingOccurrences(of: ",", with: "")
        return Double(limpio)
    }

    private static func pagoMensualAmortizado(
        principal: Double,
        tasaAnualPorcentaje: Double,
        meses: Int
    ) -> Double {
        guard meses > 0 else { return 0 }
        let tasaMensual = tasaAnualPorcentaje / 100 / 12
        guard tasaMensual > 0 else { return principal / Double(meses) }
        let factor = pow(1 + tasaMensual, Double(meses))
        return principal * tasaMensual * factor / (factor - 1)
    }
}

private func dinero(_ valor: Double) -> String {
    let formato = NumberFormatter()
    formato.numberStyle = .currency
    formato.locale = Locale(identifier: "es_MX")
    formato.minimumFractionDigits = 2
    formato.maximumFractionDigits = 2
    return formato.string(from: NSNumber(value: valor.redondeadoAMoneda)) ?? "$0.00"
}

private func porcentaje(_ valor: Double) -> String {
    "\(Int((valor * 100).rounded()))%"
}
