// Módulo aislado de gastos entre personas. Estos modelos no se relacionan
// con cuentas, tarjetas, estados de cuenta ni movimientos financieros.
import Foundation
import SwiftData

@Model
final class GrupoGastosCompartidos {
    var nombre: String
    var fecha: Date
    var creadoEl: Date

    @Relationship(deleteRule: .cascade, inverse: \GastoCompartidoIndependiente.grupo)
    var gastos: [GastoCompartidoIndependiente] = []

    @Relationship(deleteRule: .cascade, inverse: \LiquidacionGastoIndependiente.grupo)
    var liquidaciones: [LiquidacionGastoIndependiente] = []

    init(nombre: String, fecha: Date = .now) {
        self.nombre = nombre
        self.fecha = fecha
        self.creadoEl = .now
    }
}

/// Un pago entre participantes del módulo independiente. Nunca crea un
/// Movimiento ni toca una cuenta o tarjeta de Claro.
@Model
final class LiquidacionGastoIndependiente {
    var monto: Double
    var fecha: Date
    var pagadorEsUsuario: Bool
    var pagadorNombreGuardado: String
    var receptorEsUsuario: Bool
    var receptorNombreGuardado: String
    @Relationship(deleteRule: .nullify) var pagador: Persona?
    @Relationship(deleteRule: .nullify) var receptor: Persona?
    var grupo: GrupoGastosCompartidos?

    init(monto: Double, fecha: Date = .now,
         pagadorEsUsuario: Bool, pagador: Persona?, pagadorNombreGuardado: String,
         receptorEsUsuario: Bool, receptor: Persona?, receptorNombreGuardado: String,
         grupo: GrupoGastosCompartidos?) {
        self.monto = monto.redondeadoAMoneda
        self.fecha = fecha
        self.pagadorEsUsuario = pagadorEsUsuario
        self.pagador = pagador
        self.pagadorNombreGuardado = pagadorNombreGuardado
        self.receptorEsUsuario = receptorEsUsuario
        self.receptor = receptor
        self.receptorNombreGuardado = receptorNombreGuardado
        self.grupo = grupo
    }

    var nombrePagador: String {
        pagadorEsUsuario ? "Tú" : (pagador?.nombre ?? pagadorNombreGuardado)
    }
    var nombreReceptor: String {
        receptorEsUsuario ? "Tú" : (receptor?.nombre ?? receptorNombreGuardado)
    }
}

@Model
final class GastoCompartidoIndependiente {
    var concepto: String
    var monto: Double
    var fecha: Date
    var pagadorEsUsuario: Bool
    var pagadorNombreGuardado: String

    @Relationship(deleteRule: .nullify)
    var pagador: Persona?
    var grupo: GrupoGastosCompartidos?

    @Relationship(deleteRule: .cascade, inverse: \ParteGastoIndependiente.gasto)
    var partes: [ParteGastoIndependiente] = []

    init(concepto: String, monto: Double, fecha: Date = .now,
         pagadorEsUsuario: Bool, pagador: Persona? = nil,
         pagadorNombreGuardado: String, grupo: GrupoGastosCompartidos? = nil) {
        self.concepto = concepto
        self.monto = monto.redondeadoAMoneda
        self.fecha = fecha
        self.pagadorEsUsuario = pagadorEsUsuario
        self.pagador = pagador
        self.pagadorNombreGuardado = pagadorNombreGuardado
        self.grupo = grupo
    }

    var nombrePagador: String {
        pagadorEsUsuario ? "Tú" : (pagador?.nombre ?? pagadorNombreGuardado)
    }
}

@Model
final class ParteGastoIndependiente {
    var monto: Double
    var esUsuario: Bool
    var personaNombreGuardado: String

    @Relationship(deleteRule: .nullify)
    var persona: Persona?
    var gasto: GastoCompartidoIndependiente?

    init(monto: Double, esUsuario: Bool, persona: Persona? = nil,
         personaNombreGuardado: String,
         gasto: GastoCompartidoIndependiente? = nil) {
        self.monto = monto.redondeadoAMoneda
        self.esUsuario = esUsuario
        self.persona = persona
        self.personaNombreGuardado = personaNombreGuardado
        self.gasto = gasto
    }

    var nombreParticipante: String {
        esUsuario ? "Tú" : (persona?.nombre ?? personaNombreGuardado)
    }
}
