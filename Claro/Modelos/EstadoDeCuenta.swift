//
//  EstadoDeCuenta.swift
//  Claro — Carpeta: Modelos
//
//  La "cuenta del restaurante" de cada tarjeta en cada corte.
//  ⚠️ LEY 2: un estado de cuenta INFORMA cuánto debes; NO es un pago.
//  ⚠️ LEY 1: lo pagado de este estado de cuenta NO se guarda aquí;
//  lo calculará el Motor sumando los pagos reales registrados.
//

import Foundation
import SwiftData

@Model
final class EstadoDeCuenta {
    var fechaCorte: Date
    var fechaLimitePago: Date
    var inicioPeriodo: Date        // periodo de compras que abarca
    var finPeriodo: Date

    var pagoParaNoGenerarIntereses: Double
    var pagoMinimo: Double
    var saldoAlCorte: Double       // lo que el banco reportó al corte

    // Metadatos locales de la importación. No se conserva el PDF: solo su
    // huella para detectar duplicados y el nombre para el historial.
    var importacionID: UUID? = nil
    var huellaPDF: String? = nil
    var archivoOrigen: String? = nil
    var bancoDetectado: String? = nil

    // Momento en que este corte entró a Claro. Permite reconstruir qué
    // estado estaba vigente cuando se capturó un pago, aunque el usuario
    // haya elegido una fecha distinta para ese movimiento.
    var registradoEl: Date? = nil

    // Evidencia de conciliación extraída del resumen bancario.
    var adeudoPeriodoAnteriorReportado: Double? = nil
    var cargosYCostosPeriodoReportados: Double? = nil
    var pagosYAbonosPeriodoReportados: Double? = nil

    var tarjeta: TarjetaCredito?

    // Mensualidades MSI que el banco incluyó en este corte.
    // .nullify = si se borra el estado de cuenta, las mensualidades
    // NO se borran (pertenecen a su plan), solo se desvinculan.
    @Relationship(deleteRule: .nullify, inverse: \MensualidadMSI.estadoDeCuenta)
    var mensualidadesIncluidas: [MensualidadMSI] = []

    init(fechaCorte: Date,
         fechaLimitePago: Date,
         inicioPeriodo: Date,
         finPeriodo: Date,
         pagoParaNoGenerarIntereses: Double,
         pagoMinimo: Double,
         saldoAlCorte: Double,
         tarjeta: TarjetaCredito? = nil) {
        self.fechaCorte = fechaCorte
        self.fechaLimitePago = fechaLimitePago
        self.inicioPeriodo = inicioPeriodo
        self.finPeriodo = finPeriodo
        self.pagoParaNoGenerarIntereses = pagoParaNoGenerarIntereses.redondeadoAMoneda
        self.pagoMinimo = pagoMinimo.redondeadoAMoneda
        self.saldoAlCorte = saldoAlCorte.redondeadoAMoneda
        self.tarjeta = tarjeta
        self.registradoEl = .now
    }
}
