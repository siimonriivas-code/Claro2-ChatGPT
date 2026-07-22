//
//  MotorFusionCuentas.swift
//  Claro
//
//  Une dos registros que en realidad representan la misma cuenta bancaria.
//  Conserva todos los movimientos y el saldo combinado.
//

import Foundation
import SwiftData

@MainActor
enum MotorFusionCuentas {

    static func fusionar(origen: CuentaBancaria,
                         en destino: CuentaBancaria,
                         contexto: ModelContext) throws {
        guard origen.persistentModelID != destino.persistentModelID else {
            throw ErrorFusionCuentas.mismaCuenta
        }
        guard origen.banco?.persistentModelID == destino.banco?.persistentModelID else {
            throw ErrorFusionCuentas.bancosDiferentes
        }

        // Conservamos una foto exacta del dinero combinado. Sumar dos saldos
        // iniciales es incorrecto cuando fueron capturados en fechas que se
        // traslapan; la nueva foto evita duplicar movimientos históricos.
        let saldoCombinado = (origen.saldoCalculado + destino.saldoCalculado)
            .redondeadoAMoneda

        // Copias estables: al reasignar relaciones SwiftData modifica las
        // colecciones de ambas cuentas inmediatamente.
        let movimientosQueSalen = Array(origen.movimientos)
        let transferenciasQueLlegan = Array(origen.movimientosEntrantes)

        for movimiento in movimientosQueSalen {
            if movimiento.tipo == .transferencia,
               movimiento.cuentaDestino?.persistentModelID == destino.persistentModelID {
                // Era una transferencia entre dos registros de la misma cuenta.
                // Al fusionar no debe transformarse en gasto ni aparecer dos veces.
                movimiento.cuenta = destino
                movimiento.cuentaDestino = nil
                cancelarTransferenciaInterna(movimiento)
            } else {
                movimiento.cuenta = destino
            }
        }

        for movimiento in transferenciasQueLlegan {
            if movimiento.tipo == .transferencia,
               movimiento.cuenta?.persistentModelID == destino.persistentModelID {
                movimiento.cuentaDestino = nil
                cancelarTransferenciaInterna(movimiento)
            } else {
                movimiento.cuentaDestino = destino
            }
        }

        destino.saldoInicial = saldoCombinado
        destino.fechaSaldoInicial = .now
        origen.archivada = true
        try contexto.save()
    }

    static func cantidadMovimientosUnicos(_ cuenta: CuentaBancaria) -> Int {
        Set((cuenta.movimientos + cuenta.movimientosEntrantes)
            .map(\.persistentModelID)).count
    }

    private static func cancelarTransferenciaInterna(_ movimiento: Movimiento) {
        movimiento.estado = .cancelado
        movimiento.editadoEl = .now
        let nota = "Fusionada: transferencia entre registros de la misma cuenta"
        if movimiento.detalle.isEmpty {
            movimiento.detalle = nota
        } else if !movimiento.detalle.contains(nota) {
            movimiento.detalle += " · \(nota)"
        }
    }
}

enum ErrorFusionCuentas: LocalizedError {
    case mismaCuenta
    case bancosDiferentes

    var errorDescription: String? {
        switch self {
        case .mismaCuenta:
            return "Selecciona una cuenta diferente."
        case .bancosDiferentes:
            return "Solo se pueden fusionar cuentas del mismo banco."
        }
    }
}
