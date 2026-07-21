import XCTest
@testable import Claro

final class PersonExcessIncomeTests: XCTestCase {
    func testCobroSeDivideEntreDeudaEIngreso() {
        let distribucion = MotorDePersonas.distribuirCobro(
            monto: 5_807, saldoPendiente: 2_019.62)

        XCTAssertEqual(distribucion.aplicadoADeuda, 2_019.62, accuracy: 0.001)
        XCTAssertEqual(distribucion.excedenteComoIngreso, 3_787.38, accuracy: 0.001)
    }

    func testExcedenteNoConvierteAUsuarioEnDeudor() {
        let persona = Persona(nombre: "Bodoque")
        let movimientoCompra = Movimiento(tipo: .gasto, monto: 100)
        let compra = CompraCompartida()
        compra.movimiento = movimientoCompra
        let participacion = Participacion(
            monto: 100, persona: persona, compra: compra)
        persona.participaciones = [participacion]
        compra.participaciones = [participacion]

        let aplicado = Movimiento(
            tipo: .cobroRecibido, monto: 100, persona: persona)
        let excedente = Movimiento(
            tipo: .ingreso, monto: 50, persona: persona)
        persona.movimientos = [aplicado, excedente]

        XCTAssertEqual(persona.saldoPendiente, 0, accuracy: 0.001)
        XCTAssertEqual(persona.totalAplicadoADeuda, 100, accuracy: 0.001)
        XCTAssertEqual(persona.totalExcedenteRecibido, 50, accuracy: 0.001)
        XCTAssertEqual(persona.totalQueTeHaPagado, 150, accuracy: 0.001)
    }
}
