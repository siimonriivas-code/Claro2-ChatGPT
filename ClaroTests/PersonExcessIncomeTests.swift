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

    func testResumenCompartidoExplicaComprasPagosYPendiente() {
        let persona = Persona(nombre: "Hermano")
        let tarjeta = TarjetaCredito(
            nombre: "BBVA Azul", limiteCredito: 30_000,
            diaCorte: 10, diaLimitePago: 28)

        let supermercado = Movimiento(
            tipo: .compraCredito, monto: 800,
            fecha: fecha(2026, 7, 3), detalle: "Supermercado",
            tarjeta: tarjeta)
        let compraSupermercado = CompraCompartida()
        compraSupermercado.movimiento = supermercado
        supermercado.compraCompartida = compraSupermercado
        let parteSupermercado = Participacion(
            monto: 400, persona: persona, compra: compraSupermercado)
        compraSupermercado.participaciones = [parteSupermercado]

        let celular = Movimiento(
            tipo: .compraCredito, monto: 6_000,
            fecha: fecha(2026, 5, 10), detalle: "Celular",
            tarjeta: tarjeta)
        let plan = PlanMSI(
            detalle: "Celular", montoTotal: 6_000, numeroMeses: 6,
            fechaCompra: celular.fecha, tarjeta: tarjeta)
        celular.planMSI = plan
        let compraCelular = CompraCompartida()
        compraCelular.movimiento = celular
        celular.compraCompartida = compraCelular
        let mesUno = Participacion(
            monto: 500, persona: persona, compra: compraCelular)
        let mesDos = Participacion(
            monto: 500, persona: persona, compra: compraCelular)
        compraCelular.participaciones = [mesUno, mesDos]

        persona.participaciones = [parteSupermercado, mesUno, mesDos]
        persona.movimientos = [
            Movimiento(tipo: .cobroRecibido, monto: 300,
                       fecha: fecha(2026, 7, 15), persona: persona)
        ]

        let resumen = GeneradorResumenCobro.texto(para: persona)

        XCTAssertTrue(resumen.contains("Supermercado"))
        XCTAssertTrue(resumen.contains("BBVA Azul"))
        XCTAssertTrue(resumen.contains("2 mensualidades MSI registradas"))
        XCTAssertTrue(resumen.contains("Subtotal de tus partes: $1,400.00"))
        XCTAssertTrue(resumen.contains("Pagos ya registrados: −$300.00"))
        XCTAssertTrue(resumen.contains("Total pendiente: $1,100.00"))
    }

    private func fecha(_ ano: Int, _ mes: Int, _ dia: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(
            year: ano, month: mes, day: dia, hour: 12))!
    }
}
