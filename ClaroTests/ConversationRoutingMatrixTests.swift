import XCTest
@testable import Claro

final class ConversationRoutingMatrixTests: XCTestCase {

    private let resumen = ResumenFinancieroClaro.pruebaConversacional

    func testCulturaGeneralYUsosNoFinancierosNoRecibenDatosPrivados() {
        let historialFinanciero = [
            TurnoConversacionClaro(
                esUsuario: false,
                texto: "Tu deuda y riesgo son elevados",
                ambito: .finanzasPersonales)
        ]
        let preguntas = [
            "Hola", "¿Cómo estás?", "Bien y tú", "Gracias",
            "¿Qué es Colima?", "¿Dónde queda Colima?", "¿Quién es Messi?",
            "¿Cómo cocinar arroz?", "¿Qué significa resiliencia?",
            "¿Qué es un banco de arena?", "¿Qué es un banco de peces?",
            "¿Cómo funciona un banco de datos?", "¿Dónde hay un banco de sangre?",
            "¿Qué es un banco de tiempo?", "¿Para qué sirve un banco de pruebas?",
            "¿Qué son los créditos cinematográficos?",
            "¿Quién aparece en los créditos finales?",
            "¿Qué es el patrimonio mundial?",
            "¿Qué significa patrimonio de la humanidad?",
            "¿Cuál es el patrimonio natural de México?",
            "¿Qué es patrimonio cultural?", "¿Qué es patrimonio histórico?",
            "¿Cuál es mi saldo de vacaciones?", "¿Cuántos días de saldo tengo?",
            "Ayúdame con un presupuesto de tiempo",
            "¿Cuándo es el ingreso a la universidad?",
            "¿Cuánto tengo de edad?", "¿Cuánto oro tengo?",
            "Debo cocinar", "Debo arreglar el coche", "Debo escribir una carta",
            "Debo estudiar mañana", "Debo caminar más", "Debo dormir temprano",
            "Este mes cierro la novela", "¿Qué es Liverpool?",
            "¿Quién es Alondra?", "¿Qué significa BBVA?",
            "Quiero saber qué es Liverpool",
            "Quiero saber cómo funciona Hey Banco",
            "¿Cómo está Alondra?", "¿Y Liverpool ganó el partido?",
            "¿Qué opinas de Liverpool?"
        ]

        for pregunta in preguntas {
            let intencion = decidir(pregunta, historial: historialFinanciero)
            XCTAssertEqual(
                intencion.ambito, .general,
                "La pregunta general heredó finanzas privadas: \(pregunta)")
            XCTAssertFalse(intencion.ambito.usaDatosPersonales, pregunta)
        }
    }

    func testEducacionFinancieraSeMantieneGenerica() {
        let preguntas = [
            "¿Qué es el pago mínimo?",
            "¿Qué es el pago para no generar intereses?",
            "¿Qué significa saldo al corte?",
            "¿Cómo funciona una tarjeta de crédito?",
            "¿Qué diferencia hay entre débito y crédito?",
            "¿Qué es el CAT?", "¿Qué es una tasa anual?",
            "¿Cómo se calculan los intereses?", "¿Qué es interés compuesto?",
            "¿Qué es una amortización?", "Explícame el método avalancha",
            "Explícame el método bola de nieve",
            "¿Qué deuda conviene pagar primero?",
            "En general, ¿qué tarjeta conviene pagar antes?",
            "¿Qué pasa si una persona solo paga el mínimo?",
            "¿Cómo se hace un presupuesto mensual?",
            "¿Qué es la liquidez?", "¿Qué significa insolvencia?",
            "¿Cuándo se considera vencida una deuda?",
            "¿Cómo funcionan las mensualidades sin intereses?",
            "¿Qué son los cargos recurrentes?",
            "En México, ¿qué suele incluir un estado de cuenta?",
            "Hipotéticamente, ¿conviene refinanciar una deuda?",
            "¿Qué es una cuenta de nómina?"
        ]

        for pregunta in preguntas {
            let intencion = decidir(pregunta)
            XCTAssertEqual(
                intencion.ambito, .educacionFinanciera,
                "La explicación genérica se trató como dato personal: \(pregunta)")
            XCTAssertFalse(intencion.ambito.usaDatosPersonales, pregunta)
        }
    }

    func testFormasNaturalesDePreguntarPorDatosPropios() {
        let casos: [(String, MetricaConsultaClaro)] = [
            ("¿Cómo ando de dinero?", .panorama),
            ("¿Cómo ves mis finanzas?", .panorama),
            ("Dame mi panorama financiero", .panorama),
            ("¿Con cuánto efectivo cuento?", .disponibleReal),
            ("¿Cuál es mi saldo disponible?", .disponibleReal),
            ("¿Cuánto dinero tengo?", .disponibleReal),
            ("¿Cómo voy a cerrar el mes?", .proyeccionFinDeMes),
            ("¿Con cuánto termino el mes?", .proyeccionFinDeMes),
            ("¿Cuánto me quedará al fin de mes?", .proyeccionFinDeMes),
            ("¿Qué riesgo tengo?", .riesgo),
            ("¿Estoy en riesgo de quiebra?", .riesgo),
            ("¿Crees que haya riesgo de bancarrota?", .riesgo),
            ("¿Puedo pedir un préstamo?", .prestamo),
            ("¿Me conviene sacar un crédito?", .prestamo),
            ("¿Necesito evitar otro financiamiento?", .prestamo),
            ("¿Cuánto debo en total de mis tarjetas?", .deudaTotalTarjetas),
            ("Suma lo que debo en tarjetas", .deudaTotalTarjetas),
            ("¿Cuál de mis tarjetas tiene el saldo más grande?", .mayorDeudaTarjeta),
            ("¿En cuál debo más?", .mayorDeudaTarjeta),
            ("¿En cuál debo menos?", .menorDeudaTarjeta),
            ("¿Qué debo pagar antes?", .prioridadDePago),
            ("¿Cuál vence más pronto?", .prioridadDePago),
            ("¿Cuál es el mínimo de Hey Banco INC?", .pagoMinimo),
            ("Dime el pago mínimo de Liverpool", .pagoMinimo),
            ("¿Cuánto pago para no generar intereses en Hey Banco INC?", .pagoParaNoGenerarIntereses),
            ("¿Cuánto necesito para no pagar intereses en Liverpool?", .pagoParaNoGenerarIntereses),
            ("¿Cuál es el saldo al corte de Hey Banco INC?", .saldoAlCorte),
            ("¿Cuánto pagué del corte de Hey Banco INC?", .pagadoDelCorte),
            ("¿Cuánto falta por cubrir en Hey Banco INC?", .faltaDelCorte),
            ("¿Qué límite de crédito tiene BBVA Azul?", .limiteCredito),
            ("¿Cuánto crédito disponible tiene BBVA Oro?", .creditoDisponible),
            ("¿Qué día corta Hey Banco INC?", .fechaCorte),
            ("¿Cuándo vence Liverpool?", .fechaLimite),
            ("¿Cuánto debo en Bancomer?", .deudaTarjeta),
            ("Compara mis tarjetas", .deudaTarjeta),
            ("¿Cuánto tengo en mis cuentas?", .saldoCuenta),
            ("Suma mis cuentas BBVA", .saldoCuenta),
            ("¿Cuál es el saldo de Nómina Pensión?", .saldoCuenta),
            ("¿Cuánto recibí de Nómina CIAPACOV?", .ingresos),
            ("¿Cuánto llegó de mi pensión?", .ingresos),
            ("¿Quién me pagó?", .movimientos),
            ("Enséñame mis últimos movimientos", .movimientos),
            ("¿Cuánto gasté en comida?", .gastos),
            ("¿Puedo comprar algo de $5,000?", .gastos),
            ("¿Quién me debe más?", .porCobrarPersona),
            ("¿Cuánto me debe Alondra?", .porCobrarPersona),
            ("¿Cuánto le debo a BODOQUE?", .deudaConAcreedor),
            ("¿Cuál es mi patrimonio?", .patrimonio)
        ]

        for (pregunta, metrica) in casos {
            let intencion = decidir(pregunta)
            XCTAssertEqual(
                intencion.ambito, .finanzasPersonales,
                "No reconoció la pregunta personal: \(pregunta)")
            XCTAssertEqual(
                intencion.metrica, metrica,
                "Interpretó otra métrica: \(pregunta)")
        }
    }

    func testCambioDeTemaRompeElContextoAnterior() {
        let historial = [
            TurnoConversacionClaro(
                esUsuario: false, texto: "Hey Banco vence primero",
                ambito: .finanzasPersonales)
        ]
        let casos: [(String, AmbitoConsultaClaro)] = [
            ("Otro tema: ¿qué es Colima?", .general),
            ("Olvida eso: ¿cómo cocinar arroz?", .general),
            ("Eso está mal: dime el mínimo de Liverpool", .finanzasPersonales),
            ("No respondiste: ¿cuánto tengo en mis cuentas?", .finanzasPersonales),
            ("¿Qué es Liverpool?", .general),
            ("¿Y la otra tarjeta?", .finanzasPersonales),
            ("¿Y Hey Banco INC?", .finanzasPersonales)
        ]
        for (pregunta, ambito) in casos {
            XCTAssertEqual(
                decidir(pregunta, historial: historial).ambito,
                ambito, pregunta)
        }
    }

    func testPreguntaCompuestaConservaTodasLasMetricas() {
        let tarjeta = decidir(
            "¿Cuál es el pago mínimo y el PNGI de Hey Banco INC?")
        XCTAssertTrue(tarjeta.metricasSolicitadas.contains(.pagoMinimo))
        XCTAssertTrue(tarjeta.metricasSolicitadas.contains(
            .pagoParaNoGenerarIntereses))

        let comparacion = decidir("¿En cuál debo más y cuándo vence?")
        XCTAssertEqual(comparacion.metrica, .mayorDeudaTarjeta)
        XCTAssertTrue(comparacion.metricasSolicitadas.contains(.fechaLimite))
    }

    func testMotorExactoRespondeLasDosMitadesDePreguntaCompuesta() {
        let pregunta = "¿Cuál es el pago mínimo y el PNGI de Hey Banco INC?"
        let intencion = decidir(pregunta)
        let respuesta = MotorClaroInteligente.respuestaFactualExacta(
            intencion: intencion, pregunta: pregunta, resumen: resumen)
        XCTAssertNotNil(respuesta)
        XCTAssertTrue(respuesta?.contains("pago mínimo") == true, respuesta ?? "")
        XCTAssertTrue(
            respuesta?.contains("pago para no generar intereses") == true,
            respuesta ?? "")
    }

    private func decidir(
        _ pregunta: String,
        historial: [TurnoConversacionClaro] = []
    ) -> IntencionConsultaClaro {
        EnrutadorConsultaClaro.decidir(
            pregunta: pregunta, historial: historial, resumen: resumen).intencion
    }
}
