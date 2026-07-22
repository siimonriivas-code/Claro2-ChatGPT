import XCTest
@testable import Claro

final class PaymentSynchronizationRegressionTests: XCTestCase {
    private let calendario = Calendar(identifier: .gregorian)

    func testPagoTardioParcialYCompletoActualizaTodoElSistema() {
        let hoy = calendario.startOfDay(for: .now)
        let corte = fecha(relativaA: hoy, dias: -40)
        let limite = fecha(relativaA: hoy, dias: -10)
        let tarjeta = TarjetaCredito(
            nombre: "Prueba", limiteCredito: 20_000,
            diaCorte: 1, diaLimitePago: 20, saldoInicial: 1_500,
            fechaSaldoInicial: fecha(relativaA: hoy, dias: -100))
        let estado = EstadoDeCuenta(
            fechaCorte: corte, fechaLimitePago: limite,
            inicioPeriodo: fecha(relativaA: corte, dias: -30),
            finPeriodo: corte, pagoParaNoGenerarIntereses: 1_000,
            pagoMinimo: 100, saldoAlCorte: 1_500, tarjeta: tarjeta)
        let parcial = Movimiento(
            tipo: .pagoTarjeta, monto: 400,
            fecha: fecha(relativaA: hoy, dias: -1),
            detalle: "Pago parcial tardío", tarjeta: tarjeta)
        tarjeta.estadosDeCuenta = [estado]
        tarjeta.movimientos = [parcial]

        XCTAssertEqual(estado.pagadoDelPeriodo, 400, accuracy: 0.001)
        XCTAssertEqual(estado.faltaPorCubrir, 600, accuracy: 0.001)
        XCTAssertEqual(estado.saldoDelCortePendiente, 1_100, accuracy: 0.001)
        XCTAssertEqual(estado.pagoMinimoPendiente, 0, accuracy: 0.001)
        XCTAssertEqual(estado.situacion, .vencidoParcialmenteCubierto)
        XCTAssertEqual(MotorDashboard.comprometido(tarjetas: [tarjeta]),
                       600, accuracy: 0.001)

        let complemento = Movimiento(
            tipo: .pagoTarjeta, monto: 600, fecha: hoy,
            detalle: "Complemento", tarjeta: tarjeta)
        tarjeta.movimientos.append(complemento)

        XCTAssertEqual(estado.pagadoDelPeriodo, 1_000, accuracy: 0.001)
        XCTAssertEqual(estado.faltaPorCubrir, 0, accuracy: 0.001)
        XCTAssertEqual(estado.saldoDelCortePendiente, 500, accuracy: 0.001)
        XCTAssertEqual(estado.situacion, .cubierto)
        XCTAssertEqual(MotorDashboard.comprometido(tarjetas: [tarjeta]),
                       0, accuracy: 0.001)
        XCTAssertTrue(MotorDashboard.pagosProximos(tarjetas: [tarjeta]).isEmpty)

        complemento.estado = .cancelado
        XCTAssertEqual(estado.faltaPorCubrir, 600, accuracy: 0.001)
        XCTAssertEqual(estado.situacion, .vencidoParcialmenteCubierto)
    }

    func testUnPagoNoSeDuplicaEntreDosCortes() {
        let hoy = calendario.startOfDay(for: .now)
        let tarjeta = TarjetaCredito(
            nombre: "Prueba", limiteCredito: 20_000,
            diaCorte: 1, diaLimitePago: 20,
            fechaSaldoInicial: fecha(relativaA: hoy, dias: -120))
        let anterior = EstadoDeCuenta(
            fechaCorte: fecha(relativaA: hoy, dias: -60),
            fechaLimitePago: fecha(relativaA: hoy, dias: -40),
            inicioPeriodo: fecha(relativaA: hoy, dias: -90),
            finPeriodo: fecha(relativaA: hoy, dias: -60),
            pagoParaNoGenerarIntereses: 500, pagoMinimo: 50,
            saldoAlCorte: 500, tarjeta: tarjeta)
        let vigente = EstadoDeCuenta(
            fechaCorte: fecha(relativaA: hoy, dias: -30),
            fechaLimitePago: fecha(relativaA: hoy, dias: -10),
            inicioPeriodo: fecha(relativaA: hoy, dias: -59),
            finPeriodo: fecha(relativaA: hoy, dias: -30),
            pagoParaNoGenerarIntereses: 700, pagoMinimo: 70,
            saldoAlCorte: 700, tarjeta: tarjeta)
        let pago = Movimiento(
            tipo: .pagoTarjeta, monto: 700,
            fecha: fecha(relativaA: hoy, dias: -1),
            detalle: "Pago del corte vigente", tarjeta: tarjeta)
        tarjeta.estadosDeCuenta = [anterior, vigente]
        tarjeta.movimientos = [pago]

        XCTAssertEqual(anterior.pagadoDelPeriodo, 0, accuracy: 0.001)
        XCTAssertEqual(vigente.pagadoDelPeriodo, 700, accuracy: 0.001)
        XCTAssertEqual(vigente.situacion, .cubierto)
    }

    func testPagoAnteriorNoCubreElEstadoImportadoDespues() {
        let tarjeta = TarjetaCredito(
            nombre: "Prueba", limiteCredito: 66_000,
            diaCorte: 17, diaLimitePago: 10,
            fechaSaldoInicial: fecha(2026, 1, 1))
        let anterior = EstadoDeCuenta(
            fechaCorte: fecha(2026, 6, 17),
            fechaLimitePago: fecha(2026, 7, 10),
            inicioPeriodo: fecha(2026, 5, 18),
            finPeriodo: fecha(2026, 6, 17),
            pagoParaNoGenerarIntereses: 11_297.44,
            pagoMinimo: 900, saldoAlCorte: 11_297.44,
            tarjeta: tarjeta)
        anterior.registradoEl = fecha(2026, 6, 18)

        let pagoAnterior = Movimiento(
            tipo: .pagoTarjeta, monto: 11_297.44,
            fecha: fecha(2026, 7, 18),
            detalle: "Pago capturado antes del nuevo estado",
            tarjeta: tarjeta)
        pagoAnterior.creadoEl = fecha(2026, 7, 19)

        tarjeta.estadosDeCuenta = [anterior]
        tarjeta.movimientos = [pagoAnterior]
        tarjeta.sellarAsignacionUnicaDePagos()

        let nuevo = EstadoDeCuenta(
            fechaCorte: fecha(2026, 7, 17),
            fechaLimitePago: fecha(2026, 8, 10),
            inicioPeriodo: fecha(2026, 6, 18),
            finPeriodo: fecha(2026, 7, 17),
            pagoParaNoGenerarIntereses: 6_295.08,
            pagoMinimo: 830, saldoAlCorte: 6_295.08,
            tarjeta: tarjeta)
        nuevo.registradoEl = fecha(2026, 7, 21)
        tarjeta.estadosDeCuenta.append(nuevo)

        XCTAssertTrue(Calendar.current.isDate(
            pagoAnterior.fechaCorteObjetivoPago!,
            inSameDayAs: anterior.fechaCorte))
        XCTAssertEqual(anterior.pagadoDelPeriodo, 11_297.44, accuracy: 0.001)
        XCTAssertEqual(anterior.faltaPorCubrir, 0, accuracy: 0.001)
        XCTAssertEqual(nuevo.pagadoDelPeriodo, 0, accuracy: 0.001)
        XCTAssertEqual(nuevo.faltaPorCubrir, 6_295.08, accuracy: 0.001)
        XCTAssertEqual(nuevo.pagoMinimoPendiente, 830, accuracy: 0.001)
        XCTAssertEqual(nuevo.situacion, .pendiente)
    }

    func testFiltroDeCorteNoMezclaMovimientosAnteriores() {
        let tarjeta = TarjetaCredito(
            nombre: "Prueba", limiteCredito: 20_000,
            diaCorte: 17, diaLimitePago: 10,
            fechaSaldoInicial: fecha(2026, 1, 1))
        let loteAnterior = UUID()
        let loteVigente = UUID()
        let anterior = EstadoDeCuenta(
            fechaCorte: fecha(2026, 6, 17),
            fechaLimitePago: fecha(2026, 7, 10),
            inicioPeriodo: fecha(2026, 5, 18),
            finPeriodo: fecha(2026, 6, 17),
            pagoParaNoGenerarIntereses: 500, pagoMinimo: 50,
            saldoAlCorte: 500, tarjeta: tarjeta)
        anterior.importacionID = loteAnterior
        let vigente = EstadoDeCuenta(
            fechaCorte: fecha(2026, 7, 17),
            fechaLimitePago: fecha(2026, 8, 10),
            inicioPeriodo: fecha(2026, 6, 18),
            finPeriodo: fecha(2026, 7, 17),
            pagoParaNoGenerarIntereses: 700, pagoMinimo: 70,
            saldoAlCorte: 700, tarjeta: tarjeta)
        vigente.importacionID = loteVigente

        let compraAnterior = Movimiento(
            tipo: .compraCredito, monto: 500,
            fecha: fecha(2026, 6, 1), detalle: "Compra anterior",
            tarjeta: tarjeta)
        compraAnterior.importacionID = loteAnterior
        let compraVigente = Movimiento(
            tipo: .compraCredito, monto: 700,
            fecha: fecha(2026, 7, 1), detalle: "Compra vigente",
            tarjeta: tarjeta)
        compraVigente.importacionID = loteVigente
        let pagoAnterior = Movimiento(
            tipo: .pagoTarjeta, monto: 500,
            fecha: fecha(2026, 7, 5), detalle: "Pago anterior",
            tarjeta: tarjeta)
        pagoAnterior.fechaCorteObjetivoPago = anterior.fechaCorte

        tarjeta.estadosDeCuenta = [anterior, vigente]
        tarjeta.movimientos = [compraAnterior, compraVigente, pagoAnterior]

        let delAnterior = tarjeta.movimientos(asociadosA: anterior)
        let delVigente = tarjeta.movimientos(asociadosA: vigente)
        XCTAssertEqual(Set(delAnterior.map(\.detalle)),
                       Set(["Compra anterior", "Pago anterior"]))
        XCTAssertEqual(delVigente.map(\.detalle), ["Compra vigente"])
    }

    private func fecha(relativaA base: Date, dias: Int) -> Date {
        calendario.date(byAdding: .day, value: dias, to: base)!
    }

    private func fecha(_ anio: Int, _ mes: Int, _ dia: Int) -> Date {
        calendario.date(from: DateComponents(
            year: anio, month: mes, day: dia))!
    }
}
