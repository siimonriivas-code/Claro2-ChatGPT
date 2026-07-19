import XCTest
@testable import Claro

final class FinancialSnapshotRegressionTests: XCTestCase {

    private let calendario = Calendar(identifier: .gregorian)

    func testMovimientosFuturosYCanceladosNoAlteranDineroDisponible() {
        let ahora = fecha(2026, 7, 19)
        let cuenta = CuentaBancaria(
            nombre: "Débito", tipo: .debito, saldoInicial: 1_000,
            fechaSaldoInicial: fecha(2026, 1, 1))
        let valido = Movimiento(
            tipo: .ingreso, monto: 500, fecha: fecha(2026, 7, 10),
            detalle: "Ingreso válido", cuenta: cuenta)
        let futuro = Movimiento(
            tipo: .ingreso, monto: 9_999, fecha: fecha(2026, 8, 1),
            detalle: "Ingreso futuro", cuenta: cuenta)
        let cancelado = Movimiento(
            tipo: .ingreso, monto: 777, fecha: fecha(2026, 7, 11),
            detalle: "Ingreso cancelado", cuenta: cuenta)
        cancelado.estado = .cancelado
        cuenta.movimientos = [valido, futuro, cancelado]

        let resumen = resumir(
            cuentas: [cuenta], movimientos: [valido, futuro, cancelado],
            ahora: ahora)
        XCTAssertEqual(resumen.saldoLiquido, 1_500, accuracy: 0.001)
        XCTAssertEqual(resumen.ingresoMesActual, 500, accuracy: 0.001)
        XCTAssertEqual(resumen.movimientosAnalizados, 1)
    }

    func testTransferenciaSoloMueveDineroYNoLoDuplica() {
        let ahora = fecha(2026, 7, 19)
        let origen = CuentaBancaria(
            nombre: "Origen", tipo: .debito, saldoInicial: 1_000,
            fechaSaldoInicial: fecha(2026, 1, 1))
        let destino = CuentaBancaria(
            nombre: "Destino", tipo: .ahorro, saldoInicial: 100,
            fechaSaldoInicial: fecha(2026, 1, 1))
        let transferencia = Movimiento(
            tipo: .transferencia, monto: 300, fecha: fecha(2026, 7, 10),
            detalle: "Ahorro", cuenta: origen, cuentaDestino: destino)
        origen.movimientos = [transferencia]
        destino.movimientosEntrantes = [transferencia]

        let resumen = resumir(
            cuentas: [origen, destino], movimientos: [transferencia],
            ahora: ahora)
        XCTAssertEqual(resumen.detalleCuentas.first {
            $0.nombre == "Origen"
        }?.saldo ?? -1, 700, accuracy: 0.001)
        XCTAssertEqual(resumen.detalleCuentas.first {
            $0.nombre == "Destino"
        }?.saldo ?? -1, 400, accuracy: 0.001)
        XCTAssertEqual(resumen.saldoLiquido, 1_100, accuracy: 0.001)
        XCTAssertEqual(resumen.ingresoMesActual, 0, accuracy: 0.001)
        XCTAssertEqual(resumen.gastoMesActual, 0, accuracy: 0.001)
    }

    func testComprasYPagosFuturosNoCambianDeudaHistorica() {
        let ahora = fecha(2026, 7, 19)
        let tarjeta = TarjetaCredito(
            nombre: "Prueba", limiteCredito: 10_000,
            diaCorte: 13, diaLimitePago: 3, saldoInicial: 1_000,
            fechaSaldoInicial: fecha(2026, 1, 1))
        let compraActual = Movimiento(
            tipo: .compraCredito, monto: 500, fecha: fecha(2026, 7, 10),
            detalle: "Compra actual", tarjeta: tarjeta)
        let pagoActual = Movimiento(
            tipo: .pagoTarjeta, monto: 200, fecha: fecha(2026, 7, 11),
            detalle: "Pago actual", tarjeta: tarjeta)
        let compraFutura = Movimiento(
            tipo: .compraCredito, monto: 800, fecha: fecha(2026, 8, 1),
            detalle: "Compra futura", tarjeta: tarjeta)
        let pagoFuturo = Movimiento(
            tipo: .pagoTarjeta, monto: 900, fecha: fecha(2026, 8, 2),
            detalle: "Pago futuro", tarjeta: tarjeta)
        tarjeta.movimientos = [compraActual, pagoActual, compraFutura, pagoFuturo]

        let resumen = resumir(
            tarjetas: [tarjeta],
            movimientos: [compraActual, pagoActual, compraFutura, pagoFuturo],
            ahora: ahora)
        XCTAssertEqual(resumen.deudaTarjetas, 1_300, accuracy: 0.001)
        XCTAssertEqual(resumen.detalleTarjetas.first?.creditoDisponible ?? -1,
                       8_700, accuracy: 0.001)
    }

    func testPagoTardioCompletoLiquidaCorteSinCrearDeudaFantasma() {
        let ahora = fecha(2026, 8, 10)
        let tarjeta = TarjetaCredito(
            nombre: "Hey", limiteCredito: 50_000,
            diaCorte: 13, diaLimitePago: 3,
            fechaSaldoInicial: fecha(2026, 1, 1))
        let corte = EstadoDeCuenta(
            fechaCorte: fecha(2026, 7, 13),
            fechaLimitePago: fecha(2026, 8, 3),
            inicioPeriodo: fecha(2026, 6, 14),
            finPeriodo: fecha(2026, 7, 13),
            pagoParaNoGenerarIntereses: 1_000,
            pagoMinimo: 100, saldoAlCorte: 1_500, tarjeta: tarjeta)
        let corteFuturo = EstadoDeCuenta(
            fechaCorte: fecha(2026, 8, 13),
            fechaLimitePago: fecha(2026, 9, 3),
            inicioPeriodo: fecha(2026, 7, 14),
            finPeriodo: fecha(2026, 8, 13),
            pagoParaNoGenerarIntereses: 9_999,
            pagoMinimo: 999, saldoAlCorte: 9_999, tarjeta: tarjeta)
        let pagoTardio = Movimiento(
            tipo: .pagoTarjeta, monto: 1_000, fecha: fecha(2026, 8, 5),
            detalle: "Pago tardío completo", tarjeta: tarjeta)
        tarjeta.estadosDeCuenta = [corte, corteFuturo]
        tarjeta.movimientos = [pagoTardio]

        let resumen = resumir(
            tarjetas: [tarjeta], movimientos: [pagoTardio], ahora: ahora)
        XCTAssertEqual(resumen.comprometidoTarjetas, 0, accuracy: 0.001)
        XCTAssertEqual(resumen.estadosVencidos, 0)
        XCTAssertEqual(resumen.detalleTarjetas.first?.pagoMinimo ?? -1,
                       100, accuracy: 0.001)
        XCTAssertEqual(resumen.detalleTarjetas.first?.pagadoDelCorte ?? -1,
                       1_000, accuracy: 0.001)
    }

    func testPersonaYDeudaIgnoranAbonosFuturos() {
        let ahora = fecha(2026, 7, 19)
        let persona = Persona(nombre: "Alondra")
        let compraMovimiento = Movimiento(
            tipo: .gasto, monto: 1_200, fecha: fecha(2026, 7, 1),
            detalle: "Compra compartida")
        let compra = CompraCompartida()
        compra.movimiento = compraMovimiento
        let participacion = Participacion(
            monto: 1_000, persona: persona, compra: compra)
        persona.participaciones = [participacion]
        compra.participaciones = [participacion]
        let cobroActual = Movimiento(
            tipo: .cobroRecibido, monto: 200, fecha: fecha(2026, 7, 10),
            detalle: "Cobro actual", persona: persona)
        let cobroFuturo = Movimiento(
            tipo: .cobroRecibido, monto: 700, fecha: fecha(2026, 8, 1),
            detalle: "Cobro futuro", persona: persona)
        persona.movimientos = [cobroActual, cobroFuturo]

        let deuda = Deuda(
            acreedor: "Hermano", montoOriginal: 2_000,
            fecha: fecha(2026, 1, 1))
        let abonoActual = Movimiento(
            tipo: .abonoDeuda, monto: 500, fecha: fecha(2026, 7, 9),
            detalle: "Abono actual", deuda: deuda)
        let abonoFuturo = Movimiento(
            tipo: .abonoDeuda, monto: 1_000, fecha: fecha(2026, 8, 2),
            detalle: "Abono futuro", deuda: deuda)
        deuda.abonos = [abonoActual, abonoFuturo]

        let todos = [compraMovimiento, cobroActual, cobroFuturo,
                     abonoActual, abonoFuturo]
        let resumen = resumir(
            personas: [persona], deudas: [deuda], movimientos: todos,
            ahora: ahora)
        XCTAssertEqual(resumen.detallePersonas.first?.pendiente ?? -1,
                       800, accuracy: 0.001)
        XCTAssertEqual(resumen.detalleDeudas.first?.saldo ?? -1,
                       1_500, accuracy: 0.001)
    }

    func testSobrepagoDePersonaNuncaCreaDeudaNegativa() {
        let ahora = fecha(2026, 7, 19)
        let persona = Persona(nombre: "Alondra")
        let movimientoCompra = Movimiento(
            tipo: .gasto, monto: 100, fecha: fecha(2026, 7, 1),
            detalle: "Compra compartida")
        let compra = CompraCompartida()
        compra.movimiento = movimientoCompra
        let participacion = Participacion(
            monto: 100, persona: persona, compra: compra)
        persona.participaciones = [participacion]
        let cobro = Movimiento(
            tipo: .cobroRecibido, monto: 200, fecha: fecha(2026, 7, 5),
            detalle: "Pago mayor", persona: persona)
        persona.movimientos = [cobro]

        let resumen = resumir(
            personas: [persona], movimientos: [movimientoCompra, cobro],
            ahora: ahora)
        XCTAssertEqual(resumen.porCobrar, 0, accuracy: 0.001)
        XCTAssertEqual(resumen.detallePersonas.first?.pendiente ?? -1,
                       0, accuracy: 0.001)
    }

    func testUnSoloMesHistoricoNoSeDiluyeConMesesVaciosAnteriores() {
        let ahora = fecha(2026, 7, 19)
        let ingresoMayo = Movimiento(
            tipo: .ingreso, monto: 6_000, fecha: fecha(2026, 5, 5),
            detalle: "Nómina histórica")

        let resumen = resumir(movimientos: [ingresoMayo], ahora: ahora)
        XCTAssertEqual(resumen.ingresoMensualEstimado, 6_000,
                       accuracy: 0.001)
        XCTAssertEqual(resumen.mesesConHistoria, 1)
    }

    func testTasaMensualSeConvierteYCatNoSeUsaComoTasaAnual() {
        let resumen = resumir(movimientos: [], ahora: fecha(2026, 7, 19))
        let mensual = EnrutadorConsultaClaro.decidir(
            pregunta: "¿Es viable un préstamo de $12,000 a 12 meses con 2% mensual?",
            historial: [], resumen: resumen).intencion
        let respuestaMensual = MotorClaroInteligente.responderConReglas(
            intencion: mensual,
            pregunta: "¿Es viable un préstamo de $12,000 a 12 meses con 2% mensual?",
            resumen: resumen)
        XCTAssertTrue(respuestaMensual.contains("24.00%"), respuestaMensual)

        let soloCAT = EnrutadorConsultaClaro.decidir(
            pregunta: "¿Es viable un préstamo de $12,000 a 12 meses con CAT 40%?",
            historial: [], resumen: resumen).intencion
        let respuestaCAT = MotorClaroInteligente.responderConReglas(
            intencion: soloCAT,
            pregunta: "¿Es viable un préstamo de $12,000 a 12 meses con CAT 40%?",
            resumen: resumen)
        XCTAssertFalse(respuestaCAT.contains("Usé una tasa anual"), respuestaCAT)
    }

    private func resumir(
        cuentas: [CuentaBancaria] = [],
        tarjetas: [TarjetaCredito] = [],
        personas: [Persona] = [],
        deudas: [Deuda] = [],
        movimientos: [Movimiento],
        ahora: Date
    ) -> ResumenFinancieroClaro {
        MotorClaroInteligente.resumir(
            cuentas: cuentas, tarjetas: tarjetas, personas: personas,
            planes: [], deudas: deudas, movimientos: movimientos, ahora: ahora)
    }

    private func fecha(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendario.date(from: DateComponents(
            year: year, month: month, day: day, hour: 12))!
    }
}
