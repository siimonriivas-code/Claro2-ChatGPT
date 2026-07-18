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
    case qwen8B = "Qwen3 8B · local"
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

    static let instruccionesDelCopiloto = """
    Eres Claro Inteligente, asesor financiero personal experto y privado. Dominas presupuesto, flujo de efectivo, crédito, deudas, pagos, ahorro, riesgo y proyecciones. Hablas en español mexicano y respondes con seguridad, franqueza y precisión.

    REGLAS OBLIGATORIAS:
    - Contesta la pregunta de inmediato. La primera frase debe dar el veredicto: sí, no, viable, riesgoso, bajo, alto o la conclusión concreta que corresponda.
    - No hagas preguntas preliminares y no obligues al usuario a llenar cuestionarios.
    - Para la situación personal del usuario, usa solamente los hechos y resultados entregados por el motor financiero. No inventes movimientos, tasas, ingresos, saldos ni fechas.
    - Puedes responder preguntas financieras generales con tu conocimiento, pero distingue claramente una explicación general de los datos personales realmente registrados.
    - No vuelvas a calcular operaciones: el motor ya hizo las cuentas. Tu trabajo es interpretar, comparar y explicar.
    - Distingue dinero disponible hoy de ingresos esperados; saldo de una cuenta de límite de crédito; y deuda vigente de gastos proyectados.
    - Al evaluar un préstamo o compra, considera flujo disponible, pagos próximos, deuda, margen mensual, riesgo y proyección de cierre. Expón cualquier supuesto después del veredicto.
    - Puedes dar una opinión clara como “yo no lo tomaría” o “sí parece viable”.
    - Si falta información, responde con la mejor estimación disponible y menciona la suposición después del veredicto; no detengas la respuesta.
    - Distingue riesgo financiero estimado de una declaración legal de bancarrota.
    - Sé breve: normalmente entre 2 y 5 párrafos cortos. Muestra primero lo importante y luego la evidencia.
    - Escribe todos los montos con signo de pesos para que el modo privacidad pueda ocultarlos.
    - No incluyas avisos genéricos, sermones ni frases paternalistas.
    """

    static var nombreMotorDisponible: String {
        if AdministradorQwen.shared.estaListo {
            return "\(AdministradorQwen.shared.nombreVisible) · local"
        }
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
        let solicitud = solicitudDelCopiloto(
            pregunta: pregunta, resumen: resumen,
            veredictoDelMotor: respaldo, historial: historial)

        if AdministradorQwen.shared.estaDescargado {
            do {
                let texto = try await AdministradorQwen.shared.responder(
                    solicitud: solicitud,
                    requiereRazonamiento: requiereRazonamientoProfundo(pregunta))
                if !texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let fuente: FuenteRespuestaClaro =
                        AdministradorQwen.shared.modeloSeleccionado == .potente8B
                        ? .qwen8B : .qwen4B
                    return RespuestaClaroInteligente(texto: texto, fuente: fuente)
                }
            } catch {
                // Apple Intelligence y las reglas siguen disponibles.
            }
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *),
           case .available = SystemLanguageModel.default.availability,
           SystemLanguageModel.default.supportsLocale(Locale(identifier: "es_MX")) {
            do {
                let texto = try await responderConAppleIntelligence(
                    solicitud: solicitud)
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

    static func solicitudDelCopiloto(
        pregunta: String,
        resumen: ResumenFinancieroClaro,
        veredictoDelMotor: String,
        historial: [TurnoConversacionClaro]) -> String {
        let qwen = AdministradorQwen.shared
        let limiteHistorial = qwen.modeloSeleccionado == .potente8B
            && qwen.estaDescargado ? 18 : 6
        let conversacion = historial.suffix(limiteHistorial).map {
            "\($0.esUsuario ? "USUARIO" : "CLARO"): \($0.texto)"
        }.joined(separator: "\n")
        return """
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

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    @Generable
    struct RedaccionFinanciera {
        @Guide(description: "Respuesta final en español mexicano, directa, clara y basada exclusivamente en los datos proporcionados")
        var respuesta: String
    }

    @available(iOS 26.0, *)
    private static func responderConAppleIntelligence(
        solicitud: String) async throws -> String {
        let sesion = LanguageModelSession(instructions: instruccionesDelCopiloto)
        let respuesta = try await sesion.respond(to: solicitud,
                                                 generating: RedaccionFinanciera.self)
        return respuesta.content.respuesta
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    #endif
}
