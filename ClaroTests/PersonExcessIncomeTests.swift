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

    func testResumenCompartidoSoloCobraCorteVigenteYSaldoReal() {
        let persona = Persona(nombre: "Alondra")
        let tarjeta = TarjetaCredito(
            nombre: "BBVA Azul", limiteCredito: 30_000,
            diaCorte: 10, diaLimitePago: 28)

        let loteAnterior = UUID()
        let loteVigente = UUID()
        let corteAnterior = EstadoDeCuenta(
            fechaCorte: fecha(2026, 6, 10),
            fechaLimitePago: fecha(2026, 6, 28),
            inicioPeriodo: fecha(2026, 5, 11),
            finPeriodo: fecha(2026, 6, 10),
            pagoParaNoGenerarIntereses: 2_000,
            pagoMinimo: 200,
            saldoAlCorte: 2_000,
            tarjeta: tarjeta)
        corteAnterior.importacionID = loteAnterior
        let corteVigente = EstadoDeCuenta(
            fechaCorte: fecha(2026, 7, 10),
            fechaLimitePago: fecha(2026, 7, 28),
            inicioPeriodo: fecha(2026, 6, 11),
            finPeriodo: fecha(2026, 7, 10),
            pagoParaNoGenerarIntereses: 3_000,
            pagoMinimo: 300,
            saldoAlCorte: 3_000,
            tarjeta: tarjeta)
        corteVigente.importacionID = loteVigente
        tarjeta.estadosDeCuenta = [corteAnterior, corteVigente]

        let compraAntigua = Movimiento(
            tipo: .compraCredito, monto: 1_000,
            fecha: fecha(2026, 6, 3), detalle: "Cena de junio",
            tarjeta: tarjeta)
        compraAntigua.importacionID = loteAnterior
        let compartidaAntigua = CompraCompartida()
        compartidaAntigua.movimiento = compraAntigua
        compraAntigua.compraCompartida = compartidaAntigua
        let parteAntigua = Participacion(
            monto: 500, persona: persona, compra: compartidaAntigua)
        parteAntigua.importacionID = loteAnterior
        compartidaAntigua.participaciones = [parteAntigua]

        let supermercado = Movimiento(
            tipo: .compraCredito, monto: 800,
            fecha: fecha(2026, 7, 3), detalle: "Supermercado",
            tarjeta: tarjeta)
        supermercado.importacionID = loteVigente
        let compraSupermercado = CompraCompartida()
        compraSupermercado.movimiento = supermercado
        supermercado.compraCompartida = compraSupermercado
        let parteSupermercado = Participacion(
            monto: 400, persona: persona, compra: compraSupermercado)
        parteSupermercado.importacionID = loteVigente
        compraSupermercado.participaciones = [parteSupermercado]

        let celular = Movimiento(
            tipo: .compraCredito, monto: 6_000,
            fecha: fecha(2026, 5, 3), detalle: "Celular",
            tarjeta: tarjeta)
        let plan = PlanMSI(
            detalle: "Celular", montoTotal: 6_000, numeroMeses: 6,
            fechaCompra: celular.fecha, tarjeta: tarjeta)
        celular.planMSI = plan
        let compraCelular = CompraCompartida()
        compraCelular.movimiento = celular
        celular.compraCompartida = compraCelular
        let mesAnterior = Participacion(
            monto: 500, persona: persona, compra: compraCelular)
        mesAnterior.importacionID = loteAnterior
        let mesVigente = Participacion(
            monto: 500, persona: persona, compra: compraCelular)
        mesVigente.importacionID = loteVigente
        compraCelular.participaciones = [mesAnterior, mesVigente]
        let mensualidadAnterior = MensualidadMSI(
            numero: 1, monto: 1_000, plan: plan)
        mensualidadAnterior.estadoDeCuenta = corteAnterior
        let mensualidadVigente = MensualidadMSI(
            numero: 2, monto: 1_000, plan: plan)
        mensualidadVigente.estadoDeCuenta = corteVigente
        plan.mensualidades = [mensualidadAnterior, mensualidadVigente]

        let compraSinCortar = Movimiento(
            tipo: .compraCredito, monto: 400,
            fecha: fecha(2026, 7, 18), detalle: "Cine sin cortar",
            tarjeta: tarjeta)
        let compartidaSinCortar = CompraCompartida()
        compartidaSinCortar.movimiento = compraSinCortar
        compraSinCortar.compraCompartida = compartidaSinCortar
        let parteSinCortar = Participacion(
            monto: 200, persona: persona, compra: compartidaSinCortar)
        compartidaSinCortar.participaciones = [parteSinCortar]

        persona.participaciones = [
            parteAntigua,
            mesAnterior,
            parteSupermercado,
            mesVigente,
            parteSinCortar
        ]
        persona.movimientos = [
            Movimiento(tipo: .cobroRecibido, monto: 1_000,
                       fecha: fecha(2026, 7, 15), persona: persona)
        ]

        let calculo = GeneradorResumenCobro.calcular(para: persona)
        let resumen = GeneradorResumenCobro.texto(para: persona)

        XCTAssertEqual(calculo.cargosCorteVigente, 900, accuracy: 0.001)
        XCTAssertEqual(calculo.pendienteCorteVigente, 900, accuracy: 0.001)
        XCTAssertEqual(calculo.saldoAnteriorPendiente, 0, accuracy: 0.001)
        XCTAssertEqual(calculo.comprasSinCortar, 200, accuracy: 0.001)
        XCTAssertEqual(calculo.totalAPagarAhora, 900, accuracy: 0.001)
        XCTAssertTrue(resumen.contains("Supermercado"))
        XCTAssertTrue(resumen.contains("MSI 2/6"))
        XCTAssertFalse(resumen.contains("Cena de junio"))
        XCTAssertTrue(resumen.contains("Compras todavía sin cortar: $200.00"))
        XCTAssertTrue(resumen.contains("TOTAL A PAGAR AHORA: $900.00"))
    }

    func testSaldoAnteriorSoloApareceSiRealmenteSiguePendiente() {
        let persona = Persona(nombre: "Hermano")
        let tarjeta = TarjetaCredito(
            nombre: "Liverpool", limiteCredito: 20_000,
            diaCorte: 13, diaLimitePago: 3)
        let loteAnterior = UUID()
        let loteVigente = UUID()
        let anterior = EstadoDeCuenta(
            fechaCorte: fecha(2026, 6, 13),
            fechaLimitePago: fecha(2026, 7, 3),
            inicioPeriodo: fecha(2026, 5, 14),
            finPeriodo: fecha(2026, 6, 13),
            pagoParaNoGenerarIntereses: 500,
            pagoMinimo: 50,
            saldoAlCorte: 500,
            tarjeta: tarjeta)
        anterior.importacionID = loteAnterior
        let vigente = EstadoDeCuenta(
            fechaCorte: fecha(2026, 7, 13),
            fechaLimitePago: fecha(2026, 8, 3),
            inicioPeriodo: fecha(2026, 6, 14),
            finPeriodo: fecha(2026, 7, 13),
            pagoParaNoGenerarIntereses: 300,
            pagoMinimo: 30,
            saldoAlCorte: 300,
            tarjeta: tarjeta)
        vigente.importacionID = loteVigente
        tarjeta.estadosDeCuenta = [anterior, vigente]

        let movimiento = Movimiento(
            tipo: .compraCredito,
            monto: 500,
            fecha: fecha(2026, 6, 2),
            detalle: "Compra anterior",
            tarjeta: tarjeta)
        let compartida = CompraCompartida()
        compartida.movimiento = movimiento
        movimiento.compraCompartida = compartida
        let parte = Participacion(
            monto: 500, persona: persona, compra: compartida)
        parte.importacionID = loteAnterior
        compartida.participaciones = [parte]
        persona.participaciones = [parte]
        persona.movimientos = [
            Movimiento(tipo: .cobroRecibido, monto: 300, persona: persona)
        ]

        let calculo = GeneradorResumenCobro.calcular(para: persona)
        let texto = GeneradorResumenCobro.texto(para: persona)

        XCTAssertEqual(
            calculo.saldoAnteriorPendiente,
            200,
            accuracy: 0.001
        )
        XCTAssertTrue(
            texto.contains("SALDO ANTERIOR REALMENTE PENDIENTE")
        )
        XCTAssertTrue(texto.contains("$200.00 pendiente de $500.00"))
    }

    private func fecha(_ ano: Int, _ mes: Int, _ dia: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(
            year: ano, month: mes, day: dia, hour: 12))!
    }
}
