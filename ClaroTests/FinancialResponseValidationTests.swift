import XCTest
@testable import Claro

final class FinancialResponseValidationTests: XCTestCase {

    private let resumen = ResumenFinancieroClaro.pruebaConversacional

    func testRechazaMontoInventado() {
        let intencion = intencion("¿Cuánto debo en Hey Banco INC?")
        XCTAssertFalse(ClaroInteligenciaLocal.respuestaFinancieraEsConsistente(
            "Debes $9,999.99 en Hey Banco INC.",
            intencion: intencion,
            pregunta: "¿Cuánto debo en Hey Banco INC?",
            resumen: resumen))
    }

    func testRechazaMontosRealesIntercambiadosEntreTarjetas() {
        let pregunta = "Compara BBVA Azul y BBVA Oro"
        let intencion = IntencionConsultaClaro(
            ambito: .finanzasPersonales, acto: .pregunta,
            metrica: .deudaTarjeta,
            metricasSolicitadas: [.deudaTarjeta],
            entidades: [
                .init(tipo: .tarjeta, nombre: "BBVA Azul"),
                .init(tipo: .tarjeta, nombre: "BBVA Oro")
            ],
            dependeDelHistorial: false, pideTotal: false,
            pideComparacion: true, esEspecifica: true)
        let intercambiada = """
        - BBVA Azul: $22,480.55
        - BBVA Oro: $41,826.41
        """
        XCTAssertFalse(ClaroInteligenciaLocal.respuestaFinancieraEsConsistente(
            intercambiada, intencion: intencion,
            pregunta: pregunta, resumen: resumen))
    }

    func testAceptaAsociacionCorrectaPorEntidad() {
        let pregunta = "Compara BBVA Azul y BBVA Oro"
        let intencion = IntencionConsultaClaro(
            ambito: .finanzasPersonales, acto: .pregunta,
            metrica: .deudaTarjeta,
            metricasSolicitadas: [.deudaTarjeta],
            entidades: [
                .init(tipo: .tarjeta, nombre: "BBVA Azul"),
                .init(tipo: .tarjeta, nombre: "BBVA Oro")
            ],
            dependeDelHistorial: false, pideTotal: false,
            pideComparacion: true, esEspecifica: true)
        let correcta = """
        - BBVA Azul: $41,826.41
        - BBVA Oro: $22,480.55
        """
        XCTAssertTrue(ClaroInteligenciaLocal.respuestaFinancieraEsConsistente(
            correcta, intencion: intencion,
            pregunta: pregunta, resumen: resumen))
    }

    func testParserDeMontosAceptaFormatosComunesYExcluyeFechas() {
        let montos = ClaroInteligenciaLocal.montosEn(
            "Fechas 13/07/2026 y 03.08.2026; $5,000; 6 mil; 5000 pesos")
        XCTAssertEqual(montos.filter { abs($0 - 5_000) < 0.01 }.count, 2)
        XCTAssertEqual(montos.filter { abs($0 - 6_000) < 0.01 }.count, 1)
        XCTAssertFalse(montos.contains(13))
        XCTAssertFalse(montos.contains(7))
        XCTAssertFalse(montos.contains(2026))
        XCTAssertFalse(montos.contains(3.08))
    }

    func testRechazaPorcentajeYConteoDeCortesIncorrectos() {
        let intencionRiesgo = intencion("¿Qué riesgo financiero tengo?")
        XCTAssertFalse(ClaroInteligenciaLocal.respuestaFinancieraEsConsistente(
            "Tu utilización es 30% y tienes 3 cortes vencidos.",
            intencion: intencionRiesgo,
            pregunta: "¿Qué riesgo financiero tengo?", resumen: resumen))
        XCTAssertTrue(ClaroInteligenciaLocal.respuestaFinancieraEsConsistente(
            "Tu utilización es 28% y tienes 0 cortes vencidos.",
            intencion: intencionRiesgo,
            pregunta: "¿Qué riesgo financiero tengo?", resumen: resumen))
    }

    func testRechazaDineroEscritoConPalabras() {
        let pregunta = "¿Cuánto debo en Hey Banco INC?"
        XCTAssertFalse(ClaroInteligenciaLocal.respuestaFinancieraEsConsistente(
            "Debes seis mil pesos en Hey Banco INC.",
            intencion: intencion(pregunta),
            pregunta: pregunta, resumen: resumen))
    }

    func testRechazaCambioDeSignoEnUnaCifraReal() {
        let pregunta = "¿Cuánto dinero tengo disponible?"
        let valor = abs(resumen.disponibleReal)
        let signoInvertido = resumen.disponibleReal < 0 ? valor : -valor
        let respuesta = "Tienes \(signoInvertido.formatted(.number.precision(.fractionLength(2)))) pesos disponibles."
        XCTAssertFalse(ClaroInteligenciaLocal.respuestaFinancieraEsConsistente(
            respuesta, intencion: intencion(pregunta), pregunta: pregunta,
            resumen: resumen))
    }

    func testRechazaIntercambiarMetricasDeLaMismaTarjeta() throws {
        let pregunta = "¿Cuál es el pago mínimo de Hey Banco INC?"
        let tarjeta = try XCTUnwrap(resumen.detalleTarjetas.first {
            $0.nombre == "Hey Banco INC"
        })
        let pngi = try XCTUnwrap(tarjeta.pagoParaNoGenerarIntereses)
        XCTAssertFalse(ClaroInteligenciaLocal.respuestaFinancieraEsConsistente(
            "El pago mínimo de Hey Banco INC es $\(pngi).",
            intencion: intencion(pregunta), pregunta: pregunta,
            resumen: resumen))
    }

    func testRechazaEvasionEnPreguntaFactual() {
        let pregunta = "¿Cuánto debo en Hey Banco INC?"
        XCTAssertFalse(ClaroInteligenciaLocal.respuestaFinancieraEsConsistente(
            "No tengo acceso a esa información.",
            intencion: intencion(pregunta), pregunta: pregunta,
            resumen: resumen))
    }

    func testPermiteMontoHipoteticoEscritoPorUsuarioEnPrestamo() {
        let pregunta = "¿Es viable un préstamo de $100,000?"
        XCTAssertTrue(ClaroInteligenciaLocal.respuestaFinancieraEsConsistente(
            "El monto solicitado es $100,000.00.",
            intencion: intencion(pregunta),
            pregunta: pregunta, resumen: resumen))
    }

    func testContextoDeQwenTieneLimitesDeTamanoYMovimientos() {
        let movimientos = (0..<100).map { indice in
            DetalleMovimientoClaro(
                fecha: resumen.generadoEl.addingTimeInterval(Double(-indice)),
                tipo: TipoMovimiento.gasto.rawValue,
                detalle: "Movimiento \(indice) " + String(repeating: "detalle-largo ", count: 300),
                monto: Double(100 + indice), cuenta: "Débito",
                cuentaDestino: nil, tarjeta: nil, categoria: "Pruebas",
                persona: nil)
        }
        let grande = resumen.reemplazandoMovimientos(movimientos)
        let contexto = grande.contextoParaModelo(consulta: "movimientos recientes")
        XCTAssertLessThanOrEqual(contexto.count, 12_100)
        XCTAssertTrue(contexto.contains("selección local de 10 de 100"), contexto)
        XCTAssertFalse(contexto.hasSuffix("detalle-lar"), contexto)
    }

    func testSolicitudCompletaLimitaPreguntaEHistorialAntesDeTokenizar() {
        let textoEnorme = String(repeating: "pregunta-muy-larga ", count: 8_000)
        let historial = (0..<20).map { indice in
            TurnoConversacionClaro(
                esUsuario: indice.isMultiple(of: 2),
                texto: textoEnorme,
                ambito: .finanzasPersonales)
        }
        let solicitud = ClaroInteligenciaLocal.solicitudDelCopiloto(
            pregunta: textoEnorme,
            resumen: resumen,
            interpretacion: textoEnorme,
            historial: historial)
        XCTAssertLessThanOrEqual(solicitud.count, 18_000)
        XCTAssertTrue(solicitud.contains("Texto adicional omitido"))
        XCTAssertTrue(solicitud.contains("HECHOS REGISTRADOS"))
        XCTAssertTrue(solicitud.contains("TAREA:"))
    }

    private func intencion(_ pregunta: String) -> IntencionConsultaClaro {
        EnrutadorConsultaClaro.decidir(
            pregunta: pregunta, historial: [], resumen: resumen).intencion
    }
}

private extension ResumenFinancieroClaro {
    func reemplazandoMovimientos(
        _ movimientos: [DetalleMovimientoClaro]
    ) -> ResumenFinancieroClaro {
        ResumenFinancieroClaro(
            generadoEl: generadoEl,
            saldoLiquido: saldoLiquido,
            comprometidoTarjetas: comprometidoTarjetas,
            disponibleReal: disponibleReal,
            deudaTarjetas: deudaTarjetas,
            limiteTarjetas: limiteTarjetas,
            utilizacionCredito: utilizacionCredito,
            deudasPersonales: deudasPersonales,
            porCobrar: porCobrar,
            patrimonio: patrimonio,
            ingresoMesActual: ingresoMesActual,
            gastoMesActual: gastoMesActual,
            ingresoMensualEstimado: ingresoMensualEstimado,
            ingresosRecurrentesEsperados: ingresosRecurrentesEsperados,
            ingresosRecurrentesPendientes: ingresosRecurrentesPendientes,
            gastoMensualEstimado: gastoMensualEstimado,
            flujoMensualEstimado: flujoMensualEstimado,
            proyeccionFinDeMes: proyeccionFinDeMes,
            pagosAntesDeFinDeMes: pagosAntesDeFinDeMes,
            pagosProximos30Dias: pagosProximos30Dias,
            cargaMinimaDeudaMensual: cargaMinimaDeudaMensual,
            capacidadMensualPrestamo: capacidadMensualPrestamo,
            mesesDeColchon: mesesDeColchon,
            compromisoFuturoMSI: compromisoFuturoMSI,
            compromisoMensualMSI: compromisoMensualMSI,
            estadosVencidos: estadosVencidos,
            movimientosAnalizados: movimientos.count,
            mesesConHistoria: mesesConHistoria,
            usaEstimacionPorHistoriaCorta: usaEstimacionPorHistoriaCorta,
            nivelRiesgo: nivelRiesgo,
            puntuacionRiesgo: puntuacionRiesgo,
            confianza: confianza,
            factoresRiesgo: factoresRiesgo,
            fortalezas: fortalezas,
            categoriasPrincipales: categoriasPrincipales,
            cargosRecurrentes: cargosRecurrentes,
            detalleTarjetas: detalleTarjetas,
            detalleCuentas: detalleCuentas,
            detallePersonas: detallePersonas,
            detalleDeudas: detalleDeudas,
            detalleMovimientos: movimientos)
    }
}
