// Modelos avanzados añadidos después de la primera versión.
import Foundation
import SwiftData

enum EstadoIngresoRecurrente: String, Codable, CaseIterable {
    case esperado = "Esperado"
    case recibido = "Recibido"
    case retrasado = "Retrasado"
    case omitido = "Omitido"
}

@Model final class IngresoRecurrente {
    var nombre: String
    var montoEsperado: Double
    var diaInicial: Int
    var diaFinal: Int
    var activo: Bool
    var creadoEl: Date
    var cuenta: CuentaBancaria?
    @Relationship(deleteRule: .cascade, inverse: \OcurrenciaIngresoRecurrente.ingreso)
    var ocurrencias: [OcurrenciaIngresoRecurrente] = []

    init(nombre: String, montoEsperado: Double, diaInicial: Int, diaFinal: Int,
         cuenta: CuentaBancaria? = nil, activo: Bool = true) {
        self.nombre = nombre
        self.montoEsperado = montoEsperado.redondeadoAMoneda
        let inicio = min(28, max(1, diaInicial))
        self.diaInicial = inicio
        self.diaFinal = min(28, max(inicio, diaFinal))
        self.cuenta = cuenta
        self.activo = activo
        self.creadoEl = .now
    }
}

@Model final class OcurrenciaIngresoRecurrente {
    var mes: Date
    var estadoRaw: String
    var montoRecibido: Double
    var fechaRecibida: Date?
    var ingreso: IngresoRecurrente?
    var movimiento: Movimiento?
    var estado: EstadoIngresoRecurrente {
        get { EstadoIngresoRecurrente(rawValue: estadoRaw) ?? .esperado }
        set { estadoRaw = newValue.rawValue }
    }
    init(mes: Date, estado: EstadoIngresoRecurrente = .esperado,
         montoRecibido: Double = 0, fechaRecibida: Date? = nil,
         ingreso: IngresoRecurrente? = nil, movimiento: Movimiento? = nil) {
        self.mes = Calendar.current.dateInterval(of: .month, for: mes)?.start ?? mes
        self.estadoRaw = estado.rawValue
        self.montoRecibido = montoRecibido.redondeadoAMoneda
        self.fechaRecibida = fechaRecibida
        self.ingreso = ingreso
        self.movimiento = movimiento
    }
}

@Model final class ConversacionFinanciera {
    var titulo: String
    var creadaEl: Date
    var actualizadaEl: Date
    var resumen: String
    @Relationship(deleteRule: .cascade, inverse: \MensajeFinanciero.conversacion)
    var mensajes: [MensajeFinanciero] = []
    init(titulo: String = "Nueva conversación") {
        self.titulo = titulo
        self.creadaEl = .now
        self.actualizadaEl = .now
        self.resumen = ""
    }
}

@Model final class MensajeFinanciero {
    var esUsuario: Bool
    var texto: String
    var fuenteRaw: String?
    var ambitoRaw: String
    var creadoEl: Date
    var conversacion: ConversacionFinanciera?
    init(esUsuario: Bool, texto: String, fuenteRaw: String? = nil,
         ambitoRaw: String, conversacion: ConversacionFinanciera? = nil) {
        self.esUsuario = esUsuario
        self.texto = texto
        self.fuenteRaw = fuenteRaw
        self.ambitoRaw = ambitoRaw
        self.creadoEl = .now
        self.conversacion = conversacion
    }
}

@Model final class ConciliacionCuentaBancaria {
    var bancoDetectado: String
    var archivoOrigen: String
    var fechaInicial: Date?
    var fechaFinal: Date?
    var saldoInicialReportado: Double?
    var saldoFinalReportado: Double?
    var saldoCalculadoAlImportar: Double
    var movimientosImportados: Int
    var importacionID: UUID
    var creadaEl: Date
    var cuenta: CuentaBancaria?
    init(bancoDetectado: String, archivoOrigen: String, cuenta: CuentaBancaria?,
         fechaInicial: Date? = nil, fechaFinal: Date? = nil,
         saldoInicialReportado: Double? = nil, saldoFinalReportado: Double? = nil,
         saldoCalculadoAlImportar: Double, movimientosImportados: Int,
         importacionID: UUID = UUID()) {
        self.bancoDetectado = bancoDetectado
        self.archivoOrigen = archivoOrigen
        self.cuenta = cuenta
        self.fechaInicial = fechaInicial
        self.fechaFinal = fechaFinal
        self.saldoInicialReportado = saldoInicialReportado
        self.saldoFinalReportado = saldoFinalReportado
        self.saldoCalculadoAlImportar = saldoCalculadoAlImportar.redondeadoAMoneda
        self.movimientosImportados = movimientosImportados
        self.importacionID = importacionID
        self.creadaEl = .now
    }
    var diferencia: Double? {
        saldoFinalReportado.map { ($0 - saldoCalculadoAlImportar).redondeadoAMoneda }
    }
}
