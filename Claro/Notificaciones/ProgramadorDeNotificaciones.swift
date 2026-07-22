//
//  ProgramadorDeNotificaciones.swift
//  Claro — Carpeta: Notificaciones
//
//  Recordatorios específicos por tarjeta: resumen en el día de corte,
//  10, 5 y 3 días antes, y el día del vencimiento (a las 9:00 am).
//  Si un corte ya está cubierto, sus recordatorios desaparecen solos,
//  porque cada vez que abres la app TODO se reprograma desde cero
//  con los montos reales que faltan.
//

import Foundation
import UserNotifications

enum ProgramadorDeNotificaciones {

    private static let claveIdentificadoresAutomaticos =
        "identificadoresNotificacionesAutomaticas"

    enum ErrorNotificacion: LocalizedError {
        case permisoDenegado

        var errorDescription: String? {
            "Las notificaciones están desactivadas para Claro. Puedes habilitarlas en Ajustes del iPhone."
        }
    }

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

        // Retiramos únicamente los avisos automáticos creados por Claro.
        // Los recordatorios puntuales que el usuario programó para cobrar
        // a una persona se conservan.
        let anteriores = UserDefaults.standard.stringArray(
            forKey: claveIdentificadoresAutomaticos
        ) ?? []
        var nuevos: [String] = []

        for tarjeta in tarjetas {
            guard let estado = tarjeta.estadoDeCuentaVigente,
                  estado.faltaPorCubrir > 0 else { continue }
            nuevos.append(identificadorCorte(tarjeta: tarjeta))
            nuevos.append(contentsOf: [10, 5, 3, 0].map {
                identificadorPago(tarjeta: tarjeta, dias: $0)
            })
        }
        if personas.contains(where: { $0.saldoPendiente > 0 }) {
            nuevos.append("cobros-semanales")
        }

        centro.removePendingNotificationRequests(
            withIdentifiers: Array(Set(anteriores + nuevos))
        )

        for tarjeta in tarjetas {
            guard let estado = tarjeta.estadoDeCuentaVigente,
                  estado.faltaPorCubrir > 0 else { continue }
            programarResumenDeCorte(tarjeta: tarjeta, estado: estado,
                                    centro: centro)
            programarCuentaRegresiva(tarjeta: tarjeta, estado: estado,
                                     centro: centro)
        }

        programarCobrosPendientes(personas: personas, centro: centro)
        UserDefaults.standard.set(nuevos,
                                  forKey: claveIdentificadoresAutomaticos)
    }

    /// Se usa al apagar las notificaciones desde Configuración o al borrar
    /// todos los datos. En ese caso sí se retiran avisos automáticos y manuales.
    static func cancelarTodas() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UserDefaults.standard.removeObject(
            forKey: claveIdentificadoresAutomaticos
        )
    }

    /// Crea un aviso puntual para cobrarle a una persona. Complementa el
    /// resumen semanal automático con una fecha elegida por el usuario.
    static func programarCobro(persona: Persona, fecha: Date) async throws {
        let centro = UNUserNotificationCenter.current()
        let autorizado = try await centro.requestAuthorization(
            options: [.alert, .sound, .badge]
        )
        guard autorizado else { throw ErrorNotificacion.permisoDenegado }

        let contenido = UNMutableNotificationContent()
        contenido.title = "Recordatorio de cobro · \(persona.nombre)"
        contenido.body = "Saldo pendiente: \(max(0, persona.saldoPendiente).comoDinero)."
        contenido.sound = .default

        let componentes = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fecha
        )
        let solicitud = UNNotificationRequest(
            identifier: "cobro-\(UUID().uuidString)",
            content: contenido,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: componentes,
                repeats: false
            )
        )
        try await centro.add(solicitud)
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
        let diasAntes = [10, 5, 3, 0]
        let falta = montoVisible(estado.faltaPorCubrir)

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
                identifier: identificadorPago(tarjeta: tarjeta, dias: dias),
                content: contenido,
                trigger: disparador)
            centro.add(peticion)
        }
    }

    private static func programarResumenDeCorte(
        tarjeta: TarjetaCredito,
        estado: EstadoDeCuenta,
        centro: UNUserNotificationCenter
    ) {
        let calendario = Calendar.current
        let inicioDia = calendario.startOfDay(for: estado.fechaCorte)
        var componentes = calendario.dateComponents([.year, .month, .day],
                                                    from: inicioDia)
        componentes.hour = 9
        var fechaDisparo = calendario.date(from: componentes) ?? inicioDia
        if calendario.isDateInToday(estado.fechaCorte), fechaDisparo <= .now {
            fechaDisparo = Date.now.addingTimeInterval(5)
            componentes = calendario.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fechaDisparo)
        }
        guard fechaDisparo > .now else { return }

        let resumen = desgloseFamiliar(estado: estado, tarjeta: tarjeta)
        let contenido = UNMutableNotificationContent()
        contenido.title = "✂️ Ya cortó \(tarjeta.nombre)"
        contenido.body = "Saldo total \(montoVisible(estado.saldoAlCorte)). Para no generar intereses: tú \(montoVisible(resumen.parteUsuario)); familia \(montoVisible(resumen.parteFamilia))\(resumen.detalle.isEmpty ? "" : " (\(resumen.detalle))")."
        contenido.sound = .default

        centro.add(UNNotificationRequest(
            identifier: identificadorCorte(tarjeta: tarjeta),
            content: contenido,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: componentes, repeats: false)))
    }

    private static func desgloseFamiliar(
        estado: EstadoDeCuenta,
        tarjeta: TarjetaCredito
    ) -> (parteUsuario: Double, parteFamilia: Double, detalle: String) {
        guard let importacionID = estado.importacionID else {
            return (estado.pagoParaNoGenerarIntereses, 0, "")
        }
        let partes = tarjeta.movimientos
            .compactMap(\.compraCompartida)
            .flatMap(\.participaciones)
            .filter { $0.importacionID == importacionID }
        var porPersona: [String: Double] = [:]
        for parte in partes {
            porPersona[parte.persona?.nombre ?? "Sin asignar", default: 0]
                += parte.monto
        }
        let familia = porPersona.values.reduce(0, +).redondeadoAMoneda
        let propio = max(0, estado.pagoParaNoGenerarIntereses - familia)
            .redondeadoAMoneda
        let detalle = porPersona
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { "\($0.key) \(montoVisible($0.value))" }
            .joined(separator: " · ")
        return (propio, familia, detalle)
    }

    private static func montoVisible(_ monto: Double) -> String {
        UserDefaults.standard.bool(forKey: "montosOcultos")
            ? "••••" : monto.comoDinero
    }

    private static func identificadorPago(tarjeta: TarjetaCredito,
                                          dias: Int) -> String {
        "pago-\(tarjeta.nombre)-\(dias)"
    }

    private static func identificadorCorte(tarjeta: TarjetaCredito) -> String {
        "corte-\(tarjeta.nombre)"
    }
}
