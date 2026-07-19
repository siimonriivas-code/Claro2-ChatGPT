import XCTest
@testable import Claro

final class RappiImportRegressionTests: XCTestCase {

    func testRappiExtraeResumenYMovimientosSinConfundirIntereses() async {
        let textoOCR = """
        BANORTE RappiCard
        Estado de cuenta
        Número de tarjeta **** **** **** 5915
        TU PAGO REQUERIDO ESTE PERIODO
        Periodo 07-jun-2026 al 06-jul-2026
        Fecha de corte 06-jul-2026
        Fecha límite de pago lunes, 27-jul-2026
        Pago para no generar intereses $476.89
        Pago mínimo + compras y cargos diferidos a meses $553.96
        Pago mínimo $476.89
        NIVEL DE USO DE TU TARJETA
        Saldo cargos regulares: $476.89
        Saldo cargos a meses: $426.47
        Saldo deudor total $903.36
        Límite de crédito $73,000.00

        DESGLOSE DE MOVIMIENTOS
        COMPRAS Y CARGOS DIFERIDOS A MESES CON INTERESES
        2026-03-03 Rappi; RFC: TRA150604TW1 $637.40 $426.47 $29.62 $4.74 $77.07 5 de 12 75%
        CARGOS, ABONOS Y COMPRAS REGULARES (NO A MESES)
        2026-06-09 2026-06-09 Rappi; RFC: TRA150604TW1 +$143.50
        2026-06-22 2026-06-22 Rappi; RFC: TRA150604TW1 +$237.46
        2026-06-25 2026-06-25 Rappi; RFC: TRA150604TW1 +$160.50
        2026-06-25 2026-06-25 PAGO POR SPEI -$1,553.75
        2026-07-06 2026-07-06 IVA INTERES COMPRA EN CUOTAS +$4.74
        Total de cargos +$546.20
        Total de abonos -$1,553.75
        """

        let resultado = await AnalizadorEstadoDeCuenta.analizar(
            paginas: [textoOCR])

        XCTAssertEqual(resultado.bancoDetectado, "RappiCard")
        XCTAssertEqual(resultado.ultimosDigitosDetectados, "5915")
        XCTAssertEqual(resultado.pagoParaNoGenerarIntereses, 476.89)
        XCTAssertEqual(resultado.pagoMinimo, 476.89)
        XCTAssertEqual(resultado.saldoAlCorte, 903.36)
        XCTAssertEqual(componentes(resultado.fechaCorte), [2026, 7, 6])
        XCTAssertEqual(componentes(resultado.fechaLimitePago), [2026, 7, 27])

        XCTAssertEqual(resultado.movimientos.count, 4)
        XCTAssertEqual(resultado.movimientos.filter(\.esMSI).count, 1)
        let plan = try? XCTUnwrap(resultado.movimientos.first(where: \.esMSI))
        XCTAssertEqual(plan?.montoOriginal, 637.40)
        XCTAssertEqual(plan?.monto, 77.07)
        XCTAssertEqual(plan?.msiNumero, 5)
        XCTAssertEqual(plan?.msiTotal, 12)
        XCTAssertFalse(resultado.movimientos.contains {
            $0.comercio.localizedCaseInsensitiveContains("SPEI")
                || $0.comercio.localizedCaseInsensitiveContains("IVA INTERES")
        })
    }

    private func componentes(_ fecha: Date?) -> [Int] {
        guard let fecha else { return [] }
        let c = Calendar.current.dateComponents([.year, .month, .day], from: fecha)
        return [c.year, c.month, c.day].compactMap { $0 }
    }
}
