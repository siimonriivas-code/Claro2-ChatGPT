import SwiftData
import XCTest
@testable import Claro

final class AdvancedFeaturesRegressionTests: XCTestCase {
    func testBBVADebitoDistingueNominaYGasto() {
        let texto = """
        ESTADO DE CUENTA BBVA 2026
        SALDO INICIAL $1,000.00
        01/JUL NOMINA CIAPACOV +$27,500.00
        02/JUL PENSION IMSS +$13,200.00
        03/JUL COMPRA TARJETA -$1,250.00
        SALDO FINAL $40,450.00
        """
        let resultado = AnalizadorEstadoDebito.analizar(texto: texto)
        XCTAssertEqual(resultado.banco, "BBVA")
        XCTAssertEqual(resultado.movimientos.count, 3)
        XCTAssertEqual(resultado.movimientos.filter(\.esIngreso).count, 2)
        XCTAssertEqual(resultado.movimientos.filter { !$0.esIngreso }.first?.monto, 1_250)
        XCTAssertEqual(resultado.saldoFinal, 40_450)
    }

    func testIngresoHabitualPendienteEntraEnProyeccion() {
        let banco = Banco(nombre: "BBVA", colorHex: "004481", icono: "building.columns")
        let cuenta = CuentaBancaria(nombre: "Débito", tipo: .debito,
                                    saldoInicial: 1_000, banco: banco)
        let pension = IngresoRecurrente(nombre: "Pensión", montoEsperado: 13_000,
                                        diaInicial: 1, diaFinal: 1, cuenta: cuenta)
        let resumen = MotorClaroInteligente.resumir(
            cuentas: [cuenta], tarjetas: [], personas: [], planes: [], deudas: [],
            movimientos: [], ingresosRecurrentes: [pension], ocurrenciasIngreso: [],
            ahora: fecha(2026, 7, 1))
        XCTAssertEqual(resumen.ingresosRecurrentesPendientes, 13_000)
        XCTAssertGreaterThanOrEqual(resumen.ingresoMensualEstimado, 13_000)
    }

    func testNuevoEsquemaSwiftDataAbreEnMemoria() throws {
        let esquema = Schema([
            Banco.self, CuentaBancaria.self, TarjetaCredito.self, Movimiento.self,
            EstadoDeCuenta.self, PlanMSI.self, MensualidadMSI.self, Persona.self,
            CompraCompartida.self, Participacion.self, Deuda.self, Categoria.self,
            RegistroDeCambio.self, IngresoRecurrente.self,
            OcurrenciaIngresoRecurrente.self, ConversacionFinanciera.self,
            MensajeFinanciero.self, ConciliacionCuentaBancaria.self
        ])
        let contenedor = try ModelContainer(for: esquema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let conversacion = ConversacionFinanciera(titulo: "Prueba")
        contenedor.mainContext.insert(conversacion)
        try contenedor.mainContext.save()
        XCTAssertEqual(try contenedor.mainContext.fetchCount(
            FetchDescriptor<ConversacionFinanciera>()), 1)
    }

    private func fecha(_ ano: Int, _ mes: Int, _ dia: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(
            year: ano, month: mes, day: dia, hour: 12))!
    }
}
