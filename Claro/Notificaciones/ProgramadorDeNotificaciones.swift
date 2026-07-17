//
//  ProgramadorDeNotificaciones.swift
//  Claro — Carpeta: Notificaciones
//
//  Recordatorios específicos por tarjeta con cuenta regresiva:
//  10, 5, 3 y 1 día antes, y el día del vencimiento (a las 9:00 am).
//  Si un corte ya está cubierto, sus recordatorios desaparecen solos,
//  porque cada vez que abres la app TODO se reprograma desde cero
//  con los montos reales que faltan.
//

import Foundation
import UserNotifications

enum ProgramadorDeNotificaciones {

    /// Pide permiso al sistema para enviar notificaciones (solo la 1a vez).
    static func pedirPermiso() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Borra todo lo programado y vuelve a programar según la realidad
    /// actual: cortes con dinero pendiente y cobros que te deben.
    static func reprogramar(tarjetas: [TarjetaCredito],
                            personas: [Persona] = []) {
        let centro = UNUserNotificationCenter.current()
        centro.removeAllPendingNotificationRequests()

        for tarjeta in tarjetas {
            guard let estado = tarjeta.estadoDeCuentaVigente,
                  estado.faltaPorCubrir > 0 else { continue }
            programarCuentaRegresiva(tarjeta: tarjeta, estado: estado,
                                     centro: centro)
        }

        programarCobrosPendientes(personas: personas, centro: centro)
    }

    /// Recordatorio semanal (lunes 10:00 am) de lo que te deben.
    /// Se reconstruye con montos frescos cada vez que abres la app,
    /// y desaparece solo cuando ya nadie te debe.
    private static func programarCobrosPendientes(personas: [Persona],
                                                  centro: UNUserNotificationCenter) {
        let pendientes = personas
            .filter { $0.saldoPendiente > 0 }
            .sorted { $0.saldoPendiente > $1.saldoPendiente }
        guard !pendientes.isEmpty else { return }

        let total = pendientes.reduce(0) { $0 + $1.saldoPendiente }
        var detalle = pendientes.prefix(3)
            .map { "\($0.nombre): \($0.saldoPendiente.comoDinero)" }
            .joined(separator: " · ")
        if pendientes.count > 3 { detalle += " y más…" }

        let contenido = UNMutableNotificationContent()
        contenido.title = "💰 Te deben \(total.comoDinero)"
        contenido.body = detalle
        contenido.sound = .default

        var componentes = DateComponents()
        componentes.weekday = 2   // lunes
        componentes.hour = 10

        centro.add(UNNotificationRequest(
            identifier: "cobros-semanales",
            content: contenido,
            trigger: UNCalendarNotificationTrigger(dateMatching: componentes,
                                                   repeats: true)))
    }

    private static func programarCuentaRegresiva(tarjeta: TarjetaCredito,
                                                 estado: EstadoDeCuenta,
                                                 centro: UNUserNotificationCenter) {
        let calendario = Calendar.current
        let diasAntes = [10, 5, 3, 1, 0]
        let falta = estado.faltaPorCubrir.comoDinero

        for dias in diasAntes {
            guard let diaAviso = calendario.date(
                byAdding: .day, value: -dias,
                to: calendario.startOfDay(for: estado.fechaLimitePago))
            else { continue }

            var componentes = calendario.dateComponents([.year, .month, .day],
                                                        from: diaAviso)
            componentes.hour = 9

            // Solo programar avisos que aún están en el futuro
            guard let fechaDisparo = calendario.date(from: componentes),
                  fechaDisparo > .now else { continue }

            let contenido = UNMutableNotificationContent()
            contenido.sound = .default

            switch dias {
            case 0:
                contenido.title = "🔴 HOY vence \(tarjeta.nombre)"
                contenido.body = "Falta cubrir \(falta) para no generar intereses."
            case 1:
                contenido.title = "🔴 Mañana vence \(tarjeta.nombre)"
                contenido.body = "Falta cubrir \(falta) para no generar intereses."
            case 3:
                contenido.title = "⚠️ Faltan 3 días · \(tarjeta.nombre)"
                contenido.body = "Aún debes \(falta) para no generar intereses."
            default:
                contenido.title = "Faltan \(dias) días · \(tarjeta.nombre)"
                contenido.body = "Pago para no generar intereses: \(falta)."
            }

            let disparador = UNCalendarNotificationTrigger(
                dateMatching: componentes, repeats: false)
            let peticion = UNNotificationRequest(
                identifier: "pago-\(tarjeta.nombre)-\(dias)",
                content: contenido,
                trigger: disparador)
            centro.add(peticion)
        }
    }
}
