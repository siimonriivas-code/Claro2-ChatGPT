import XCTest
@testable import Claro

final class DeviceAIStressTests: XCTestCase {

    func testAlternaQwenYConversacionGeneralDoceVecesSinRetenerModelo() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("La prueba de memoria requiere el iPhone físico con Qwen descargado.")
        #else
        let qwen = AdministradorQwen.shared
        guard qwen.estaDescargado else {
            throw XCTSkip("Qwen no está descargado en el contenedor de esta instalación.")
        }

        let resumen = ResumenFinancieroClaro.pruebaConversacional
        var historial: [TurnoConversacionClaro] = []
        for numero in 1...12 {
            let financiera = await ClaroInteligenciaLocal.responder(
                pregunta: "Explica en dos frases qué aspecto de mis finanzas conviene vigilar en la prueba \(numero).",
                resumen: resumen,
                historial: historial)
            XCTAssertEqual(financiera.ambito, .finanzasPersonales)
            XCTAssertFalse(financiera.texto.isEmpty)
            XCTAssertFalse(
                qwen.bloqueaOtroModeloEnMemoria,
                "Qwen retuvo pesos o buffers después de la vuelta \(numero)")

            historial.append(.init(
                esUsuario: true, texto: "Consulta financiera \(numero)",
                ambito: .finanzasPersonales))
            historial.append(.init(
                esUsuario: false, texto: financiera.texto,
                ambito: financiera.ambito))

            let general = await ClaroInteligenciaLocal.responder(
                pregunta: numero.isMultiple(of: 2) ? "¿Cómo estás?" : "Hola",
                resumen: resumen,
                historial: historial)
            XCTAssertEqual(general.ambito, .general)
            XCTAssertFalse(general.texto.isEmpty)
            XCTAssertFalse(
                general.texto.contains("deuda")
                    || general.texto.contains("riesgo crítico")
                    || general.texto.contains("patrimonio"),
                "La charla general arrastró el diagnóstico en la vuelta \(numero)")
        }
        #endif
    }
}
