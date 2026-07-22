import XCTest
@testable import Claro

final class StatementImportRegressionTests: XCTestCase {
    func testBanamexExtraeCadenaContableDelPeriodo() async {
        let texto = """
        BANAMEX
        Número de tarjeta 5499 4905 6134 4490
        Fecha de corte: 17-jul-2026
        Fecha límite de pago: lunes, 10-ago-2026
        Pago para no generar intereses: $6,295.08
        Pago mínimo: $830.00
        Saldo deudor total: $6,295.08
        RESUMEN DE CARGOS Y ABONOS DEL PERIODO
        Adeudo del periodo anterior = $11,297.44
        Cargos regulares (no a meses) + $6,307.08
        Cargos compras a meses (capital) + $0.00
        Monto de Intereses + $0.00
        Monto de comisiones + $0.00
        IVA de Intereses y comisiones + $0.00
        Pagos y abonos - $11,309.44
        """

        let resultado = await AnalizadorEstadoDeCuenta.analizar(
            paginas: [texto])
        XCTAssertEqual(resultado.adeudoPeriodoAnterior!,
                       11_297.44, accuracy: 0.001)
        XCTAssertEqual(resultado.ultimosDigitosDetectados, "4490")
        XCTAssertEqual(resultado.cargosYCostosPeriodo!,
                       6_307.08, accuracy: 0.001)
        XCTAssertEqual(resultado.pagosYAbonosPeriodo!,
                       11_309.44, accuracy: 0.001)
        let comprobacion = ConciliadorEstadoCuenta.verificar(
            adeudoAnterior: resultado.adeudoPeriodoAnterior!,
            cargosYCostos: resultado.cargosYCostosPeriodo!,
            pagosYAbonos: resultado.pagosYAbonosPeriodo!,
            nuevoPagoParaNoGenerarIntereses:
                resultado.pagoParaNoGenerarIntereses!)
        XCTAssertTrue(comprobacion.esCoherente)
        XCTAssertEqual(comprobacion.saldoEsperado, 6_295.08, accuracy: 0.001)
    }

    func testHeyBancoTomaLaTerminacionDeUnNumeroCompleto() async {
        let texto = """
        HEY BANCO
        NÚMERO DE LA TARJETA 4741751765438803
        Periodo 14-jun-2026 al 13-jul-2026
        Fecha límite de pago: lunes, 03-ago-2026
        Pago para no generar intereses $5,776.46
        Pago mínimo $625.00
        Saldo deudor total $13,985.11
        """

        let resultado = await AnalizadorEstadoDeCuenta.analizar(paginas: [texto])

        XCTAssertEqual(resultado.bancoDetectado, "Hey Banco")
        XCTAssertEqual(resultado.ultimosDigitosDetectados, "8803")
    }


    func testHeyBancoConservaResumenYReconstruyeMovimientos() async {
        let digital = """
        \(ExtractorPDF.prefijoResumenDigital)
        HEY BANCO
        Tarjeta **** 2815
        Periodo 14-jun-2026 al 13-jul-2026
        Fecha límite de pago: lunes, 03-ago-2026
        PAGO PARA NO GENERAR INTERESES $ 5,776.46
        PAGO MÍNIMO $ 625.00
        SALDO DEUDOR TOTAL $ 13,985.11

        DESGLOSE DE MOVIMIENTOS
        23-dic-2025 Virtual #4741751767572815 SU PAGO ... GRACIAS $ 19,000.00 $ 8,208.65 $ 92.15 $ 14.74 $ 1,695.46 7 de 12
        24-jun-2026 24-jun-2026 TELCEL +
        $ 549.00
        01-jul-2026 01-jul-2026 CFE SUMINISTRADOR +
        $ 3,532.00
        02-jul-2026 02-jul-2026 SU PAGO GRACIAS -
        $ 2,444.46
        UNIDAD ESPECIALIZADA DE ATENCIÓN A USUARIOS
        """

        let resultado = await AnalizadorEstadoDeCuenta.analizar(paginas: [digital])

        XCTAssertEqual(resultado.bancoDetectado, "Hey Banco")
        XCTAssertEqual(resultado.ultimosDigitosDetectados, "2815")
        XCTAssertEqual(componentes(resultado.fechaCorte), [2026, 7, 13])
        XCTAssertEqual(componentes(resultado.fechaLimitePago), [2026, 8, 3])
        XCTAssertEqual(resultado.pagoParaNoGenerarIntereses, 5_776.46)
        XCTAssertEqual(resultado.pagoMinimo, 625)
        XCTAssertEqual(resultado.saldoAlCorte, 13_985.11)
        XCTAssertEqual(resultado.movimientos.count, 3)
        XCTAssertEqual(resultado.movimientos.filter(\.esMSI).count, 1)
        XCTAssertTrue(resultado.movimientos.contains { $0.comercio.contains("TELCEL") })
        XCTAssertTrue(resultado.movimientos.contains { $0.comercio.contains("CFE") })
        XCTAssertFalse(resultado.movimientos.contains {
            !$0.esMSI && $0.comercio.localizedCaseInsensitiveContains("SU PAGO")
        })
    }

    func testLiverpoolIgnoraPagoYPresupuestoFantasma() async {
        let textoOCR = """
        LIVERPOOL
        Tarjeta **** 1234
        Fecha de corte 13-JUL-2026
        Fecha límite de pago 13-AGO-2026
        Pago para no generar intereses $299.00
        Pago mínimo $30.00
        Saldo al corte $299.00
        03-JUL PIF SUPERIOR 0067806617 PRESUPUESTO 299.00 299.00 30.00 +$299.00
        04-JUL GRACIAS POR SU PAGO -$299.00
        """

        let resultado = await AnalizadorEstadoDeCuenta.analizar(paginas: [textoOCR])

        XCTAssertEqual(resultado.bancoDetectado, "Liverpool")
        XCTAssertEqual(componentes(resultado.fechaCorte), [2026, 7, 13])
        XCTAssertEqual(componentes(resultado.fechaLimitePago), [2026, 8, 13])
        XCTAssertEqual(resultado.pagoParaNoGenerarIntereses, 299)
        XCTAssertEqual(resultado.pagoMinimo, 30)
        XCTAssertEqual(resultado.saldoAlCorte, 299)
        XCTAssertEqual(resultado.movimientos.count, 1)
        XCTAssertEqual(resultado.movimientos.first?.monto, 299)
        XCTAssertFalse(resultado.movimientos.first?.comercio.contains("PRESUPUESTO") ?? true)
    }

    private func componentes(_ fecha: Date?) -> [Int] {
        guard let fecha else { return [] }
        let c = Calendar.current.dateComponents([.year, .month, .day], from: fecha)
        return [c.year, c.month, c.day].compactMap { $0 }
    }
}
