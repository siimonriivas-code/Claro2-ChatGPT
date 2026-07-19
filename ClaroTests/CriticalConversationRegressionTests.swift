import XCTest
@testable import Claro

final class CriticalConversationRegressionTests: XCTestCase {

    private let resumen = ResumenFinancieroClaro.pruebaConversacional

    func testPreguntasGeneralesNoHeredanDiagnosticoFinanciero() {
        let historial = [
            TurnoConversacionClaro(
                esUsuario: false,
                texto: "Tu riesgo financiero es crítico",
                ambito: .finanzasPersonales)
        ]
        let generales = [
            "Hola", "Bien y tú", "¿Cómo cocinar arroz?",
            "¿Cuándo nació Messi?", "¿Qué opinas de Colima?",
            "¿Está bien escrito?", "¿Qué es Colima?",
            "¿Qué es Liverpool?", "¿Qué significa Alondra?",
            "¿Qué es el patrimonio mundial?", "¿Qué es un banco de arena?",
            "¿Qué son los créditos cinematográficos?",
            "¿Cuánto tengo de edad?"
        ]

        for pregunta in generales {
            let decision = EnrutadorConsultaClaro.decidir(
                pregunta: pregunta, historial: historial, resumen: resumen)
            XCTAssertEqual(
                decision.intencion.ambito, .general,
                "No debía heredar finanzas: \(pregunta)")
        }
    }

    func testEducacionFinancieraNuncaUsaDatosPersonales() {
        let casos = [
            "¿Qué es el pago mínimo?",
            "¿Cómo funciona una tarjeta de crédito?",
            "Explícame el método avalancha",
            "En México, ¿qué tarjeta suele tener mayor deuda?",
            "¿Qué diferencia hay entre saldo al corte y deuda total?"
        ]
        for pregunta in casos {
            let decision = EnrutadorConsultaClaro.decidir(
                pregunta: pregunta, historial: [], resumen: resumen)
            XCTAssertEqual(
                decision.intencion.ambito, .educacionFinanciera,
                "Debía ser educación sin datos privados: \(pregunta)")
            XCTAssertFalse(decision.intencion.ambito.usaDatosPersonales)
        }
    }

    func testLenguajePersonalNaturalSeReconoceSinConfigurarCadaPregunta() {
        let casos: [(String, MetricaConsultaClaro)] = [
            ("¿Cómo ves mis finanzas?", .panorama),
            ("¿Cómo voy a cerrar el mes?", .proyeccionFinDeMes),
            ("¿Cuánto me quedará al final del mes?", .proyeccionFinDeMes),
            ("¿Qué riesgo tengo?", .riesgo),
            ("¿Hay riesgo de bancarrota?", .riesgo),
            ("¿Crees que sea viable sacar un préstamo?", .prestamo),
            ("¿Es buen momento para un préstamo?", .prestamo),
            ("¿En cuál tarjeta debo más?", .mayorDeudaTarjeta),
            ("¿Cuál debo pagar primero?", .prioridadDePago),
            ("¿Cuál vence primero?", .prioridadDePago),
            ("¿Cuál es el mínimo a pagar de Hey Banco INC?", .pagoMinimo),
            ("¿Cuál es el saldo del corte de Hey Banco INC?", .saldoAlCorte),
            ("¿Cuánto pago para evitar intereses en Hey Banco INC?", .pagoParaNoGenerarIntereses),
            ("¿Cuánto aboné a Hey Banco INC?", .pagadoDelCorte),
            ("¿Cuál es la línea de crédito de Hey Banco INC?", .limiteCredito),
            ("¿Cuánto crédito le queda a Hey Banco INC?", .creditoDisponible),
            ("¿Qué día corta Hey Banco INC?", .fechaCorte),
            ("¿Cuándo tengo que pagar Hey Banco INC?", .fechaLimite),
            ("¿Cuánto tengo en mis cuentas?", .saldoCuenta),
            ("¿Quién me debe más?", .porCobrarPersona),
            ("¿Cuánto llegó de pensión?", .ingresos),
            ("¿Cuánto gasté?", .gastos),
            ("¿Puedo gastar $5,000?", .gastos),
            ("¿Me alcanza para un iPhone?", .gastos),
            ("¿Qué pasa si pago Hey Banco INC?", .desconocida),
            ("Compara mis tarjetas", .deudaTarjeta)
        ]

        for (pregunta, metrica) in casos {
            let decision = EnrutadorConsultaClaro.decidir(
                pregunta: pregunta, historial: [], resumen: resumen)
            XCTAssertEqual(
                decision.intencion.ambito, .finanzasPersonales,
                "Debía usar las finanzas personales: \(pregunta)")
            XCTAssertEqual(
                decision.intencion.metrica, metrica,
                "Métrica incorrecta: \(pregunta)")
        }
    }

    func testReferenciaPersonalGanaAMarcadoresEducativos() {
        let casos = [
            "En México, ¿cuál de mis tarjetas debo pagar primero?",
            "Hipotéticamente, ¿puedo tomar este préstamo con mis finanzas?"
        ]
        for pregunta in casos {
            XCTAssertEqual(
                EnrutadorConsultaClaro.decidir(
                    pregunta: pregunta, historial: [], resumen: resumen)
                    .intencion.ambito,
                .finanzasPersonales)
        }
    }

    func testCorreccionYCambioDeTemaConservanLaPreguntaNueva() {
        let correccion = EnrutadorConsultaClaro.decidir(
            pregunta: "Eso está mal: dime el pago mínimo de Hey Banco INC",
            historial: [], resumen: resumen).intencion
        XCTAssertEqual(correccion.acto, .correccion)
        XCTAssertEqual(correccion.ambito, .finanzasPersonales)
        XCTAssertEqual(correccion.metrica, .pagoMinimo)

        let cambioGeneral = EnrutadorConsultaClaro.decidir(
            pregunta: "Otro tema: ¿qué es Colima?",
            historial: [], resumen: resumen).intencion
        XCTAssertEqual(cambioGeneral.acto, .cambioDeTema)
        XCTAssertEqual(cambioGeneral.ambito, .general)

        let cambioFinanciero = EnrutadorConsultaClaro.decidir(
            pregunta: "Olvida eso: ¿cuánto debo?",
            historial: [], resumen: resumen).intencion
        XCTAssertEqual(cambioFinanciero.acto, .cambioDeTema)
        XCTAssertEqual(cambioFinanciero.ambito, .finanzasPersonales)
        XCTAssertEqual(cambioFinanciero.metrica, .deudaTarjeta)

        let correccionSola = EnrutadorConsultaClaro.decidir(
            pregunta: "No te pregunté eso",
            historial: [], resumen: resumen).intencion
        XCTAssertEqual(correccionSola.acto, .correccion)
        XCTAssertEqual(correccionSola.ambito, .general)
    }

    func testSeguimientosBrevesYTemasAutocontenidos() {
        let historial = [
            TurnoConversacionClaro(
                esUsuario: false, texto: "Hey es prioritaria",
                ambito: .finanzasPersonales)
        ]
        for pregunta in ["¿Y la otra tarjeta?", "Hey Banco INC y Liverpool"] {
            XCTAssertEqual(
                EnrutadorConsultaClaro.decidir(
                    pregunta: pregunta, historial: historial, resumen: resumen)
                    .intencion.ambito,
                .finanzasPersonales)
        }
        XCTAssertEqual(
            EnrutadorConsultaClaro.decidir(
                pregunta: "¿Qué es Liverpool?", historial: historial,
                resumen: resumen).intencion.ambito,
            .general)
    }

    func testMotorExactoNoIntercambiaCifrasEntreTarjetas() {
        let casos: [(String, String, [String])] = [
            ("Pago mínimo de Hey Banco INC", "625.00", ["5,776.46", "8,208.65"]),
            ("Saldo al corte de Hey Banco INC", "8,208.65", ["625.00", "5,776.46"]),
            ("Pago para evitar intereses de Hey Banco INC", "5,776.46", ["625.00", "8,208.65"]),
            ("Cuánto aboné a Hey Banco INC", "2,444.46", ["5,776.46"]),
            ("Línea de crédito de Hey Banco INC", "50,000.00", ["100,000.00"]),
            ("Cuánto debo en BBVA Azul", "41,826.41", ["22,480.55"])
        ]
        for (pregunta, correcta, incorrectas) in casos {
            let intencion = EnrutadorConsultaClaro.decidir(
                pregunta: pregunta, historial: [], resumen: resumen).intencion
            let respuesta = MotorClaroInteligente.respuestaFactualExacta(
                intencion: intencion, pregunta: pregunta, resumen: resumen)
            XCTAssertNotNil(respuesta, pregunta)
            XCTAssertTrue(respuesta?.contains(correcta) == true, pregunta)
            for incorrecta in incorrectas {
                XCTAssertFalse(respuesta?.contains(incorrecta) == true, pregunta)
            }
        }
    }

    func testComparacionesTotalesCategoriasEIngresosPorOrigen() {
        let comparacion = respuestaExacta("Compara mis tarjetas")
        XCTAssertTrue(comparacion.contains("BBVA Azul"))
        XCTAssertTrue(comparacion.contains("BBVA Oro"))
        XCTAssertTrue(comparacion.contains("Hey Banco INC"))
        XCTAssertTrue(comparacion.contains("Liverpool"))

        let cuentas = respuestaExacta("Suma mis cuentas")
        XCTAssertTrue(cuentas.contains("40,001.00"))

        let persona = respuestaExacta("¿Quién me debe más?")
        XCTAssertTrue(persona.contains("Alondra"))
        XCTAssertTrue(persona.contains("6,000.66"))

        let categoria = respuestaExacta("¿Cuánto gasté en Comida?")
        XCTAssertTrue(categoria.contains("1,234.56"))

        let pension = respuestaExacta("¿Cuánto llegó de pensión?")
        XCTAssertTrue(pension.contains("13,000.55"))
    }

    func testPrestamoUsaAmortizacionYNoDivisionSimple() {
        let pregunta = "¿Es viable un préstamo de $100,000 a 36 meses con tasa de 20% anual?"
        let intencion = EnrutadorConsultaClaro.decidir(
            pregunta: pregunta, historial: [], resumen: resumen).intencion
        let respuesta = MotorClaroInteligente.responderConReglas(
            intencion: intencion, pregunta: pregunta, resumen: resumen)
        XCTAssertTrue(respuesta.contains("3,716.36"), respuesta)
        XCTAssertFalse(respuesta.contains("2,777.78"), respuesta)

        let sinTasa = "¿Es viable un préstamo de $100,000 a 36 meses?"
        let intencionSinTasa = EnrutadorConsultaClaro.decidir(
            pregunta: sinTasa, historial: [], resumen: resumen).intencion
        let respuestaSinTasa = MotorClaroInteligente.responderConReglas(
            intencion: intencionSinTasa, pregunta: sinTasa, resumen: resumen)
        XCTAssertTrue(respuestaSinTasa.contains("No puedo declarar viable"))
    }

    private func respuestaExacta(_ pregunta: String) -> String {
        let intencion = EnrutadorConsultaClaro.decidir(
            pregunta: pregunta, historial: [], resumen: resumen).intencion
        return MotorClaroInteligente.respuestaFactualExacta(
            intencion: intencion, pregunta: pregunta, resumen: resumen) ?? ""
    }
}

extension ResumenFinancieroClaro {
    static var pruebaConversacional: ResumenFinancieroClaro {
        let fecha = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 7, day: 19, hour: 12))!
        let corte = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 7, day: 13))!
        let limite = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 8, day: 3))!
        return ResumenFinancieroClaro(
            generadoEl: fecha,
            saldoLiquido: 40_001,
            comprometidoTarjetas: 20_551.46,
            disponibleReal: 19_449.54,
            deudaTarjetas: 82_971.07,
            limiteTarjetas: 300_000,
            utilizacionCredito: 0.27657,
            deudasPersonales: 2_881.47,
            porCobrar: 11_223.76,
            patrimonio: -34_627.78,
            ingresoMesActual: 40_001,
            gastoMesActual: 1_234.56,
            ingresoMensualEstimado: 40_001,
            ingresosRecurrentesEsperados: 40_001,
            ingresosRecurrentesPendientes: 0,
            gastoMensualEstimado: 20_000,
            flujoMensualEstimado: 20_001,
            proyeccionFinDeMes: 18_000,
            pagosAntesDeFinDeMes: 10_000,
            pagosProximos30Dias: 20_551.46,
            cargaMinimaDeudaMensual: 1_525,
            capacidadMensualPrestamo: 5_000,
            mesesDeColchon: 1.2,
            compromisoFuturoMSI: 8_208.65,
            compromisoMensualMSI: 1_695.46,
            estadosVencidos: 0,
            movimientosAnalizados: 12,
            mesesConHistoria: 3,
            usaEstimacionPorHistoriaCorta: false,
            nivelRiesgo: .moderado,
            puntuacionRiesgo: 35,
            confianza: "alta",
            factoresRiesgo: [],
            fortalezas: [],
            categoriasPrincipales: [(nombre: "Comida", monto: 1_234.56)],
            cargosRecurrentes: [],
            detalleTarjetas: [
                DetalleTarjetaClaro(
                    nombre: "BBVA Azul", deuda: 41_826.41, limite: 100_000,
                    creditoDisponible: 58_173.59, saldoAlCorte: 21_555.11,
                    pagoParaNoGenerarIntereses: 20_000, pagoMinimo: 900,
                    pagadoDelCorte: 0, faltaCorte: 20_000,
                    fechaCorte: corte, fechaLimite: limite, diasParaVencer: 15,
                    tasaAnual: nil, cat: nil),
                DetalleTarjetaClaro(
                    nombre: "BBVA Oro", deuda: 22_480.55, limite: 80_000,
                    creditoDisponible: 57_519.45, saldoAlCorte: 10_000,
                    pagoParaNoGenerarIntereses: 9_000, pagoMinimo: 500,
                    pagadoDelCorte: 0, faltaCorte: 9_000,
                    fechaCorte: corte, fechaLimite: limite, diasParaVencer: 15,
                    tasaAnual: nil, cat: nil),
                DetalleTarjetaClaro(
                    nombre: "Hey Banco INC", deuda: 18_066.11, limite: 50_000,
                    creditoDisponible: 31_933.89, saldoAlCorte: 8_208.65,
                    pagoParaNoGenerarIntereses: 5_776.46, pagoMinimo: 625,
                    pagadoDelCorte: 2_444.46, faltaCorte: 3_332,
                    fechaCorte: corte, fechaLimite: limite, diasParaVencer: 15,
                    tasaAnual: nil, cat: nil),
                DetalleTarjetaClaro(
                    nombre: "Liverpool", deuda: 598, limite: 70_000,
                    creditoDisponible: 69_402, saldoAlCorte: 299,
                    pagoParaNoGenerarIntereses: 299, pagoMinimo: 30,
                    pagadoDelCorte: 0, faltaCorte: 299,
                    fechaCorte: corte, fechaLimite: limite, diasParaVencer: 25,
                    tasaAnual: nil, cat: nil)
            ],
            detalleCuentas: [
                DetalleCuentaClaro(
                    nombre: "Nómina CIAPACOV", banco: "BBVA",
                    tipo: "Débito", saldo: 27_000.45),
                DetalleCuentaClaro(
                    nombre: "Nómina Pensión", banco: "BBVA",
                    tipo: "Débito", saldo: 13_000.55)
            ],
            detallePersonas: [
                DetallePersonaClaro(nombre: "Alondra", pendiente: 6_000.66),
                DetallePersonaClaro(nombre: "Hermano", pendiente: 5_000.77),
                DetallePersonaClaro(nombre: "Ana", pendiente: 111.11),
                DetallePersonaClaro(nombre: "Mariana", pendiente: 111.22)
            ],
            detalleDeudas: [
                DetalleDeudaClaro(
                    acreedor: "Hermano", saldo: 861.85,
                    tasaAnual: nil, cat: nil, mensualidad: nil),
                DetalleDeudaClaro(
                    acreedor: "BODOQUE", saldo: 2_019.62,
                    tasaAnual: nil, cat: nil, mensualidad: nil)
            ],
            detalleMovimientos: [
                DetalleMovimientoClaro(
                    fecha: fecha, tipo: TipoMovimiento.ingreso.rawValue,
                    detalle: "Nómina pensión julio", monto: 13_000.55,
                    cuenta: "Nómina Pensión", cuentaDestino: nil,
                    tarjeta: nil, categoria: nil, persona: nil),
                DetalleMovimientoClaro(
                    fecha: fecha, tipo: TipoMovimiento.ingreso.rawValue,
                    detalle: "Nómina CIAPACOV julio", monto: 27_000.45,
                    cuenta: "Nómina CIAPACOV", cuentaDestino: nil,
                    tarjeta: nil, categoria: nil, persona: nil)
            ])
    }
}
