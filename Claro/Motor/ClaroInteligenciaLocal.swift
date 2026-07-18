//
//  ClaroInteligenciaLocal.swift
//  Claro
//
//  Apple Intelligence redacta la explicación, pero no hace las cuentas.
//  Si el modelo no está disponible, el Motor local responde directamente.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum FuenteRespuestaClaro: String {
    case appleIntelligence = "Apple Intelligence"
    case motorLocal = "Motor local"
}

struct RespuestaClaroInteligente {
    let texto: String
    let fuente: FuenteRespuestaClaro
}

struct TurnoConversacionClaro {
    let esUsuario: Bool
    let texto: String
}

enum ClaroInteligenciaLocal {

    static var nombreMotorDisponible: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *),
           case .available = SystemLanguageModel.default.availability,
           SystemLanguageModel.default.supportsLocale(Locale(identifier: "es_MX")) {
            return "Apple Intelligence · local"
        }
        #endif
        return "Motor financiero · local"
    }

    static func responder(pregunta: String,
                          resumen: ResumenFinancieroClaro,
                          historial: [TurnoConversacionClaro]) async -> RespuestaClaroInteligente {
        let respaldo = MotorClaroInteligente.responderConReglas(pregunta,
                                                                 resumen: resumen)
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *),
           case .available = SystemLanguageModel.default.availability,
           SystemLanguageModel.default.supportsLocale(Locale(identifier: "es_MX")) {
            do {
                let texto = try await responderConAppleIntelligence(
                    pregunta: pregunta, resumen: resumen,
                    veredictoDelMotor: respaldo, historial: historial)
                if !texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return RespuestaClaroInteligente(texto: texto,
                                                     fuente: .appleIntelligence)
                }
            } catch {
                // La conversación nunca se rompe: las reglas locales contestan.
            }
        }
        #endif
        return RespuestaClaroInteligente(texto: respaldo, fuente: .motorLocal)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    @Generable
    struct RedaccionFinanciera {
        @Guide(description: "Respuesta final en español mexicano, directa, clara y basada exclusivamente en los datos proporcionados")
        var respuesta: String
    }

    @available(iOS 26.0, *)
    private static func responderConAppleIntelligence(
        pregunta: String,
        resumen: ResumenFinancieroClaro,
        veredictoDelMotor: String,
        historial: [TurnoConversacionClaro]) async throws -> String {
        let instrucciones = """
        Eres Claro Inteligente, copiloto financiero personal privado. Hablas en español mexicano y respondes con seguridad, franqueza y precisión.

        REGLAS OBLIGATORIAS:
        - Contesta la pregunta de inmediato. La primera frase debe dar el veredicto: sí, no, viable, riesgoso, bajo, alto o la conclusión concreta que corresponda.
        - No hagas preguntas preliminares y no obligues al usuario a llenar cuestionarios.
        - Usa solamente los hechos y resultados entregados por el motor financiero. No inventes movimientos, tasas, ingresos ni fechas.
        - No vuelvas a calcular operaciones: el motor ya hizo las cuentas. Tu trabajo es interpretar, comparar y explicar.
        - Puedes dar una opinión clara como “yo no lo tomaría” o “sí parece viable”.
        - Si falta información, responde con la mejor estimación disponible y menciona la suposición después del veredicto; no detengas la respuesta.
        - Distingue riesgo financiero estimado de una declaración legal de bancarrota.
        - Sé breve: normalmente entre 2 y 5 párrafos cortos. Muestra primero lo importante y luego la evidencia.
        - Escribe todos los montos con signo de pesos para que el modo privacidad pueda ocultarlos.
        - No incluyas avisos genéricos, sermones ni frases paternalistas.
        """
        let conversacion = historial.suffix(6).map {
            "\($0.esUsuario ? "USUARIO" : "CLARO"): \($0.texto)"
        }.joined(separator: "\n")
        let solicitud = """
        DATOS CALCULADOS POR EL MOTOR:
        \(resumen.contextoParaModelo)

        VEREDICTO DETERMINISTA PARA ESTA PREGUNTA:
        \(veredictoDelMotor)

        CONTEXTO RECIENTE:
        \(conversacion.isEmpty ? "Sin conversación anterior." : conversacion)

        PREGUNTA ACTUAL:
        \(pregunta)

        Responde directamente usando estos datos. Conserva las cifras y el sentido del veredicto determinista; puedes mejorar su claridad y explicar sus razones.
        """
        let sesion = LanguageModelSession(instructions: instrucciones)
        let respuesta = try await sesion.respond(to: solicitud,
                                                 generating: RedaccionFinanciera.self)
        return respuesta.content.respuesta
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    #endif
}
