//
//  CoordinadorInferenciaClaro.swift
//  Claro
//
//  Una sola reserva para los motores generativos. Evita que Apple
//  Intelligence y MLX/Qwen intenten ocupar memoria al mismo tiempo, incluso
//  cuando una vista cancela una tarea mientras la inferencia nativa termina.
//

import Foundation

actor CoordinadorInferenciaClaro {
    static let shared = CoordinadorInferenciaClaro()

    enum Motor: Sendable {
        case apple
        case qwen
    }

    struct Reserva: Sendable, Equatable {
        fileprivate let id: UUID
        let motor: Motor
    }

    private var reservaActiva: Reserva?

    func reservar(_ motor: Motor) -> Reserva? {
        guard reservaActiva == nil else { return nil }
        let reserva = Reserva(id: UUID(), motor: motor)
        reservaActiva = reserva
        return reserva
    }

    func liberar(_ reserva: Reserva) {
        guard reservaActiva?.id == reserva.id else { return }
        reservaActiva = nil
    }

    func motorActivo() -> Motor? {
        reservaActiva?.motor
    }
}
