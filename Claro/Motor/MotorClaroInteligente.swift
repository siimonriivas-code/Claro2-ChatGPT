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
    let detalleTarjetas: [(nombre: String, deuda: Double, limite: Double,
                           faltaCorte: Double, dias: Int?)]

    var contextoParaModelo: String {
        let uso = utilizacionCredito.map { porcentaje($0) } ?? "sin límite registrado"
        let colchon = mesesDeColchon.map { String(format: "%.1f meses", $0) }
            ?? "no calculable por falta de gasto histórico"
        let tarjetasTexto = detalleTarjetas.isEmpty ? "ninguna" : detalleTarjetas.map {
            let vencimiento = $0.dias.map { "\($0) días" } ?? "sin corte vigente"
            return "\($0.nombre): deuda \(dinero($0.deuda)), límite \(dinero($0.limite)), "
                + "falta del corte \(dinero($0.faltaCorte)), vencimiento \(vencimiento)"
        }.joined(separator: " | ")
        let categorias = categoriasPrincipales.isEmpty ? "sin datos" : categoriasPrincipales
            .map { "\($0.nombre) \(dinero($0.monto))" }.joined(separator: ", ")
        let recurrentes = cargosRecurrentes.isEmpty ? "ninguno detectado" : cargosRecurrentes
            .prefix(6).map { "\($0.comercio) ~\(dinero($0.promedio))/mes" }
            .joined(separator: ", ")
        let riesgos = factoresRiesgo.isEmpty ? "ninguno relevante" : factoresRiesgo.joined(separator: " | ")
        let positivos = fortalezas.isEmpty ? "ninguno comprobable" : fortalezas.joined(separator: " | ")

        return """
        FECHA DEL ANÁLISIS: \(generadoEl.formatted(date: .long, time: .shortened))
        LIQUIDEZ: cuentas \(dinero(saldoLiquido)); comprometido en cortes \(dinero(comprometidoTarjetas)); disponible real \(dinero(disponibleReal)).
        DEUDAS: tarjetas \(dinero(deudaTarjetas)); utilización \(uso); otras deudas \(dinero(deudasPersonales)); por cobrar \(dinero(porCobrar)).
        PATRIMONIO ESTIMADO: \(dinero(patrimonio)).
        MES ACTUAL: ingresos registrados \(dinero(ingresoMesActual)); gastos de consumo \(dinero(gastoMesActual)).
        RITMO MENSUAL ESTIMADO: ingresos \(dinero(ingresoMensualEstimado)); gastos \(dinero(gastoMensualEstimado)); flujo \(dinero(flujoMensualEstimado)).
        PROYECCIÓN CONSERVADORA DE EFECTIVO AL FIN DE MES: \(dinero(proyeccionFinDeMes)); pagos de tarjetas antes de fin de mes \(dinero(pagosAntesDeFinDeMes)); pagos en próximos 30 días \(dinero(pagosProximos30Dias)).
        CAPACIDAD INDICATIVA PARA UNA NUEVA MENSUALIDAD: hasta \(dinero(capacidadMensualPrestamo)); carga mínima mensual de deuda actual \(dinero(cargaMinimaDeudaMensual)); colchón líquido \(colchon).
        MSI: compromiso futuro total \(dinero(compromisoFuturoMSI)); mensualidad futura aproximada \(dinero(compromisoMensualMSI)).
        RIESGO: \(nivelRiesgo.rawValue) (\(puntuacionRiesgo)/100); cortes vencidos \(estadosVencidos); confianza \(confianza).
        FACTORES DE RIESGO: \(riesgos).
        FORTALEZAS: \(positivos).
        TARJETAS: \(tarjetasTexto).
        MAYORES CATEGORÍAS DEL MES: \(categorias).
        CARGOS RECURRENTES: \(recurrentes).
        COBERTURA DE DATOS: \(movimientosAnalizados) movimientos; \(mesesConHistoria) meses con historia; estimación por historia corta: \(usaEstimacionPorHistoriaCorta ? "sí" : "no").
        """
    }
}

enum MotorClaroInteligente {

    static func resumir(cuentas: [CuentaBancaria],
                        tarjetas: [TarjetaCredito],
                        personas: [Persona],
                        planes: [PlanMSI],
                        deudas: [Deuda],
                        movimientos: [Movimiento],
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
        let ingresoEstimado = historiaCorta ? ingresoMes / proporcionMes : historico.ingresos
        let gastoEstimado = historiaCorta ? gastoMes / proporcionMes : historico.gastos
        let gastoEfectivoEstimado = historiaCorta
            ? gastoEfectivoMes / proporcionMes : historico.gastosEfectivo

        let saldoLiquido = MotorDashboard.saldoTotal(cuentas: cuentas)
        let comprometido = MotorDashboard.comprometido(tarjetas: tarjetas)
        let disponible = saldoLiquido - comprometido
        let deudaTarjetas = tarjetas.reduce(0) { $0 + max(0, $1.deudaCalculada) }
        let limiteTarjetas = tarjetas.reduce(0) { $0 + max(0, $1.limiteCredito) }
        let utilizacion = limiteTarjetas > 0 ? deudaTarjetas / limiteTarjetas : nil
        let otrasDeudas = deudas.reduce(0) { $0 + max(0, $1.saldoRestante) }
        let porCobrar = MotorDashboard.totalTeDeben(personas: personas)
        let patrimonio = saldoLiquido + porCobrar - deudaTarjetas - otrasDeudas

        let cortes = tarjetas.compactMap(\.estadoDeCuentaVigente)
        let pendientes = cortes.filter { $0.faltaPorCubrir > 0 }
        let finMesInclusivo = finMes.addingTimeInterval(-1)
        let pagosFinMes = pendientes.filter {
            $0.fechaLimitePago >= calendario.startOfDay(for: ahora)
                && $0.fechaLimitePago <= finMesInclusivo
        }.reduce(0) { $0 + $1.faltaPorCubrir }
        let limite30 = calendario.date(byAdding: .day, value: 30, to: ahora) ?? ahora
        let pagos30 = pendientes.filter {
            $0.fechaLimitePago >= calendario.startOfDay(for: ahora)
                && $0.fechaLimitePago <= limite30
        }.reduce(0) { $0 + $1.faltaPorCubrir }
        let vencidos = pendientes.filter { $0.situacion == .vencidoSinCubrir }.count
        let cargaMinima = cortes.reduce(0) {
            $0 + ($1.situacion == .cubierto ? 0 : max(0, $1.pagoMinimo - $1.pagadoDelPeriodo))
        }

        let ingresoRestante = max(0, ingresoEstimado - ingresoMes)
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

        let detalleTarjetas = tarjetas.map { tarjeta in
            let corte = tarjeta.estadoDeCuentaVigente
            return (tarjeta.nombre, max(0, tarjeta.deudaCalculada),
                    max(0, tarjeta.limiteCredito), corte?.faltaPorCubrir ?? 0,
                    corte?.diasParaVencer)
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
            detalleTarjetas: detalleTarjetas)
    }

    static func responderConReglas(_ pregunta: String,
                                   resumen: ResumenFinancieroClaro) -> String {
        let normalizada = pregunta.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                           locale: Locale(identifier: "es_MX"))
            .lowercased()
        if normalizada.contains("prestamo") || normalizada.contains("credito")
            || normalizada.contains("mensualidad") {
            return respuestaPrestamo(pregunta: normalizada, resumen: resumen)
        }
        if normalizada.contains("bancarrota") || normalizada.contains("quiebra")
            || normalizada.contains("riesgo") || normalizada.contains("insolven") {
            return respuestaRiesgo(resumen)
        }
        if normalizada.contains("fin de mes") || normalizada.contains("cierro")
            || normalizada.contains("proyeccion") || normalizada.contains("proyect") {
            return respuestaProyeccion(resumen)
        }
        if normalizada.contains("gasto") || normalizada.contains("comprar")
            || normalizada.contains("puedo gastar") {
            return respuestaGasto(resumen)
        }
        if normalizada.contains("debo") || normalizada.contains("deuda")
            || normalizada.contains("tarjeta") || normalizada.contains("pagar") {
            return respuestaDeuda(resumen)
        }
        return respuestaPanorama(resumen)
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
        let numeros = numerosEn(pregunta)
        let plazo = plazoEnMeses(pregunta)
        let monto = numeros.first(where: { $0 >= 500 })
        var mensualidadEstimada: Double?
        if let monto, let plazo, plazo > 0 {
            mensualidadEstimada = monto / Double(plazo)
        }
        let cabe = mensualidadEstimada.map { $0 <= r.capacidadMensualPrestamo }
        let viableGeneral = r.capacidadMensualPrestamo > 0
            && r.nivelRiesgo != .alto && r.nivelRiesgo != .critico
            && r.proyeccionFinDeMes >= 0
        let veredicto: String
        if let cabe {
            veredicto = cabe && viableGeneral
                ? "Sí parece viable con los datos actuales."
                : "Yo no tomaría ese préstamo en esas condiciones."
        } else {
            veredicto = viableGeneral
                ? "Podrías considerar un préstamo pequeño, pero no uno que apriete tu flujo."
                : "Ahora mismo yo no sacaría un préstamo nuevo."
        }
        var texto = "\(veredicto) Tu capacidad indicativa para una mensualidad nueva es de hasta \(dinero(r.capacidadMensualPrestamo)) y tu flujo mensual estimado es \(dinero(r.flujoMensualEstimado))."
        if let mensualidadEstimada {
            texto += " Dividiendo el monto entre el plazo, la mensualidad base sería aproximadamente \(dinero(mensualidadEstimada)) antes de intereses y comisiones."
        }
        texto += " La decisión cambiaría si la tasa eleva la mensualidad real por encima de ese margen."
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
        var resultados: [(ingreso: Double, gasto: Double, efectivo: Double)] = []
        for retroceso in 1...6 {
            guard let fecha = calendario.date(byAdding: .month, value: -retroceso,
                                              to: inicioActual),
                  let intervalo = calendario.dateInterval(of: .month, for: fecha) else { continue }
            let delMes = movimientos.filter { $0.fecha >= intervalo.start && $0.fecha < intervalo.end }
            if delMes.isEmpty && resultados.isEmpty { continue }
            let ingreso = delMes.filter { $0.tipo == .ingreso }.reduce(0) { $0 + $1.monto }
            let gasto = delMes.filter { $0.tipo == .gasto || $0.tipo == .compraCredito }
                .reduce(0) { $0 + $1.montoPropio }
            let efectivo = delMes.filter { $0.tipo == .gasto }
                .reduce(0) { $0 + $1.montoPropio }
            resultados.append((ingreso, gasto, efectivo))
        }
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

    private static func plazoEnMeses(_ texto: String) -> Int? {
        guard let expresion = try? NSRegularExpression(
            pattern: #"(\d{1,3})\s*(?:mes|meses)"#,
            options: [.caseInsensitive]) else { return nil }
        let ns = texto as NSString
        guard let resultado = expresion.firstMatch(
            in: texto, range: NSRange(location: 0, length: ns.length)),
              resultado.numberOfRanges > 1 else { return nil }
        return Int(ns.substring(with: resultado.range(at: 1)))
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
