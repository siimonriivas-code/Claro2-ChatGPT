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

    private func fecha(relativaA base: Date, dias: Int) -> Date {
        calendario.date(byAdding: .day, value: dias, to: base)!
    }
}
