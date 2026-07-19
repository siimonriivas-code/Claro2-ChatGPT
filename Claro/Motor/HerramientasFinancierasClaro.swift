import Foundation

enum OperacionHerramientaFinanciera: String {
    case buscarTarjeta
    case compararDeudas
    case consultarMovimientos
    case simularPrestamo
    case proyectarSaldo
}

struct ResultadoHerramientaFinanciera {
    let operacion: OperacionHerramientaFinanciera
    let texto: String
}

/// Capa estable entre el lenguaje libre y las cuentas deterministas. Los
/// modelos redactan; estas herramientas buscan, comparan y calculan.
enum HerramientasFinancierasClaro {
    static func ejecutar(intencion: IntencionConsultaClaro,
                         pregunta: String,
                         resumen: ResumenFinancieroClaro) -> ResultadoHerramientaFinanciera? {
        let operacion: OperacionHerramientaFinanciera
        switch intencion.metrica {
        case .deudaTarjeta, .saldoAlCorte, .pagoParaNoGenerarIntereses,
             .pagoMinimo, .pagadoDelCorte, .faltaDelCorte,
             .limiteCredito, .creditoDisponible, .fechaCorte, .fechaLimite,
             .mayorDeudaTarjeta, .menorDeudaTarjeta:
            operacion = .buscarTarjeta
        case .prioridadDePago, .deudaTotalTarjetas, .deudaConAcreedor:
            operacion = .compararDeudas
        case .movimientos, .ingresos, .gastos:
            operacion = .consultarMovimientos
        case .prestamo:
            operacion = .simularPrestamo
        case .proyeccionFinDeMes, .saldoCuenta, .disponibleReal:
            operacion = .proyectarSaldo
        default:
            return nil
        }
        guard let texto = MotorClaroInteligente.respuestaFactualExacta(
            intencion: intencion, pregunta: pregunta, resumen: resumen) else { return nil }
        return ResultadoHerramientaFinanciera(operacion: operacion, texto: texto)
    }
}
