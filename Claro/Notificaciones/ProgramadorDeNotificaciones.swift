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

    static let claveDestino = "destinoClaro"
    static let claveIdentificador = "identificadorClaro"

    private static let categoriaImportar = "CLARO_IMPORTAR_ESTADO"
    private static let categoriaPagar = "CLARO_PAGAR_TARJETA"
    private static let categoriaPersona = "CLARO_VER_PERSONA"

    private static let claveIdentificadoresAutomaticos =
        "identificadoresNotificacionesAutomaticas"

    enum ErrorNotificacion: LocalizedError {
        case permisoDenegado

        var errorDescription: String? {
            "Las notificaciones están desactivadas para Claro. Puedes habilitarlas en Ajustes del iPhone."
        }
    }

    /// Registra las acciones y categorías antes de programar avisos. El toque
    /// sobre el cuerpo y el botón visible conducen al mismo destino.
    static func configurarCategorias() {
        let abrirImportador = UNNotificationAction(
            identifier: "ABRIR_IMPORTADOR",
            title: "Subir estado de cuenta",
            options: [.foreground]
        )
        let registrarPago = UNNotificationAction(
            identifier: "REGISTRAR_PAGO",
            title: "Registrar pago",
            options: [.foreground]
        )
        let verPersona = UNNotificationAction(
            identifier: "VER_PERSONA",
            title: "Ver y compartir cobro",
            options: [.foreground]
        )
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: categoriaImportar,
                                   actions: [abrirImportador],
                                   intentIdentifiers: []),
            UNNotificationCategory(identifier: categoriaPagar,
                                   actions: [registrarPago],
                                   intentIdentifiers: []),
            UNNotificationCategory(identifier: categoriaPersona,
                                   actions: [verPersona],
                                   intentIdentifiers: [])
        ])
    }

    /// Pide permiso al sistema para enviar notificaciones (solo la 1a vez).
    static func pedirPermiso(alResponder: ((Bool) -> Void)? = nil) {
        configurarCategorias()
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { autorizado, _ in
                DispatchQueue.main.async { alResponder?(autorizado) }
            }
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
            nuevos.append(identificadorSubirEstado(tarjeta: tarjeta))
            if let estado = tarjeta.estadoDeCuentaVigente,
               estado.faltaPorCubrir > 0 {
                nuevos.append(identificadorCorte(tarjeta: tarjeta))
                nuevos.append(contentsOf: [10, 5, 3, 0].map {
                    identificadorPago(tarjeta: tarjeta, dias: $0)
                })
                nuevos.append(contentsOf: desgloseFamiliar(
                    estado: estado, tarjeta: tarjeta
                ).personas.map {
                    identificadorCobroDeCorte(tarjeta: tarjeta,
                                               persona: $0.persona)
                })
            }
        }
        if personas.contains(where: { $0.saldoPendiente > 0 }) {
            nuevos.append("cobros-semanales")
        }

        centro.removePendingNotificationRequests(
            withIdentifiers: Array(Set(anteriores + nuevos))
        )

        for tarjeta in tarjetas {
            programarAvisoParaSubirEstado(tarjeta: tarjeta, centro: centro)
            guard let estado = tarjeta.estadoDeCuentaVigente,
                  estado.faltaPorCubrir > 0 else { continue }
            programarResumenDeCorte(tarjeta: tarjeta, estado: estado,
                                    centro: centro)
            programarCuentaRegresiva(tarjeta: tarjeta, estado: estado,
                                     centro: centro)
            programarCobrosDeCorte(tarjeta: tarjeta, estado: estado,
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
        preparar(contenido,
                 destino: .verPersona,
                 identificador: persona.identificadorNotificaciones,
                 categoria: categoriaPersona)

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
        preparar(contenido, destino: .verPersonas,
                 identificador: nil, categoria: categoriaPersona)

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
            preparar(contenido,
                     destino: .pagarTarjeta,
                     identificador: tarjeta.identificadorNotificaciones,
                     categoria: categoriaPagar)

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
        if fechaDisparo <= .now {
            // Los importes se conocen al importar el PDF. Si el estado acaba
            // de entrar, entregamos su resumen inmediatamente.
            guard let registrado = estado.registradoEl,
                  Date.now.timeIntervalSince(registrado) < 10 * 60 else { return }
            fechaDisparo = Date.now.addingTimeInterval(5)
            componentes = calendario.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fechaDisparo)
        }

        let resumen = desgloseFamiliar(estado: estado, tarjeta: tarjeta)
        let contenido = UNMutableNotificationContent()
        contenido.title = "✂️ Resumen de \(tarjeta.nombre)"
        contenido.body = "Saldo total \(montoVisible(estado.saldoAlCorte)). Para no generar intereses: tú \(montoVisible(resumen.parteUsuario)); familia \(montoVisible(resumen.parteFamilia))\(resumen.detalle.isEmpty ? "" : " (\(resumen.detalle))")."
        contenido.sound = .default
        preparar(contenido,
                 destino: .verTarjeta,
                 identificador: tarjeta.identificadorNotificaciones,
                 categoria: categoriaPagar)

        centro.add(UNNotificationRequest(
            identifier: identificadorCorte(tarjeta: tarjeta),
            content: contenido,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: componentes, repeats: false)))
    }

    private static func desgloseFamiliar(
        estado: EstadoDeCuenta,
        tarjeta: TarjetaCredito
    ) -> (parteUsuario: Double, parteFamilia: Double, detalle: String,
          personas: [(persona: Persona, monto: Double)]) {
        guard let importacionID = estado.importacionID else {
            return (estado.pagoParaNoGenerarIntereses, 0, "", [])
        }
        let partes = tarjeta.movimientos
            .compactMap(\.compraCompartida)
            .flatMap(\.participaciones)
            .filter { $0.importacionID == importacionID }
        var porPersona: [String: Double] = [:]
        var modelos: [String: Persona] = [:]
        for parte in partes {
            let clave = parte.persona?.identificadorNotificaciones ?? "sin-asignar"
            porPersona[clave, default: 0]
                += parte.monto
            if let persona = parte.persona { modelos[clave] = persona }
        }
        let familia = porPersona.values.reduce(0, +).redondeadoAMoneda
        let propio = max(0, estado.pagoParaNoGenerarIntereses - familia)
            .redondeadoAMoneda
        let detalle = porPersona
            .compactMap { clave, monto -> (String, Double)? in
                guard let persona = modelos[clave] else { return nil }
                return (persona.nombre, monto)
            }
            .sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
            .map { "\($0.0) \(montoVisible($0.1))" }
            .joined(separator: " · ")
        let personas = porPersona.compactMap { clave, monto in
            modelos[clave].map { (persona: $0, monto: monto.redondeadoAMoneda) }
        }
        return (propio, familia, detalle, personas)
    }

    /// Programa el siguiente corte esperado aunque todavía no exista el PDF.
    /// Al abrirlo conduce directamente al importador de esa tarjeta.
    private static func programarAvisoParaSubirEstado(
        tarjeta: TarjetaCredito,
        centro: UNUserNotificationCenter
    ) {
        guard let fecha = siguienteCorteEsperado(tarjeta: tarjeta) else { return }
        let contenido = UNMutableNotificationContent()
        contenido.title = "Ya cortó \(tarjeta.nombre)"
        contenido.body = "Es momento de descargar y subir el nuevo estado de cuenta. Claro verificará fechas, saldos y continuidad antes de guardarlo."
        contenido.sound = .default
        preparar(contenido,
                 destino: .importarEstado,
                 identificador: tarjeta.identificadorNotificaciones,
                 categoria: categoriaImportar)

        let componentes = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fecha)
        centro.add(UNNotificationRequest(
            identifier: identificadorSubirEstado(tarjeta: tarjeta),
            content: contenido,
            trigger: UNCalendarNotificationTrigger(dateMatching: componentes,
                                                   repeats: false)))
    }

    private static func siguienteCorteEsperado(
        tarjeta: TarjetaCredito,
        ahora: Date = .now
    ) -> Date? {
        let calendario = Calendar.current
        func candidato(meses: Int) -> Date? {
            guard let mes = calendario.date(byAdding: .month, value: meses,
                                             to: ahora),
                  let rango = calendario.range(of: .day, in: .month, for: mes)
            else { return nil }
            var componentes = calendario.dateComponents([.year, .month], from: mes)
            componentes.day = min(max(1, tarjeta.diaCorte), rango.count)
            componentes.hour = 10
            componentes.minute = 0
            return calendario.date(from: componentes)
        }

        var fecha = candidato(meses: 0)
        if fecha == nil || fecha! <= ahora.addingTimeInterval(60) {
            fecha = candidato(meses: 1)
        }
        if let fecha,
           tarjeta.estadosDeCuenta.contains(where: {
               calendario.isDate($0.fechaCorte, inSameDayAs: fecha)
           }) {
            return candidato(meses: 1)
        }
        return fecha
    }

    /// Cinco días antes del vencimiento recuerda a quién contactar. El aviso
    /// abre su ficha, donde ya están el desglose y el botón Compartir cobro.
    private static func programarCobrosDeCorte(
        tarjeta: TarjetaCredito,
        estado: EstadoDeCuenta,
        centro: UNUserNotificationCenter
    ) {
        let calendario = Calendar.current
        guard let dia = calendario.date(byAdding: .day, value: -5,
                                        to: calendario.startOfDay(
                                            for: estado.fechaLimitePago))
        else { return }
        var componentes = calendario.dateComponents([.year, .month, .day], from: dia)
        componentes.hour = 10
        guard let fecha = calendario.date(from: componentes), fecha > .now else { return }

        for item in desgloseFamiliar(estado: estado, tarjeta: tarjeta).personas
        where item.monto > 0 {
            let contenido = UNMutableNotificationContent()
            contenido.title = "Recuerda cobrarle a \(item.persona.nombre)"
            contenido.body = "Su parte de \(tarjeta.nombre) es \(montoVisible(item.monto)). El pago vence en 5 días."
            contenido.sound = .default
            preparar(contenido,
                     destino: .verPersona,
                     identificador: item.persona.identificadorNotificaciones,
                     categoria: categoriaPersona)
            centro.add(UNNotificationRequest(
                identifier: identificadorCobroDeCorte(
                    tarjeta: tarjeta, persona: item.persona),
                content: contenido,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: componentes, repeats: false)))
        }
    }

    private static func preparar(
        _ contenido: UNMutableNotificationContent,
        destino: TipoDestinoNotificacion,
        identificador: String?,
        categoria: String
    ) {
        contenido.categoryIdentifier = categoria
        contenido.threadIdentifier = identificador ?? destino.rawValue
        contenido.userInfo[claveDestino] = destino.rawValue
        if let identificador {
            contenido.userInfo[claveIdentificador] = identificador
        }
    }

    private static func montoVisible(_ monto: Double) -> String {
        let ocultar = UserDefaults.standard.bool(forKey: "montosOcultos")
            || !UserDefaults.standard.bool(forKey: "mostrarMontosEnNotificaciones")
        return ocultar
            ? "••••" : monto.comoDinero
    }

    private static func identificadorPago(tarjeta: TarjetaCredito,
                                          dias: Int) -> String {
        "pago-\(tarjeta.identificadorNotificaciones)-\(dias)"
    }

    private static func identificadorCorte(tarjeta: TarjetaCredito) -> String {
        "corte-\(tarjeta.identificadorNotificaciones)"
    }

    private static func identificadorSubirEstado(
        tarjeta: TarjetaCredito
    ) -> String {
        "subir-estado-\(tarjeta.identificadorNotificaciones)"
    }

    private static func identificadorCobroDeCorte(
        tarjeta: TarjetaCredito,
        persona: Persona
    ) -> String {
        "cobro-corte-\(tarjeta.identificadorNotificaciones)-\(persona.identificadorNotificaciones)"
    }
}
