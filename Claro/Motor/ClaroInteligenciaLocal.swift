//
//  ClaroInteligenciaLocal.swift
//  Claro
//
//  Qwen o Apple Intelligence redactan la explicación, pero no hacen las
//  cuentas ni intervienen en la importación. El Motor local conserva siempre
//  la última palabra sobre cifras, riesgo y proyecciones.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum FuenteRespuestaClaro: String {
    case qwen4B = "Qwen3 4B · local"
    case appleIntelligence = "Apple Intelligence"
    case motorLocal = "Motor local"
}

enum AmbitoConsultaClaro: Equatable {
    case general
    case educacionFinanciera
    case finanzasPersonales

    var usaDatosPersonales: Bool { self == .finanzasPersonales }
    var usaFormatoAnalitico: Bool { self == .finanzasPersonales }

    var valorPersistente: String {
        switch self {
        case .general: "general"
        case .educacionFinanciera: "educacion"
        case .finanzasPersonales: "personal"
        }
    }

    init(valorPersistente: String) {
        switch valorPersistente {
        case "educacion": self = .educacionFinanciera
        case "personal": self = .finanzasPersonales
        default: self = .general
        }
    }
}

struct RespuestaClaroInteligente {
    let texto: String
    let fuente: FuenteRespuestaClaro
    let ambito: AmbitoConsultaClaro
}

struct TurnoConversacionClaro {
    let esUsuario: Bool
    let texto: String
    let ambito: AmbitoConsultaClaro
}

private struct LecturaSemanticaClaro {
    let ambito: AmbitoConsultaClaro
    let objetivo: String
    let datosNecesarios: String

    var textoParaModelo: String {
        let datos = datosNecesarios.trimmingCharacters(in: .whitespacesAndNewlines)
        return datos.isEmpty
            ? "Objetivo: \(objetivo)"
            : "Objetivo: \(objetivo)\nDatos que deben revisarse: \(datos)"
    }
}

enum ClaroInteligenciaLocal {

    static let instruccionesGenerales = """
    Eres Claro Inteligente, un asistente local, privado y conversacional. Hablas en español mexicano natural, amable y directo.

    REGLAS OBLIGATORIAS:
    - Responde exactamente a lo que el usuario acaba de decir o preguntar.
    - Si te saluda, saluda de forma natural. Si pregunta cómo estás, contesta esa pregunta. No conviertas una charla casual en un análisis financiero.
    - Puedes conversar y responder preguntas generales usando el conocimiento incluido en tu modelo.
    - No afirmes tener internet, noticias en tiempo real ni conocimiento posterior a tu entrenamiento.
    - No menciones las finanzas personales del usuario salvo que la pregunta actual sea financiera.
    - El mensaje actual manda sobre el historial. Si el usuario cambia de tema, conversa sobre el tema nuevo; nunca arrastres un diagnóstico financiero anterior.
    - Si el usuario indica que no respondiste lo preguntado, reconoce el error y atiende su mensaje actual. No vuelvas a mostrar el análisis anterior.
    - No inventes hechos. Si no sabes algo, dilo claramente y ofrece lo que sí sabes.
    - Contesta primero; no obligues al usuario a llenar formularios ni hagas preguntas preliminares innecesarias.
    - Usa Markdown solo cuando realmente ayude. Para saludos y charla casual responde en una o dos frases naturales, sin títulos ni listas.
    """

    static let instruccionesDelCopiloto = """
    Eres Claro Inteligente, asesor financiero personal experto y privado. Dominas presupuesto, flujo de efectivo, crédito, deudas, pagos, ahorro, riesgo y proyecciones. Hablas en español mexicano y respondes con seguridad, franqueza y precisión.

    REGLAS OBLIGATORIAS:
    - La pregunta actual del usuario es la autoridad principal. Identifica su intención, las entidades mencionadas, el periodo y la operación solicitada antes de responder.
    - Contesta exactamente lo preguntado. Si pide un nombre, da el nombre; si pide una cifra, da la cifra; si pide comparar u ordenar, compara u ordena todos los elementos pertinentes; si pide una explicación, explica esa causa concreta.
    - Contesta de inmediato. La primera frase debe dar la respuesta o conclusión concreta que corresponda.
    - No hagas preguntas preliminares y no obligues al usuario a llenar cuestionarios.
    - Para la situación personal del usuario, usa solamente los hechos y resultados entregados por el motor financiero. No inventes movimientos, tasas, ingresos, saldos ni fechas.
    - Puedes responder preguntas financieras generales con tu conocimiento, pero distingue claramente una explicación general de los datos personales realmente registrados.
    - Puedes buscar, filtrar, comparar y ordenar los datos entregados. Nunca hagas aritmética con montos: cita únicamente cifras y totales ya calculados por el motor. Si un total no está entregado, dilo sin inventarlo.
    - Distingue dinero disponible hoy de ingresos esperados; saldo de una cuenta de límite de crédito; y deuda vigente de gastos proyectados.
    - Al evaluar un préstamo o compra, considera flujo disponible, pagos próximos, deuda, margen mensual, riesgo y proyección de cierre. Expón cualquier supuesto después del veredicto.
    - Puedes dar una opinión clara como “yo no lo tomaría” o “sí parece viable”.
    - Si falta información, responde con la mejor estimación disponible y menciona la suposición después de la respuesta; no detengas la respuesta.
    - Nunca sustituyas una pregunta específica por un panorama financiero genérico.
    - Usa el historial financiero para resolver referencias naturales como “esa tarjeta”, “el mes pasado” o “¿y si pago eso?”.
    - Distingue riesgo financiero estimado de una declaración legal de bancarrota.
    - Sé breve. Muestra primero lo importante y luego la evidencia.
    - Escribe todos los montos con signo de pesos para que el modo privacidad pueda ocultarlos.
    - No incluyas avisos genéricos, sermones ni frases paternalistas.

    FORMATO OBLIGATORIO PARA LA PANTALLA:
    - Usa Markdown sencillo y deja una línea vacía entre secciones.
    - Para un análisis o recomendación de más de tres frases, usa esta estructura:
      ## Veredicto
      Una conclusión directa de una o dos frases.
      ## Cifras clave
      De dos a cinco viñetas breves con las cifras que realmente sostienen la conclusión.
      ## Qué haría
      De uno a tres pasos numerados, concretos y en orden de prioridad.
    - Para una consulta factual o comparación sencilla, responde directamente con una frase, lista o tabla breve; no fuerces las tres secciones.
    - Si la pregunta no necesita las tres secciones, usa párrafos cortos separados; nunca entregues un muro de texto.
    - Usa **negritas** solo para conclusiones, alertas y cifras especialmente importantes.
    """

    static let instruccionesEducativas = """
    Eres Claro Inteligente. Explicas educación financiera en español mexicano,
    con claridad, precisión y ejemplos sencillos.

    REGLAS OBLIGATORIAS:
    - Responde exactamente la pregunta actual.
    - Esta consulta es general: no supongas que habla de las cuentas, tarjetas,
      deudas o situación personal del usuario.
    - No inventes tasas, productos bancarios actuales ni datos en tiempo real.
    - Distingue claramente una definición general de una recomendación personal.
    - Sé breve y usa una lista solo cuando facilite la comprensión.
    - No muestres un diagnóstico, riesgo, patrimonio ni deudas del usuario.
    """

    private static var appleIntelligenceDisponible: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *),
           case .available = SystemLanguageModel.default.availability,
           SystemLanguageModel.default.supportsLocale(
            Locale(identifier: "es_MX")) {
            return true
        }
        #endif
        return false
    }

    static var nombreMotorDisponible: String {
        if appleIntelligenceDisponible && AdministradorQwen.shared.estaDescargado {
            return "Apple + Qwen 4B"
        }
        if appleIntelligenceDisponible { return "Apple Intelligence · local" }
        if AdministradorQwen.shared.estaDescargado { return "Qwen3 4B · local" }
        return "Motor financiero · local"
    }

    static func responder(pregunta: String,
                          resumen: ResumenFinancieroClaro,
                          historial: [TurnoConversacionClaro]) async -> RespuestaClaroInteligente {
        let decisionLocal = EnrutadorConsultaClaro.decidir(
            pregunta: pregunta, historial: historial, resumen: resumen)
        var intencion = decisionLocal.intencion
        let qwenYaEstabaOcupado =
            AdministradorQwen.shared.bloqueaOtroModeloEnMemoria

        // Apple únicamente desempata lenguaje ambiguo. Una decisión local de
        // alta confianza nunca se sustituye y las respuestas factuales no se
        // ejecutan hasta confirmar que se piden datos personales.
        let lecturaSemantica = decisionLocal.requiereInterpretacionSemantica
            && !qwenYaEstabaOcupado
            ? await interpretarConsultaConApple(
                pregunta: pregunta,
                historial: historial,
                incluirHistorialFinanciero: intencion.dependeDelHistorial)
            : nil
        if let lecturaSemantica {
            intencion = IntencionConsultaClaro(
                ambito: lecturaSemantica.ambito,
                acto: intencion.acto,
                metrica: intencion.metrica,
                metricasSolicitadas: intencion.metricasSolicitadas,
                entidades: intencion.entidades,
                dependeDelHistorial: intencion.dependeDelHistorial,
                pideTotal: intencion.pideTotal,
                pideComparacion: intencion.pideComparacion,
                esEspecifica: intencion.esEspecifica)
        }
        let ambito = intencion.ambito

        if ambito == .finanzasPersonales,
           let exacta = HerramientasFinancierasClaro.ejecutar(
            intencion: intencion, pregunta: pregunta, resumen: resumen) {
            return RespuestaClaroInteligente(
                texto: exacta.texto, fuente: .motorLocal, ambito: ambito)
        }

        let respaldo: String
        let solicitud: String
        let instrucciones: String

        switch ambito {
        case .finanzasPersonales:
            respaldo = MotorClaroInteligente.responderConReglas(
                intencion: intencion, pregunta: pregunta, resumen: resumen)
            solicitud = solicitudDelCopiloto(
                pregunta: pregunta, resumen: resumen,
                interpretacion: lecturaSemantica?.textoParaModelo,
                historial: historial)
            instrucciones = instruccionesDelCopiloto
        case .educacionFinanciera:
            respaldo = respuestaEducativaDeRespaldo(pregunta)
            solicitud = solicitudEducativa(
                pregunta: pregunta, historial: historial)
            instrucciones = instruccionesEducativas
        case .general:
            respaldo = respuestaGeneralDeRespaldo(pregunta)
            solicitud = solicitudGeneral(
                pregunta: pregunta, historial: historial)
            instrucciones = instruccionesGenerales
        }

        // Apple Intelligence atiende primero la conversación cotidiana: es
        // rápido, está integrado al sistema y no necesita el resumen privado.
        if ambito != .finanzasPersonales, !qwenYaEstabaOcupado,
           let textoApple = await intentarConAppleIntelligence(
            solicitud: solicitud,
            instrucciones: instrucciones
                + "\nIDENTIDAD: eres Claro Inteligente usando Apple Intelligence local.") {
            return RespuestaClaroInteligente(
                texto: textoApple, fuente: .appleIntelligence, ambito: ambito)
        }

        // Si Apple descubrió una intención financiera en una frase ambigua,
        // Apple responde también. Así esa consulta nunca comparte memoria con
        // Qwen, pero conserva toda la información financiera estructurada.
        if ambito == .finanzasPersonales, lecturaSemantica != nil,
           let textoApple = await intentarConAppleIntelligence(
            solicitud: solicitud,
            instrucciones: instrucciones
                + "\nIDENTIDAD: eres Claro Inteligente usando Apple Intelligence local.") {
            if respuestaFinancieraEsConsistente(
                textoApple, intencion: intencion,
                pregunta: pregunta, resumen: resumen) {
                return RespuestaClaroInteligente(
                    texto: textoApple, fuente: .appleIntelligence, ambito: ambito)
            }
            return RespuestaClaroInteligente(
                texto: respaldo, fuente: .motorLocal, ambito: ambito)
        }

        // Las consultas claramente financieras usan Qwen de forma exclusiva.
        // Se carga desde disco aquí y se libera por completo al responder.
        if ambito == .finanzasPersonales,
           lecturaSemantica == nil,
           AdministradorQwen.shared.estaDescargado {
            do {
                if let texto = try await intentarConQwenExclusivo(
                    solicitud: solicitud,
                    instrucciones: instrucciones
                        + "\nIDENTIDAD: eres Claro Inteligente y el modelo local que te impulsa es Qwen3 4B.",
                    requiereRazonamiento: ambito == .finanzasPersonales
                        && requiereRazonamientoProfundo(pregunta)),
                   !texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   respuestaFinancieraEsConsistente(
                    texto, intencion: intencion,
                    pregunta: pregunta, resumen: resumen) {
                    return RespuestaClaroInteligente(
                        texto: texto, fuente: .qwen4B, ambito: ambito)
                }
            } catch {
                // No se activa Apple inmediatamente después de un fallo de
                // Qwen: primero se libera el modelo y se usa el Motor local.
            }
            return RespuestaClaroInteligente(
                texto: respaldo, fuente: .motorLocal, ambito: ambito)
        }

        // Apple atiende finanzas cuando Qwen no está descargado. No existe
        // ningún contenedor MLX residente en este camino.
        if let textoApple = await intentarConAppleIntelligence(
            solicitud: solicitud,
            instrucciones: instrucciones
                + "\nIDENTIDAD: eres Claro Inteligente usando Apple Intelligence local.") {
            if ambito != .finanzasPersonales || respuestaFinancieraEsConsistente(
                textoApple, intencion: intencion,
                pregunta: pregunta, resumen: resumen) {
                return RespuestaClaroInteligente(
                    texto: textoApple, fuente: .appleIntelligence, ambito: ambito)
            }
        }
        return RespuestaClaroInteligente(
            texto: respaldo, fuente: .motorLocal, ambito: ambito)
    }

    private static func intentarConQwenExclusivo(
        solicitud: String,
        instrucciones: String,
        requiereRazonamiento: Bool
    ) async throws -> String? {
        guard let reserva = await CoordinadorInferenciaClaro.shared.reservar(.qwen)
        else { return nil }
        do {
            if !AdministradorQwen.shared.estaListo {
                await AdministradorQwen.shared.prepararSiEstaDescargado()
            }
            guard AdministradorQwen.shared.estaListo else {
                await CoordinadorInferenciaClaro.shared.liberar(reserva)
                return nil
            }
            let texto = try await AdministradorQwen.shared.responder(
                solicitud: solicitud,
                instrucciones: instrucciones,
                requiereRazonamiento: requiereRazonamiento)
            // AdministradorQwen ya sincronizó, soltó el contenedor y limpió
            // MLX antes de regresar. Solo entonces se habilita Apple.
            await CoordinadorInferenciaClaro.shared.liberar(reserva)
            return texto
        } catch {
            await CoordinadorInferenciaClaro.shared.liberar(reserva)
            throw error
        }
    }

    static func solicitudDelCopiloto(
        pregunta: String,
        resumen: ResumenFinancieroClaro,
        interpretacion: String?,
        historial: [TurnoConversacionClaro]) -> String {
        let preguntaSegura = textoAcotado(pregunta, maximo: 1_200)
        let conversacion = historialParaModelo(
            historial, ambito: .finanzasPersonales,
            limiteTurnos: 4,
            maximoCaracteresPorTurno: 500)
        let objetivo = interpretacion.map {
            textoAcotado(
                $0.trimmingCharacters(in: .whitespacesAndNewlines),
                maximo: 1_000)
        }
        let consultaParaDatos = [preguntaSegura, objetivo]
            .compactMap { $0 }
            .joined(separator: " ")
        return """
        PREGUNTA ACTUAL — ES LA AUTORIDAD PRINCIPAL:
        \(preguntaSegura)

        LECTURA SEMÁNTICA AUXILIAR DE APPLE:
        \(objetivo?.isEmpty == false ? objetivo! : "No disponible; interpreta directamente la pregunta original.")

        CONVERSACIÓN FINANCIERA RECIENTE:
        \(conversacion.isEmpty ? "Sin conversación anterior." : conversacion)

        HECHOS REGISTRADOS Y CÁLCULOS DE LA APP:
        \(resumen.contextoParaModelo(consulta: consultaParaDatos))

        TAREA:
        Resuelve la pregunta actual, no un tema parecido ni un diagnóstico genérico. Usa únicamente los hechos anteriores para hablar de las finanzas personales. Si la respuesta exige una comparación, revisa cada renglón pertinente antes de concluir. Respeta el formato visual indicado en tus instrucciones.
        """
    }

    static func ambitoDeLaConsulta(_ pregunta: String) -> AmbitoConsultaClaro {
        EnrutadorConsultaClaro.decidir(
            pregunta: pregunta, historial: [], resumen: nil).intencion.ambito
    }

    /// Una frase breve puede depender de una respuesta financiera anterior
    /// ("¿y esa?", "¿por qué?", "¿me conviene?"). El historial solo se usa
    /// en esos casos. Una corrección o un tema autocontenido nunca hereda el
    /// ámbito anterior; esto evita que el chat quede atrapado en finanzas.
    private static func esSeguimientoFinanciero(
        _ pregunta: String,
        historial: [TurnoConversacionClaro]) -> Bool {
        guard historial.last?.ambito == .finanzasPersonales else { return false }
        let texto = normalizar(pregunta)
        guard !texto.isEmpty,
              !esCorreccionOCambioDeTema(texto),
              !mensajeGeneralObvio(pregunta) else { return false }

        let palabras = texto.split(separator: " ").map(String.init)
        let referencias: Set<String> = [
            "eso", "esa", "ese", "esas", "esos", "aquella", "aquel",
            "anterior", "misma", "mismo", "otra", "otro"
        ]
        if !Set(palabras).isDisjoint(with: referencias) { return true }
        if palabras.first == "y" || palabras.first == "entonces" { return true }

        let seguimientosBreves: Set<String> = [
            "por que", "como", "cuanto", "cuanto seria", "cual", "cuales",
            "me conviene", "que recomiendas", "que hago"
        ]
        return palabras.count <= 4 && seguimientosBreves.contains(texto)
    }

    private static func esCorreccionOCambioDeTema(_ texto: String) -> Bool {
        let correcciones = [
            "no te pregunte", "eso no pregunte", "no era eso",
            "no respondiste", "cambia de tema", "otro tema"
        ]
        return correcciones.contains(where: texto.contains)
    }

    private static func mensajeGeneralObvio(_ pregunta: String) -> Bool {
        let texto = normalizar(pregunta)
        if esCorreccionOCambioDeTema(texto) { return true }
        let palabras = Set(texto.split(separator: " ").map(String.init))
        let palabrasCasuales: Set<String> = [
            "hola", "holi", "buenas", "buenos", "dias", "tardes", "noches",
            "como", "estas", "esta", "vas", "que", "tal", "quien", "eres",
            "gracias", "ok", "okay", "oye", "bien", "mal", "yo", "tu", "y",
            "tambien", "me", "alegra"
        ]
        if !palabras.isEmpty && palabras.isSubset(of: palabrasCasuales) {
            return true
        }

        // Las preguntas autocontenidas de definición o cultura general no
        // necesitan examinar el historial. Si contienen vocabulario
        // financiero inequívoco, ambitoDeLaConsulta ya las habrá separado.
        var temaActual = texto
        for conector in ["y ", "entonces ", "ahora "] {
            if temaActual.hasPrefix(conector) {
                temaActual.removeFirst(conector.count)
                break
            }
        }
        let iniciosAutocontenidos = [
            "que es ", "que significa ", "quien es ",
            "donde esta ", "donde queda ",
            "hablame de ", "cuentame sobre "
        ]
        let pideOtroTema = temaActual.hasPrefix("cuentame otra cosa")
            || temaActual.hasPrefix("hablemos de ")
        return ambitoDeLaConsulta(pregunta) == .general
            && (pideOtroTema
                || iniciosAutocontenidos.contains(where: temaActual.hasPrefix))
    }

    private static func solicitudGeneral(
        pregunta: String,
        historial: [TurnoConversacionClaro]) -> String {
        let conversacion = historialParaModelo(
            historial, ambito: .general,
            limiteTurnos: 4,
            maximoCaracteresPorTurno: 700)
        return """
        CONVERSACIÓN GENERAL RECIENTE:
        \(conversacion.isEmpty ? "Sin conversación anterior relacionada." : conversacion)

        MENSAJE ACTUAL DEL USUARIO:
        \(textoAcotado(pregunta, maximo: 2_000))

        Responde al mensaje actual de forma natural. No analices ni menciones sus finanzas a menos que el mensaje actual lo pida explícitamente.
        """
    }

    private static func solicitudEducativa(
        pregunta: String,
        historial: [TurnoConversacionClaro]) -> String {
        let conversacion = historialParaModelo(
            historial, ambito: .educacionFinanciera,
            limiteTurnos: 4,
            maximoCaracteresPorTurno: 600)
        return """
        CONVERSACIÓN DE EDUCACIÓN FINANCIERA RECIENTE:
        \(conversacion.isEmpty ? "Sin conversación anterior relacionada." : conversacion)

        PREGUNTA ACTUAL:
        \(textoAcotado(pregunta, maximo: 2_000))

        Explica exactamente esto como conocimiento financiero general. No uses,
        infieras ni menciones datos personales del usuario.
        """
    }

    private static func historialParaModelo(
        _ historial: [TurnoConversacionClaro],
        ambito: AmbitoConsultaClaro,
        limiteTurnos: Int,
        maximoCaracteresPorTurno: Int) -> String {
        historial
            .filter { $0.ambito == ambito }
            .suffix(limiteTurnos)
            .map { turno in
                let recortado = String(turno.texto.prefix(maximoCaracteresPorTurno))
                return "\(turno.esUsuario ? "USUARIO" : "CLARO"): \(recortado)"
            }
            .joined(separator: "\n")
    }

    private static func textoAcotado(_ texto: String, maximo: Int) -> String {
        guard texto.count > maximo else { return texto }
        return String(texto.prefix(maximo))
            + "\n[Texto adicional omitido para proteger la memoria]"
    }

    private static func respuestaGeneralDeRespaldo(_ pregunta: String) -> String {
        let texto = normalizar(pregunta)
        if esCorreccionOCambioDeTema(texto) {
            return "Tienes razón: respondí algo distinto a lo que dijiste. Dejemos ese análisis atrás; vuelve a preguntarme y atenderé exactamente tu mensaje."
        }
        if texto.contains("hola") || texto == "buenas" {
            return "¡Hola! Aquí estoy. Puedes preguntarme sobre tus finanzas o conversar conmigo sobre otro tema."
        }
        if texto.contains("como estas") || texto.contains("que tal") {
            return "Estoy muy bien y listo para conversar contigo. ¿Qué quieres saber?"
        }
        if texto.contains("bien") && (texto.contains(" y tu") || texto == "bien") {
            return "Qué bueno. Yo estoy bien también, gracias."
        }
        if texto.contains("gracias") {
            return "¡Con gusto!"
        }
        return "Puedo conversar contigo sobre ese tema, pero el modelo local no produjo una respuesta en este intento."
    }

    private static func respuestaEducativaDeRespaldo(_ pregunta: String) -> String {
        let texto = normalizar(pregunta)
        if texto.contains("pago para no generar intereses") {
            return "El pago para no generar intereses es la cantidad que debes cubrir antes de la fecha límite para evitar intereses sobre las compras del periodo."
        }
        if texto.contains("pago minimo") {
            return "El pago mínimo evita caer en incumplimiento inmediato, pero normalmente deja saldo sujeto a intereses; no equivale a liquidar el corte."
        }
        if texto.contains("saldo al corte") {
            return "El saldo al corte es lo que el banco reporta como adeudo al cerrar un periodo del estado de cuenta."
        }
        if texto.contains("cat") {
            return "El CAT es una medida anual que ayuda a comparar el costo total de distintos créditos, incluyendo intereses y varios cargos asociados."
        }
        return "No pude generar una explicación confiable en este intento. La pregunta se mantuvo separada de tus datos personales."
    }

    private static func normalizar(_ texto: String) -> String {
        texto
            .folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "es_MX"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func requiereRazonamientoProfundo(_ pregunta: String) -> Bool {
        let texto = pregunta.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                     locale: Locale(identifier: "es_MX"))
        let temas = [
            "prestamo", "credito", "bancarrota", "quiebra", "riesgo",
            "proyeccion", "fin de mes", "viable", "deuda", "financiar"
        ]
        return temas.contains { texto.contains($0) }
    }

    /// Apple no contesta aquí: únicamente convierte lenguaje natural en un
    /// objetivo preciso. Así Qwen puede razonar sobre cualquier consulta sin
    /// depender de una lista creciente de frases programadas a mano.
    private static func interpretarConsultaConApple(
        pregunta: String,
        historial: [TurnoConversacionClaro],
        incluirHistorialFinanciero: Bool) async -> LecturaSemanticaClaro? {
        guard !AdministradorQwen.shared.bloqueaOtroModeloEnMemoria,
              let reserva = await CoordinadorInferenciaClaro.shared.reservar(.apple)
        else { return nil }
        guard !AdministradorQwen.shared.bloqueaOtroModeloEnMemoria else {
            await CoordinadorInferenciaClaro.shared.liberar(reserva)
            return nil
        }
        let lectura = await interpretarConsultaConAppleSinReserva(
            pregunta: pregunta,
            historial: historial,
            incluirHistorialFinanciero: incluirHistorialFinanciero)
        await CoordinadorInferenciaClaro.shared.liberar(reserva)
        return lectura
    }

    private static func interpretarConsultaConAppleSinReserva(
        pregunta: String,
        historial: [TurnoConversacionClaro],
        incluirHistorialFinanciero: Bool) async -> LecturaSemanticaClaro? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), appleIntelligenceDisponible {
            let conversacion = incluirHistorialFinanciero
                ? historialParaModelo(
                    historial, ambito: .finanzasPersonales,
                    limiteTurnos: 4,
                    maximoCaracteresPorTurno: 500)
                : ""
            do {
                let sesion = LanguageModelSession(instructions: """
                Eres el enrutador semántico de Claro Inteligente. No respondas
                ni calcules cifras. Distingue tres categorías: conversación o
                cultura general; educación financiera sin datos del usuario;
                y finanzas personales que sí requieren sus registros. Una
                definición o estrategia genérica nunca usa datos personales.
                Saludos, correcciones y cambios de tema tampoco. Usa historial
                solo para referencias dependientes como «eso» o «¿y si...?». No
                inventes nombres ni datos.
                """)
                let peticion = """
                PREGUNTA ACTUAL:
                \(textoAcotado(pregunta, maximo: 2_000))

                CONTEXTO ANTERIOR PARA RESOLVER REFERENCIAS:
                \(conversacion.isEmpty ? "No se proporciona porque la pregunta debe clasificarse por sí sola." : conversacion)

                REGLA FINAL: el tema explícito de la pregunta actual siempre reemplaza al tema anterior.
                """
                let respuesta = try await sesion.respond(
                    to: peticion,
                    generating: InterpretacionConsultaFinanciera.self)
                let objetivo = respuesta.content.objetivo
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let datos = respuesta.content.datosNecesarios
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !objetivo.isEmpty else { return nil }
                let ambito: AmbitoConsultaClaro
                if respuesta.content.usaDatosFinancierosPersonales {
                    ambito = .finanzasPersonales
                } else if respuesta.content.esEducacionFinanciera {
                    ambito = .educacionFinanciera
                } else {
                    ambito = .general
                }
                return LecturaSemanticaClaro(
                    ambito: ambito,
                    objetivo: objetivo,
                    datosNecesarios: datos)
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    /// La validación relaciona cada importe con la entidad que aparece en el
    /// mismo fragmento. No basta con que una cifra exista "en algún lugar":
    /// intercambiar BBVA Azul y BBVA Oro invalida toda la redacción.
    static func respuestaFinancieraEsConsistente(
        _ respuesta: String,
        intencion: IntencionConsultaClaro,
        pregunta: String,
        resumen r: ResumenFinancieroClaro) -> Bool {
        guard intencion.ambito == .finanzasPersonales else { return true }
        if contieneMontoEscritoConPalabras(respuesta) { return false }

        let respuestaNormalizada = EnrutadorConsultaClaro.normalizar(respuesta)
        if intencion.esEspecifica && [
            "no se", "no lo se", "no tengo acceso", "no puedo saber",
            "no tengo esa informacion", "no puedo determinar"
        ].contains(where: { respuestaNormalizada.contains($0) }) {
            return false
        }

        let encontrados = montosEn(respuesta)
        var permitidosGlobales = valoresGlobalesPermitidos(r)
        if intencion.metrica == .prestamo
            || EnrutadorConsultaClaro.normalizar(pregunta).contains("y si") {
            permitidosGlobales += montosEn(pregunta)
        }

        guard encontrados.allSatisfy({ coincide($0, en: permitidosGlobales) })
        else { return false }

        let esperados = valoresEsperadosParaLaConsulta(
            intencion: intencion, resumen: r)
        if !esperados.isEmpty && !encontrados.isEmpty,
           !encontrados.allSatisfy({ coincide($0, en: esperados) }) {
            return false
        }

        let fragmentos = respuesta
            .components(separatedBy: CharacterSet.newlines)
            .flatMap { $0.components(separatedBy: ";") }
        for fragmento in fragmentos {
            let montos = montosEn(fragmento)
            guard !montos.isEmpty else { continue }
            let entidades = entidadesEnRespuesta(fragmento, resumen: r)
            if entidades.count == 1, let entidad = entidades.first {
                let valores = valoresPermitidos(
                    de: entidad, metrica: intencion.metrica, resumen: r)
                guard montos.allSatisfy({ coincide($0, en: valores) })
                else { return false }
            } else if entidades.count > 1 {
                // La asociación entre varios nombres y varios importes en una
                // misma frase es ambigua. El prompt exige un renglón por
                // entidad; si no lo respetó se usa el Motor exacto.
                return false
            }
        }

        let porcentajes = porcentajesEn(respuesta)
        var porcentajesPermitidos: [Double] = []
        if let uso = r.utilizacionCredito {
            porcentajesPermitidos.append((uso * 100).rounded())
        }
        if intencion.metrica == .prestamo {
            porcentajesPermitidos += porcentajesEn(pregunta)
        }
        guard porcentajes.allSatisfy({ coincide($0, en: porcentajesPermitidos) })
        else { return false }

        if respuestaNormalizada.contains("cortes vencidos")
            || respuestaNormalizada.contains("corte vencido") {
            let conteos = enterosAntesDe(
                patrones: ["cortes vencidos", "corte vencido"],
                en: respuestaNormalizada)
            if !conteos.isEmpty && !conteos.allSatisfy({ $0 == r.estadosVencidos }) {
                return false
            }
        }
        if let expresion = try? NSRegularExpression(
            pattern: #"\b(\d{1,3})\s*/\s*100\b"#) {
            let ns = respuesta as NSString
            for coincidencia in expresion.matches(
                in: respuesta, range: NSRange(location: 0, length: ns.length)) {
                guard coincidencia.numberOfRanges > 1,
                      let puntos = Int(ns.substring(
                        with: coincidencia.range(at: 1))),
                      puntos == r.puntuacionRiesgo else { return false }
            }
        }
        return true
    }

    static func montosEn(_ texto: String) -> [Double] {
        // Los modelos pueden usar el signo menos tipográfico (−) y cerrar
        // una cifra con punto. Ambos casos deben validarse igual que «-» y
        // no convertirse silenciosamente en una respuesta sin importes.
        let texto = texto
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        let ns = texto as NSString
        let rangoCompleto = NSRange(location: 0, length: ns.length)
        let rangosFecha = (try? NSRegularExpression(
            pattern: #"\b\d{1,2}[./-]\d{1,2}[./-]\d{2,4}\b"#))?
            .matches(in: texto, range: rangoCompleto).map(\.range) ?? []
        guard let expresion = try? NSRegularExpression(
            pattern: #"(?i)(?:-?\s*(?:\$|MXN)\s*-?\s*\d[\d,.]*(?:\s*(?:mil|k))?|(?<![\p{L}\p{N}])-?\d[\d,.]*\s*(?:mil|k|pesos?|MXN)\b|(?<![\p{L}\p{N}])-?\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?\b|(?<![\p{L}\p{N}])-?\d+\.\d{2}(?!\s*%)|(?<![\p{L}\p{N}])-?\d{4,}\b)"#)
        else { return [] }
        return expresion.matches(in: texto, range: rangoCompleto).compactMap {
            coincidencia -> Double? in
            guard !rangosFecha.contains(where: {
                NSIntersectionRange($0, coincidencia.range).length > 0
            }) else { return nil }
            let original = ns.substring(with: coincidencia.range).lowercased()
            let negativo = original.contains("-")
            let usaMiles = original.contains("mil")
                || original.range(of: #"\d\s*k\b"#,
                                  options: .regularExpression) != nil
            var limpio = original
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: "mxn", with: "")
                .replacingOccurrences(of: "pesos", with: "")
                .replacingOccurrences(of: "peso", with: "")
                .replacingOccurrences(of: "mil", with: "")
                .replacingOccurrences(of: "k", with: "")
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: "-", with: "")
                .trimmingCharacters(in: .whitespaces)
            limpio = limpio.replacingOccurrences(of: " ", with: "")
            while limpio.hasSuffix(".") || limpio.hasSuffix(",") {
                limpio.removeLast()
            }
            guard let base = Double(limpio) else { return nil }
            let valor = base * (usaMiles ? 1_000 : 1)
            // Un año aislado no es un importe.
            if !original.contains("$") && !original.contains("mxn")
                && !original.contains("peso") && !usaMiles
                && valor.rounded() == valor && (1900...2100).contains(Int(valor)) {
                return nil
            }
            return negativo ? -valor : valor
        }
    }

    private static func valoresGlobalesPermitidos(
        _ r: ResumenFinancieroClaro
    ) -> [Double] {
        var valores: [Double] = [
            r.saldoLiquido, r.comprometidoTarjetas, r.disponibleReal,
            r.deudaTarjetas, r.limiteTarjetas, r.deudasPersonales, r.porCobrar,
            r.patrimonio, r.ingresoMesActual, r.gastoMesActual,
            r.ingresoMensualEstimado, r.gastoMensualEstimado,
            r.flujoMensualEstimado, r.proyeccionFinDeMes,
            r.pagosAntesDeFinDeMes, r.pagosProximos30Dias,
            r.cargaMinimaDeudaMensual, r.capacidadMensualPrestamo,
            r.compromisoFuturoMSI, r.compromisoMensualMSI,
            r.deudaTarjetas + r.deudasPersonales,
            r.saldoLiquido + r.porCobrar
        ]
        valores += r.detalleTarjetas.flatMap { tarjeta in
            [tarjeta.deuda, tarjeta.limite, tarjeta.creditoDisponible,
             tarjeta.saldoAlCorte, tarjeta.pagoParaNoGenerarIntereses,
             tarjeta.pagoMinimo, tarjeta.pagadoDelCorte,
             Optional(tarjeta.faltaCorte)].compactMap { $0 }
        }
        valores += r.detalleCuentas.map(\.saldo)
        valores += r.detallePersonas.map(\.pendiente)
        valores += r.detalleDeudas.map(\.saldo)
        valores += r.detalleMovimientos.map(\.monto)
        valores += r.categoriasPrincipales.map(\.monto)
        valores += r.cargosRecurrentes.map(\.promedio)
        return valores
    }

    private static func entidadesEnRespuesta(
        _ texto: String, resumen r: ResumenFinancieroClaro
    ) -> [ReferenciaEntidadClaro] {
        let normalizado = EnrutadorConsultaClaro.normalizar(texto)
        var entidades: [ReferenciaEntidadClaro] = []
        for tarjeta in r.detalleTarjetas
            where contieneNombreCompleto(tarjeta.nombre, en: normalizado) {
            entidades.append(.init(tipo: .tarjeta, nombre: tarjeta.nombre))
        }
        for cuenta in r.detalleCuentas
            where contieneNombreCompleto(cuenta.nombre, en: normalizado) {
            entidades.append(.init(tipo: .cuenta, nombre: cuenta.nombre))
        }
        for persona in r.detallePersonas
            where contieneNombreCompleto(persona.nombre, en: normalizado) {
            entidades.append(.init(tipo: .persona, nombre: persona.nombre))
        }
        for deuda in r.detalleDeudas
            where contieneNombreCompleto(deuda.acreedor, en: normalizado) {
            entidades.append(.init(tipo: .acreedor, nombre: deuda.acreedor))
        }
        return entidades
    }

    private static func valoresPermitidos(
        de entidad: ReferenciaEntidadClaro,
        metrica: MetricaConsultaClaro,
        resumen r: ResumenFinancieroClaro
    ) -> [Double] {
        switch entidad.tipo {
        case .tarjeta:
            guard let tarjeta = r.detalleTarjetas.first(where: {
                $0.nombre == entidad.nombre
            }) else { return [] }
            switch metrica {
            case .deudaTarjeta, .mayorDeudaTarjeta, .menorDeudaTarjeta:
                return [tarjeta.deuda]
            case .saldoAlCorte:
                return [tarjeta.saldoAlCorte].compactMap { $0 }
            case .pagoParaNoGenerarIntereses:
                return [tarjeta.pagoParaNoGenerarIntereses].compactMap { $0 }
            case .pagoMinimo:
                return [tarjeta.pagoMinimo].compactMap { $0 }
            case .pagadoDelCorte:
                return [tarjeta.pagadoDelCorte].compactMap { $0 }
            case .faltaDelCorte, .prioridadDePago:
                return [tarjeta.faltaCorte]
            case .limiteCredito:
                return [tarjeta.limite]
            case .creditoDisponible:
                return [tarjeta.creditoDisponible]
            default:
                break
            }
            return [tarjeta.deuda, tarjeta.limite, tarjeta.creditoDisponible,
                    tarjeta.saldoAlCorte,
                    tarjeta.pagoParaNoGenerarIntereses,
                    tarjeta.pagoMinimo, tarjeta.pagadoDelCorte,
                    Optional(tarjeta.faltaCorte)].compactMap { $0 }
        case .cuenta:
            return r.detalleCuentas.filter { $0.nombre == entidad.nombre }.map(\.saldo)
        case .persona:
            return r.detallePersonas.filter { $0.nombre == entidad.nombre }.map(\.pendiente)
        case .acreedor:
            return r.detalleDeudas.filter { $0.acreedor == entidad.nombre }.map(\.saldo)
        }
    }

    private static func valoresEsperadosParaLaConsulta(
        intencion: IntencionConsultaClaro,
        resumen r: ResumenFinancieroClaro
    ) -> [Double] {
        let metricas = intencion.metricasSolicitadas.isEmpty
            ? [intencion.metrica] : intencion.metricasSolicitadas
        var valores: [Double] = []
        for metrica in metricas {
            switch metrica {
            case .disponibleReal: valores.append(r.disponibleReal)
            case .proyeccionFinDeMes: valores.append(r.proyeccionFinDeMes)
            case .deudaTotalTarjetas: valores.append(r.deudaTarjetas)
            case .patrimonio: valores.append(r.patrimonio)
            case .ingresos: valores.append(r.ingresoMesActual)
            case .gastos: valores.append(r.gastoMesActual)
            case .mayorDeudaTarjeta:
                if let tarjeta = r.detalleTarjetas.max(
                    by: { $0.deuda < $1.deuda }) { valores.append(tarjeta.deuda) }
            case .menorDeudaTarjeta:
                if let tarjeta = r.detalleTarjetas.min(
                    by: { $0.deuda < $1.deuda }) { valores.append(tarjeta.deuda) }
            default:
                let referencias = intencion.entidades.filter { entidad in
                    switch metrica {
                    case .deudaTarjeta, .saldoAlCorte,
                         .pagoParaNoGenerarIntereses, .pagoMinimo,
                         .pagadoDelCorte, .faltaDelCorte, .limiteCredito,
                         .creditoDisponible:
                        return entidad.tipo == .tarjeta
                    case .saldoCuenta: return entidad.tipo == .cuenta
                    case .porCobrarPersona: return entidad.tipo == .persona
                    case .deudaConAcreedor: return entidad.tipo == .acreedor
                    default: return false
                    }
                }
                valores += referencias.flatMap {
                    valoresPermitidos(de: $0, metrica: metrica, resumen: r)
                }
            }
        }
        return valores
    }

    private static func contieneNombreCompleto(
        _ nombre: String, en textoNormalizado: String
    ) -> Bool {
        let nombreNormalizado = EnrutadorConsultaClaro.normalizar(nombre)
        return " \(textoNormalizado) ".contains(" \(nombreNormalizado) ")
    }

    private static func coincide(_ valor: Double, en permitidos: [Double]) -> Bool {
        permitidos.contains { abs($0 - valor) < 0.011 }
    }

    private static func porcentajesEn(_ texto: String) -> [Double] {
        guard let expresion = try? NSRegularExpression(
            pattern: #"\b(\d{1,3}(?:\.\d+)?)\s*%"#) else { return [] }
        let ns = texto as NSString
        return expresion.matches(
            in: texto, range: NSRange(location: 0, length: ns.length)
        ).compactMap {
            guard $0.numberOfRanges > 1 else { return nil }
            return Double(ns.substring(with: $0.range(at: 1)))
        }
    }

    private static func enterosAntesDe(
        patrones: [String], en texto: String
    ) -> [Int] {
        patrones.flatMap { patron -> [Int] in
            guard let expresion = try? NSRegularExpression(
                pattern: #"\b(\d+)\s+"# + NSRegularExpression.escapedPattern(
                    for: patron)) else { return [] }
            let ns = texto as NSString
            return expresion.matches(
                in: texto, range: NSRange(location: 0, length: ns.length)
            ).compactMap {
                guard $0.numberOfRanges > 1 else { return nil }
                return Int(ns.substring(with: $0.range(at: 1)))
            }
        }
    }

    private static func contieneMontoEscritoConPalabras(_ texto: String) -> Bool {
        let normalizado = EnrutadorConsultaClaro.normalizar(texto)
        let numeros: Set<String> = [
            "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete",
            "ocho", "nueve", "diez", "once", "doce", "veinte", "treinta",
            "trece", "catorce", "quince", "dieciseis", "diecisiete",
            "dieciocho", "diecinueve", "cuarenta", "cincuenta", "sesenta",
            "setenta", "ochenta", "noventa", "cien", "ciento", "doscientos",
            "trescientos", "cuatrocientos", "quinientos", "seiscientos",
            "setecientos", "ochocientos", "novecientos", "mil", "millon",
            "millones"
        ]
        let palabras = normalizado.split(separator: " ").map(String.init)
        guard palabras.contains("pesos") || palabras.contains("peso")
            || palabras.contains("mil") else { return false }
        return !Set(palabras).isDisjoint(with: numeros)
    }

    private static func intentarConAppleIntelligence(
        solicitud: String,
        instrucciones: String) async -> String? {
        guard !AdministradorQwen.shared.bloqueaOtroModeloEnMemoria,
              let reserva = await CoordinadorInferenciaClaro.shared.reservar(.apple)
        else { return nil }
        guard !AdministradorQwen.shared.bloqueaOtroModeloEnMemoria else {
            await CoordinadorInferenciaClaro.shared.liberar(reserva)
            return nil
        }
        let resultado = await intentarConAppleIntelligenceSinReserva(
            solicitud: solicitud, instrucciones: instrucciones)
        await CoordinadorInferenciaClaro.shared.liberar(reserva)
        return resultado
    }

    private static func intentarConAppleIntelligenceSinReserva(
        solicitud: String,
        instrucciones: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), appleIntelligenceDisponible {
            do {
                let texto = try await responderConAppleIntelligence(
                    solicitud: solicitud, instrucciones: instrucciones)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return texto.isEmpty ? nil : texto
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    @Generable
    struct InterpretacionConsultaFinanciera {
        @Guide(description: "Verdadero únicamente si responder exige consultar las cuentas, tarjetas, movimientos, deudas o cálculos personales registrados del usuario")
        var usaDatosFinancierosPersonales: Bool

        @Guide(description: "Verdadero para definiciones o estrategias financieras generales que no requieren ni deben recibir datos personales")
        var esEducacionFinanciera: Bool

        @Guide(description: "Una sola frase que expresa exactamente la intención de la pregunta actual, conservando nombres, periodos y referencias resueltas con el historial")
        var objetivo: String

        @Guide(description: "Tipos de datos concretos que deben consultarse para responder, por ejemplo tarjetas individuales y sus deudas; no incluyas respuestas ni cifras inventadas")
        var datosNecesarios: String
    }

    @available(iOS 26.0, *)
    @Generable
    struct RedaccionFinanciera {
        @Guide(description: "Respuesta final en español mexicano, directa, clara y basada exclusivamente en los datos proporcionados")
        var respuesta: String
    }

    @available(iOS 26.0, *)
    private static func responderConAppleIntelligence(
        solicitud: String,
        instrucciones: String) async throws -> String {
        let sesion = LanguageModelSession(instructions: instrucciones)
        let respuesta = try await sesion.respond(to: solicitud,
                                                 generating: RedaccionFinanciera.self)
        return respuesta.content.respuesta
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    #endif
}
