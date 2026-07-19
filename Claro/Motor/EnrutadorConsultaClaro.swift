//
//  EnrutadorConsultaClaro.swift
//  Claro
//
//  Interpreta la intención antes de decidir qué motor puede responder.
//  Es deliberadamente puro: no carga Apple Intelligence, Qwen ni SwiftData.
//

import Foundation

enum ActoConversacionalClaro: Equatable {
    case saludo
    case charla
    case pregunta
    case seguimiento
    case correccion
    case rechazo
    case confirmacion
    case cancelacion
    case cambioDeTema
    case emocion
}

enum MetricaConsultaClaro: Equatable {
    case panorama
    case disponibleReal
    case proyeccionFinDeMes
    case riesgo
    case prestamo
    case deudaTotalTarjetas
    case deudaTarjeta
    case mayorDeudaTarjeta
    case menorDeudaTarjeta
    case prioridadDePago
    case saldoAlCorte
    case pagoParaNoGenerarIntereses
    case pagoMinimo
    case pagadoDelCorte
    case faltaDelCorte
    case limiteCredito
    case creditoDisponible
    case fechaCorte
    case fechaLimite
    case saldoCuenta
    case porCobrarPersona
    case deudaConAcreedor
    case ingresos
    case gastos
    case patrimonio
    case movimientos
    case desconocida
}

enum TipoEntidadClaro: Equatable, Hashable {
    case tarjeta
    case cuenta
    case persona
    case acreedor
}

struct ReferenciaEntidadClaro: Equatable, Hashable {
    let tipo: TipoEntidadClaro
    let nombre: String
}

struct IntencionConsultaClaro: Equatable {
    let ambito: AmbitoConsultaClaro
    let acto: ActoConversacionalClaro
    let metrica: MetricaConsultaClaro
    /// Conserva todas las métricas explícitas de una pregunta compuesta.
    /// `metrica` sigue siendo la principal para mantener compatibilidad.
    let metricasSolicitadas: [MetricaConsultaClaro]
    let entidades: [ReferenciaEntidadClaro]
    let dependeDelHistorial: Bool
    let pideTotal: Bool
    let pideComparacion: Bool
    let esEspecifica: Bool
}

struct DecisionConsultaClaro: Equatable {
    let intencion: IntencionConsultaClaro
    let requiereInterpretacionSemantica: Bool
}

enum EnrutadorConsultaClaro {

    static func decidir(
        pregunta: String,
        historial: [TurnoConversacionClaro],
        resumen: ResumenFinancieroClaro?
    ) -> DecisionConsultaClaro {
        let texto = normalizar(pregunta)
        let palabras = texto.split(separator: " ").map(String.init)
        let ultimaEsPersonal = historial.last?.ambito == .finanzasPersonales

        guard !texto.isEmpty else {
            return decision(.general, .charla, .desconocida)
        }

        if let contenidoNuevo = contenidoDespuesDeMarcador(texto),
           !contenidoNuevo.resto.isEmpty {
            let decisionNueva = decidir(
                pregunta: contenidoNuevo.resto, historial: [], resumen: resumen)
            return DecisionConsultaClaro(
                intencion: IntencionConsultaClaro(
                    ambito: decisionNueva.intencion.ambito,
                    acto: contenidoNuevo.acto,
                    metrica: decisionNueva.intencion.metrica,
                    metricasSolicitadas:
                        decisionNueva.intencion.metricasSolicitadas,
                    entidades: decisionNueva.intencion.entidades,
                    dependeDelHistorial: false,
                    pideTotal: decisionNueva.intencion.pideTotal,
                    pideComparacion: decisionNueva.intencion.pideComparacion,
                    esEspecifica: decisionNueva.intencion.esEspecifica),
                requiereInterpretacionSemantica:
                    decisionNueva.requiereInterpretacionSemantica)
        }

        if coincideAlguna(texto, correcciones) {
            return decision(.general, .correccion, .desconocida)
        }
        if coincideAlguna(texto, cancelaciones) {
            return decision(.general, .cancelacion, .desconocida)
        }

        if esSaludoOCharlaAutocontenida(texto) {
            let acto: ActoConversacionalClaro = esSaludo(texto) ? .saludo : .charla
            return decision(.general, acto, .desconocida)
        }

        let entidadesDetectadas = entidadesMencionadas(en: texto, resumen: resumen)
        let metricas = metricasSolicitadas(
            en: texto, entidades: entidadesDetectadas)
        let metrica = metricas.first ?? .desconocida
        let entidades = entidadesCompatibles(
            entidadesDetectadas, con: metrica, texto: texto)
        let pideTotal = contieneAlgunaPalabra(
            palabras, ["total", "suma", "sumando", "juntas", "juntos", "entre"])
        let pideComparacion = metrica == .mayorDeudaTarjeta
            || metrica == .menorDeudaTarjeta
            || metrica == .prioridadDePago
            || coincideAlguna(texto, ["compara", "comparacion", "ordena", "mayor", "menor"])

        if esRechazoBreve(texto), ultimaEsPersonal {
            return decision(
                .finanzasPersonales, .rechazo, metrica,
                entidades: entidades, dependeDelHistorial: true,
                pideTotal: pideTotal, pideComparacion: pideComparacion,
                metricas: metricas)
        }
        if esConfirmacionBreve(texto), ultimaEsPersonal {
            return decision(
                .finanzasPersonales, .confirmacion, metrica,
                entidades: entidades, dependeDelHistorial: true,
                pideTotal: pideTotal, pideComparacion: pideComparacion,
                metricas: metricas)
        }
        if coincideAlguna(texto, emociones) {
            return decision(.general, .emocion, .desconocida)
        }

        let definicion = esPeticionDeDefinicion(texto)
        let temaFinanciero = contieneTemaFinanciero(texto)
        let marcadorEducativo = coincideAlguna(texto, marcadoresEducativos)
        let marcadorCorporativo = coincideAlguna(texto, marcadoresCorporativos)
        let referenciaPersonal = contieneReferenciaFinancieraPersonal(
            texto, palabras: palabras, metrica: metrica,
            tieneEntidad: !entidades.isEmpty)
            || (!entidades.isEmpty && (pideTotal || pideComparacion))

        // Preguntar qué es o cómo funciona una empresa/banco nombrado es una
        // consulta general sobre esa entidad, no educación financiera ni una
        // autorización para abrir los datos privados del usuario.
        if definicion, !entidadesDetectadas.isEmpty,
           metrica == .desconocida, !referenciaPersonal {
            return decision(.general, .pregunta, .desconocida)
        }

        // Una definición o estrategia genérica jamás recibe el resumen
        // privado, aunque mencione tarjetas, bancos, deuda o intereses.
        if (definicion || marcadorEducativo || marcadorCorporativo),
           temaFinanciero, !referenciaPersonal {
            return decision(
                .educacionFinanciera, .pregunta, metrica,
                entidades: [], pideTotal: pideTotal,
                pideComparacion: pideComparacion, metricas: metricas)
        }

        if referenciaPersonal {
            return decision(
                .finanzasPersonales, .pregunta, metrica,
                entidades: entidades, pideTotal: pideTotal,
                pideComparacion: pideComparacion, metricas: metricas)
        }

        if ultimaEsPersonal,
           esSeguimientoDependiente(texto, palabras: palabras,
                                    entidades: entidades, metrica: metrica) {
            return decision(
                .finanzasPersonales, .seguimiento, metrica,
                entidades: entidades, dependeDelHistorial: true,
                pideTotal: pideTotal, pideComparacion: pideComparacion,
                metricas: metricas)
        }

        if temaFinanciero {
            // Sin primera persona ni una referencia dependiente, se trata de
            // educación financiera y no se comparte ningún dato del usuario.
            return decision(
                .educacionFinanciera, .pregunta, metrica,
                entidades: [], pideTotal: pideTotal,
                pideComparacion: pideComparacion, metricas: metricas)
        }

        // Preguntas autocontenidas de cultura general no necesitan un segundo
        // clasificador. Las frases realmente ambiguas sí pueden beneficiarse
        // de la lectura semántica local de Apple.
        let autocontenida = esPreguntaGeneralAutocontenida(texto)
        return DecisionConsultaClaro(
            intencion: IntencionConsultaClaro(
                ambito: .general,
                acto: .pregunta,
                metrica: .desconocida,
                metricasSolicitadas: [],
                entidades: [],
                dependeDelHistorial: false,
                pideTotal: false,
                pideComparacion: false,
                esEspecifica: true),
            requiereInterpretacionSemantica: !autocontenida)
    }

    static func normalizar(_ texto: String) -> String {
        texto
            .folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "es_MX"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func decision(
        _ ambito: AmbitoConsultaClaro,
        _ acto: ActoConversacionalClaro,
        _ metrica: MetricaConsultaClaro,
        entidades: [ReferenciaEntidadClaro] = [],
        dependeDelHistorial: Bool = false,
        pideTotal: Bool = false,
        pideComparacion: Bool = false,
        metricas: [MetricaConsultaClaro] = []
    ) -> DecisionConsultaClaro {
        DecisionConsultaClaro(
            intencion: IntencionConsultaClaro(
                ambito: ambito,
                acto: acto,
                metrica: metrica,
                metricasSolicitadas: metricas.isEmpty && metrica != .desconocida
                    ? [metrica] : metricas,
                entidades: entidades,
                dependeDelHistorial: dependeDelHistorial,
                pideTotal: pideTotal,
                pideComparacion: pideComparacion,
                esEspecifica: metrica != .panorama && metrica != .desconocida),
            requiereInterpretacionSemantica: false)
    }

    private static func metricasSolicitadas(
        en texto: String,
        entidades: [ReferenciaEntidadClaro]
    ) -> [MetricaConsultaClaro] {
        var segmentos = [texto]
        for separador in [" y ", " ademas ", " tambien ", ",", ";"] {
            segmentos = segmentos.flatMap {
                $0.components(separatedBy: separador)
            }
        }
        var resultado: [MetricaConsultaClaro] = []
        for segmento in segmentos {
            let metrica = metricaSolicitada(en: segmento, entidades: entidades)
            if metrica != .desconocida && !resultado.contains(metrica) {
                resultado.append(metrica)
            }
        }
        if resultado.isEmpty {
            let principal = metricaSolicitada(en: texto, entidades: entidades)
            if principal != .desconocida { resultado.append(principal) }
        }
        return resultado
    }

    private static func metricaSolicitada(
        en texto: String,
        entidades: [ReferenciaEntidadClaro]
    ) -> MetricaConsultaClaro {
        if coincideAlguna(texto, [
            "pago para no generar intereses", "para no generar intereses", "pngi",
            "para evitar intereses", "evitar pagar intereses",
            "no pagar intereses", "no cobrar intereses", "sin intereses"
        ]) { return .pagoParaNoGenerarIntereses }
        if coincideAlguna(texto, [
            "pago minimo", "minimo a pagar", "cuanto es el minimo",
            "cuanto debo pagar minimo", "minimo de", "paga el minimo",
            "pagar el minimo"
        ]) { return .pagoMinimo }
        if coincideAlguna(texto, [
            "saldo al corte", "saldo del corte", "saldo de corte"
        ]) { return .saldoAlCorte }
        if coincideAlguna(texto, [
            "cuanto pague", "cuanto he pagado", "pagado del corte",
            "pagos del corte", "pague de la tarjeta", "cuanto abone",
            "cuanto cubri", "cuanto llevo pagado", "cuanto llevo cubierto"
        ]) { return .pagadoDelCorte }
        if coincideAlguna(texto, [
            "credito disponible", "credito me queda", "credito queda",
            "disponible de credito", "cuanto credito tengo",
            "cuanto credito le queda", "cuanto le queda de credito"
        ]) { return .creditoDisponible }
        if coincideAlguna(texto, [
            "limite de credito", "limite tiene", "cual es el limite", "cuanto limite",
            "limite mas alto", "mayor limite", "linea de credito"
        ]) { return .limiteCredito }
        if coincideAlguna(texto, [
            "fecha limite", "cuando vence", "vence manana", "vence hoy",
            "cuando tengo que pagar", "que dia tengo que pagar",
            "dia limite", "fecha de pago"
        ]) {
            return .fechaLimite
        }
        if coincideAlguna(texto, [
            "fecha de corte", "cuando corta", "dia de corte", "que dia corta"
        ]) {
            return .fechaCorte
        }
        if coincideAlguna(texto, [
            "falta del corte", "falta cubrir", "falta por cubrir",
            "cuanto falta"
        ]) { return .faltaDelCorte }
        if coincideAlguna(texto, [
            "pagar primero", "pago primero", "prioridad", "vence primero",
            "vence antes", "mas urgente", "cual debo pagar primero",
            "que debo cubrir primero", "pagar antes", "vence mas pronto"
        ]) { return .prioridadDePago }
        if coincideAlguna(texto, [
            "debo mas", "mas debo", "mayor deuda", "deuda mas alta",
            "mas endeudada", "mayor saldo", "saldo mas alto",
            "saldo mas grande", "tengo mas deuda", "tarjeta debo mas",
            "tarjeta mas endeudada"
        ]) { return .mayorDeudaTarjeta }
        if coincideAlguna(texto, [
            "debo menos", "menos debo", "menor deuda", "deuda mas baja"
        ]) { return .menorDeudaTarjeta }
        if coincideAlguna(texto, [
            "cuanto debo en tarjetas", "deuda total de tarjetas",
            "total en tarjetas", "debo de tarjetas", "total de mis tarjetas",
            "suma lo que debo", "suma de mis tarjetas"
        ]) { return .deudaTotalTarjetas }
        if coincideAlguna(texto, [
            "como ves mis finanzas", "situacion financiera", "panorama financiero",
            "como ando de dinero"
        ]) { return .panorama }
        if coincideAlguna(texto, [
            "cierro este mes", "cerrar este mes", "cierre de mes", "fin de mes",
            "proyeccion", "proyecta", "como voy a cerrar el mes",
            "cuanto me quedara", "con cuanto termino el mes", "termino el mes"
        ]) { return .proyeccionFinDeMes }
        if coincideAlguna(texto, [
            "riesgo financiero", "bancarrota", "quiebra", "insolvencia",
            "que riesgo tengo", "hay riesgo"
        ]) { return .riesgo }
        if coincideAlguna(texto, ["prestamo", "mensualidad", "financiamiento"])
            || texto.contains("pedir credito") || texto.contains("sacar credito")
            || texto.contains("pedir un credito")
            || texto.contains("sacar un credito") {
            return .prestamo
        }
        if coincideAlguna(texto, [
            "dinero disponible", "disponible real", "liquidez",
            "cuanto dinero tengo", "cuanto tengo disponible",
            "mi saldo disponible", "con cuanto efectivo cuento"
        ]) { return .disponibleReal }
        if texto.contains("patrimonio") { return .patrimonio }
        if coincideAlguna(texto, [
            "me debe", "me deben", "por cobrar", "quien me debe mas",
            "cuanto me deben"
        ]) { return .porCobrarPersona }
        if coincideAlguna(texto, ["le debo", "debo a", "deuda con"]) {
            return .deudaConAcreedor
        }
        let tieneCuenta = entidades.contains { $0.tipo == .cuenta }
        let tieneTarjeta = entidades.contains { $0.tipo == .tarjeta }
        let tarjetaConNombreCompleto = entidades.contains {
            $0.tipo == .tarjeta && contieneFrase(texto, normalizar($0.nombre))
        }
        let pideSaldoCuenta = coincideAlguna(texto, [
            "saldo", "cuanto tengo en", "cuanto hay en", "suma mis cuentas",
            "total de mis cuentas", "dinero en mis cuentas"
        ])
        let pideIngreso = coincideAlguna(texto, [
            "ingreso", "ingresos", "nomina", "pension", "cuanto recibi",
            "cuanto cobre", "cuanto llego", "me depositaron"
        ])
        if coincideAlguna(texto, [
            "cuanto tengo en mis cuentas", "cuanto hay en mis cuentas",
            "suma mis cuentas", "total de mis cuentas", "dinero en mis cuentas"
        ]) { return .saldoCuenta }
        if tieneTarjeta, tarjetaConNombreCompleto,
           coincideAlguna(texto, ["saldo", "cuanto debo", "deuda"]),
           !coincideAlguna(texto, ["cuenta", "cuenta bancaria"]) {
            return .deudaTarjeta
        }
        if tieneCuenta, pideSaldoCuenta, !coincideAlguna(texto, [
            "cuanto llego", "cuanto recibi", "cuanto cobre", "me depositaron"
        ]) { return .saldoCuenta }
        if pideIngreso { return .ingresos }
        if coincideAlguna(texto, [
            "gasto", "gastos", "gaste", "compre", "compras",
            "puedo gastar", "puedo comprar", "me alcanza para"
        ]) { return .gastos }
        if coincideAlguna(texto, [
            "movimiento", "movimientos", "deposito", "depositos",
            "ultimos cargos", "cargos recientes", "ultimos movimientos",
            "quien me pago"
        ]) {
            return .movimientos
        }
        if tieneCuenta && coincideAlguna(texto, [
            "saldo", "cuanto tengo", "cuanto hay", "suma", "total"
        ]) {
            return .saldoCuenta
        }
        if tieneTarjeta,
           coincideAlguna(texto, ["saldo", "cuanto debo", "deuda"]) {
            return .deudaTarjeta
        }
        if coincideAlguna(texto, [
            "compara mis tarjetas", "comparar mis tarjetas", "ordena mis tarjetas",
            "ordenar mis tarjetas"
        ]) { return .deudaTarjeta }
        let usaDeberComoAuxiliar = usaDeberComoVerboAuxiliar(texto)
        if !usaDeberComoAuxiliar,
           texto.contains("deuda") || (!usaDeberComoAuxiliar && texto.contains("debo")) {
            return .deudaTarjeta
        }
        return .desconocida
    }

    private static func entidadesMencionadas(
        en texto: String,
        resumen: ResumenFinancieroClaro?
    ) -> [ReferenciaEntidadClaro] {
        guard let resumen else { return [] }
        let textoConAlias = contieneFrase(texto, "bancomer")
            ? texto.replacingOccurrences(of: "bancomer", with: "bbva")
            : texto
        var resultado: [ReferenciaEntidadClaro] = []
        let tarjetas = coincidenciasPreferentes(
            resumen.detalleTarjetas.map(\.nombre), en: textoConAlias)
        for tarjeta in resumen.detalleTarjetas where tarjetas.contains(tarjeta.nombre) {
            resultado.append(.init(tipo: .tarjeta, nombre: tarjeta.nombre))
        }
        let descriptoresCuentas = resumen.detalleCuentas.map {
            (nombre: $0.nombre, descriptor: "\($0.nombre) \($0.banco)")
        }
        let cuentas = coincidenciasPreferentes(
            descriptoresCuentas.map(\.descriptor), en: textoConAlias)
        for cuenta in descriptoresCuentas {
            if cuentas.contains(cuenta.descriptor) {
                resultado.append(.init(tipo: .cuenta, nombre: cuenta.nombre))
            }
        }
        let personas = coincidenciasPreferentes(
            resumen.detallePersonas.map(\.nombre), en: texto)
        for persona in resumen.detallePersonas where personas.contains(persona.nombre) {
            resultado.append(.init(tipo: .persona, nombre: persona.nombre))
        }
        let acreedores = coincidenciasPreferentes(
            resumen.detalleDeudas.map(\.acreedor), en: texto)
        for deuda in resumen.detalleDeudas where acreedores.contains(deuda.acreedor) {
            resultado.append(.init(tipo: .acreedor, nombre: deuda.acreedor))
        }
        var vistos: Set<ReferenciaEntidadClaro> = []
        return resultado.filter { vistos.insert($0).inserted }
    }

    private static func entidadesCompatibles(
        _ entidades: [ReferenciaEntidadClaro],
        con metrica: MetricaConsultaClaro,
        texto: String
    ) -> [ReferenciaEntidadClaro] {
        let tipoPreferido: TipoEntidadClaro?
        switch metrica {
        case .saldoAlCorte, .pagoParaNoGenerarIntereses, .pagoMinimo,
             .pagadoDelCorte, .faltaDelCorte, .limiteCredito,
             .creditoDisponible, .fechaCorte, .fechaLimite,
             .deudaTarjeta, .mayorDeudaTarjeta, .menorDeudaTarjeta,
             .prioridadDePago, .deudaTotalTarjetas:
            tipoPreferido = .tarjeta
        case .saldoCuenta:
            tipoPreferido = .cuenta
        case .porCobrarPersona:
            tipoPreferido = .persona
        case .deudaConAcreedor:
            tipoPreferido = .acreedor
        default:
            tipoPreferido = nil
        }
        if let tipoPreferido {
            let filtradas = entidades.filter { $0.tipo == tipoPreferido }
            if !filtradas.isEmpty { return filtradas }
        }

        // Un nombre completo es más confiable que una coincidencia parcial
        // con el nombre del banco. Así "BBVA Azul" no arrastra todas las
        // cuentas BBVA, pero "mis cuentas BBVA" sí conserva esas cuentas.
        let completas = entidades.filter {
            contieneFrase(texto, normalizar($0.nombre))
        }
        if !completas.isEmpty {
            return completas
        }
        return entidades
    }

    private static func coincidenciasPreferentes(
        _ nombres: [String], en texto: String
    ) -> Set<String> {
        let completas = nombres.filter {
            contieneFrase(texto, normalizar($0))
        }
        if !completas.isEmpty { return Set(completas) }
        return Set(nombres.filter { coincideEntidad($0, en: texto) })
    }

    private static func coincideEntidad(_ nombre: String, en texto: String) -> Bool {
        let nombreNormalizado = normalizar(nombre)
        guard !nombreNormalizado.isEmpty else { return false }
        if contieneFrase(texto, nombreNormalizado) { return true }
        let genericas: Set<String> = [
            "banco", "tarjeta", "credito", "cuenta", "nomina", "debito",
            "deuda", "inc", "the"
        ]
        let palabrasNombre = nombreNormalizado.split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 3 && !genericas.contains($0) }
        let palabrasTexto = Set(texto.split(separator: " ").map(String.init))
        return palabrasNombre.contains(where: palabrasTexto.contains)
    }

    private static func contieneReferenciaFinancieraPersonal(
        _ texto: String,
        palabras: [String],
        metrica: MetricaConsultaClaro,
        tieneEntidad: Bool
    ) -> Bool {
        if coincideAlguna(texto, falsosPositivosConocidos) { return false }
        let frasesPersonales = [
            "mis finanzas", "mi situacion financiera", "me alcanza el dinero",
            "como ando de dinero", "estoy en riesgo",
            "mi dinero", "mis saldos", "mi deuda", "mis deudas",
            "cuanto debo", "que debo pagar", "mis pagos", "mis gastos",
            "mis ahorros", "mi ahorro", "mi liquidez", "mi nomina",
            "mi prestamo", "mis prestamos", "mis creditos",
            "cuanto dinero tengo", "dinero disponible", "mi proyeccion",
            "riesgo financiero tengo", "como cierro este mes",
            "tengo mas deuda", "en cual tarjeta tengo",
            "quien me deposito", "me depositaron", "me conviene",
            "crees que sea viable", "crees que haya riesgo",
            "es viable sacar", "puedo sacar", "puedo pedir",
            "cual debo pagar", "cual vence primero", "cuanto me quedara",
            "cual vence mas pronto", "con cuanto efectivo cuento",
            "con cuanto termino el mes", "termino el mes",
            "puedo gastar", "puedo comprar", "me alcanza para",
            "cuanto gaste", "cuanto recibi", "cuanto cobre",
            "cuanto me deben", "quien me debe", "mis cuentas",
            "que pasa si pago", "cuanto llego", "como voy a cerrar el mes",
            "que riesgo tengo", "hay riesgo de bancarrota",
            "es buen momento para un prestamo", "puedo tomar un prestamo",
            "deberia pedir un prestamo", "deberia sacar un prestamo"
        ]
        if coincideAlguna(texto, frasesPersonales) { return true }

        let posesivos = Set(palabras).intersection(["mi", "mis"])
        if !posesivos.isEmpty, metrica != .desconocida { return true }

        let pronombresPersonales = Set(palabras).intersection([
            "me", "yo", "mio", "mia", "mios", "mias"
        ])
        if !pronombresPersonales.isEmpty, metrica != .desconocida { return true }

        // Un nombre que coincide con una tarjeta o persona no autoriza por sí
        // solo abrir datos privados: «qué opinas de Liverpool» y «cómo está
        // Alondra» son conversación general hasta que exista una métrica
        // financiera inequívoca.
        if tieneEntidad, metrica != .desconocida {
            return true
        }
        let verbosEnPrimeraPersona = Set(palabras).intersection([
            "debo", "tengo", "pague", "abono", "cubro", "recibi", "cobre",
            "gaste", "compre", "puedo", "quiero", "necesito"
        ])
        if metrica != .desconocida, !verbosEnPrimeraPersona.isEmpty {
            return true
        }

        switch metrica {
        case .panorama, .disponibleReal, .proyeccionFinDeMes, .riesgo,
             .prestamo, .deudaTotalTarjetas, .mayorDeudaTarjeta,
             .menorDeudaTarjeta, .deudaTarjeta,
             .limiteCredito, .creditoDisponible, .porCobrarPersona,
             .saldoCuenta:
            return !verbosEnPrimeraPersona.isEmpty || texto.contains("mis ")
                || texto.contains("mi ")
                || metrica == .porCobrarPersona
        default:
            return false
        }
    }

    private static func contieneTemaFinanciero(_ texto: String) -> Bool {
        if coincideAlguna(texto, falsosPositivosConocidos) { return false }
        if coincideAlguna(texto, usosNoFinancieros) { return false }
        if coincideAlguna(texto, [
            "metodo avalancha", "metodo bola de nieve"
        ]) { return true }
        let palabras = Set(texto.split(separator: " ").map(String.init))
        return !palabras.isDisjoint(with: vocabularioFinanciero)
    }

    private static func usaDeberComoVerboAuxiliar(_ texto: String) -> Bool {
        let palabras = texto.split(separator: " ").map(String.init)
        let accionesFinancieras: Set<String> = [
            "pagar", "ahorrar", "invertir", "abonar", "cubrir", "liquidar"
        ]
        for indice in palabras.indices where palabras[indice] == "debo" {
            let siguiente = palabras.index(after: indice)
            guard siguiente < palabras.endIndex else { continue }
            let verbo = palabras[siguiente]
            let pareceInfinitivo = verbo.hasSuffix("ar")
                || verbo.hasSuffix("er") || verbo.hasSuffix("ir")
            if pareceInfinitivo, !accionesFinancieras.contains(verbo) {
                return true
            }
        }
        return false
    }

    private static func esSeguimientoDependiente(
        _ texto: String,
        palabras: [String],
        entidades: [ReferenciaEntidadClaro],
        metrica: MetricaConsultaClaro
    ) -> Bool {
        if !entidades.isEmpty, metrica != .desconocida,
           palabras.count <= 7 { return true }
        if !entidades.isEmpty, metrica == .desconocida,
           palabras.count <= 7 {
            let palabrasDeEntidades = Set(entidades.flatMap {
                normalizar($0.nombre).split(separator: " ").map(String.init)
            })
            let conectores: Set<String> = [
                "y", "o", "la", "el", "las", "los", "otra", "otro",
                "tarjeta", "tarjetas", "banco", "inc"
            ]
            if palabras.allSatisfy({
                conectores.contains($0) || palabrasDeEntidades.contains($0)
            }) {
                return true
            }
        }
        let contieneTemaNoFinanciero = !Set(palabras).isDisjoint(with: [
            "gano", "perdio", "partido", "equipo", "ciudad", "tienda",
            "empresa", "persona", "esta", "vive"
        ])
        if palabras.first == "y", !entidades.isEmpty, palabras.count <= 6,
           !contieneTemaNoFinanciero {
            return true
        }
        let abrePreguntaGeneral = [
            "que es ", "que significa ", "quien es ", "donde esta ",
            "hablame de ", "cuentame sobre "
        ].contains(where: texto.hasPrefix)
        if !entidades.isEmpty, metrica != .desconocida,
           palabras.count <= 6, !abrePreguntaGeneral {
            return true
        }
        let referencias: Set<String> = [
            "eso", "esa", "ese", "esas", "esos", "aquella", "aquel",
            "anterior", "misma", "mismo", "otra", "otro"
        ]
        if !Set(palabras).isDisjoint(with: referencias) { return true }
        let seguimientosExactos: Set<String> = [
            "por que", "como", "cuanto", "cuanto seria", "cual", "cuales",
            "me conviene", "conviene", "que recomiendas", "que hago",
            "que opinas", "esta bien", "es mucho", "cuando", "hazlo",
            "si", "no"
        ]
        let seguimientosConReferencia = [
            "y si pago ", "y la otra", "y el otro"
        ]
        return palabras.count <= 6
            && (seguimientosExactos.contains(texto)
                || seguimientosConReferencia.contains(where: texto.hasPrefix))
    }

    private static func esPeticionDeDefinicion(_ texto: String) -> Bool {
        let prefijos = [
            "que es ", "que significa ", "como funciona ", "explicame ",
            "diferencia entre ", "define "
        ]
        return prefijos.contains(where: texto.hasPrefix)
            || texto.contains("quiero saber que es ")
            || texto.contains("quiero saber como funciona ")
    }

    private static func esPreguntaGeneralAutocontenida(_ texto: String) -> Bool {
        [
            "que es ", "que significa ", "quien es ", "donde esta ",
            "donde queda ", "hablame de ", "cuentame sobre ",
            "como funciona ", "cual es la capital"
        ].contains(where: texto.hasPrefix)
    }

    private static func esSaludoOCharlaAutocontenida(_ texto: String) -> Bool {
        let exactas: Set<String> = [
            "hola", "holi", "buenas", "buenos dias", "buenas tardes",
            "buenas noches", "como estas", "que tal", "gracias", "ok",
            "okay", "bien", "bien y tu", "mal", "triste", "quien eres"
        ]
        return exactas.contains(texto)
    }

    private static func esSaludo(_ texto: String) -> Bool {
        coincideAlguna(texto, [
            "hola", "holi", "buenas", "buenos dias", "buenas tardes",
            "buenas noches"
        ])
    }

    private static func esRechazoBreve(_ texto: String) -> Bool {
        ["no", "no gracias", "no quiero", "no lo hagas"].contains(texto)
    }

    private static func esConfirmacionBreve(_ texto: String) -> Bool {
        ["si", "si hazlo", "de acuerdo", "adelante"].contains(texto)
    }

    private static func contenidoDespuesDeMarcador(
        _ texto: String
    ) -> (acto: ActoConversacionalClaro, resto: String)? {
        let marcadores: [(String, ActoConversacionalClaro)] = [
            ("otra cosa ", .cambioDeTema),
            ("cambiando de tema ", .cambioDeTema),
            ("otro tema ", .cambioDeTema),
            ("olvida eso ", .cambioDeTema),
            ("borra eso ", .cambioDeTema),
            ("dejalo ", .cambioDeTema),
            ("eso esta mal ", .correccion),
            ("no fue eso ", .correccion),
            ("no era eso ", .correccion),
            ("no te pregunte eso ", .correccion),
            ("no respondiste ", .correccion),
            ("te equivocaste ", .correccion),
            ("corrige eso ", .correccion)
        ]
        for (prefijo, acto) in marcadores where texto.hasPrefix(prefijo) {
            return (acto, String(texto.dropFirst(prefijo.count)))
        }
        return nil
    }

    private static func contieneFrase(_ texto: String, _ frase: String) -> Bool {
        " \(texto) ".contains(" \(frase) ")
    }

    private static func coincideAlguna(_ texto: String, _ frases: [String]) -> Bool {
        frases.contains { contieneFrase(texto, $0) }
    }

    private static func contieneAlgunaPalabra(
        _ palabras: [String], _ candidatas: Set<String>
    ) -> Bool {
        !Set(palabras).isDisjoint(with: candidatas)
    }

    private static let correcciones = [
        "eso esta mal", "no fue eso", "no era eso", "no te pregunte eso",
        "eso no fue lo que te pregunte", "eso no pregunte", "no respondiste",
        "te equivocaste", "no entendiste", "corrige eso"
    ]

    private static let cancelaciones = [
        "olvida eso", "borra eso", "cancelalo", "dejalo", "cambia de tema",
        "otro tema", "dime otra cosa"
    ]

    private static let emociones = [
        "eso me preocupa", "me preocupa", "eso me pone triste", "me da miedo"
    ]

    private static let marcadoresEducativos = [
        "en general", "normalmente", "metodo avalancha", "metodo bola de nieve",
        "en mexico", "como ejemplo", "hipoteticamente"
    ]

    private static let marcadoresCorporativos = [
        "como empresa", "en bolsa", "sus acciones", "de la empresa",
        "para envio gratis"
    ]

    private static let falsosPositivosConocidos = [
        "cuanto tengo de edad", "cuanto tengo que caminar",
        "cuanto tengo que estudiar", "cierro este mes la novela",
        "patrimonio cultural", "patrimonio historico", "pension favorita",
        "pension en madrid", "credito aparece como autor", "saldo de vacaciones",
        "presupuesto de tiempo", "ingresos a la universidad",
        "ingreso a la universidad", "pagar con una sonrisa", "fin de mes significa",
        "debo pintar", "debo comprar", "cuanto oro tengo",
        "cuantos dias de saldo tengo"
    ]

    private static let usosNoFinancieros = [
        "banco de arena", "banco de peces", "banco de datos",
        "banco de sangre", "banco de tiempo", "banco de pruebas",
        "credito cinematografico", "creditos cinematograficos",
        "creditos de pelicula", "creditos finales", "credito como autor",
        "patrimonio mundial", "patrimonio de la humanidad",
        "patrimonio natural", "patrimonio cultural", "patrimonio historico",
        "saldo de vacaciones", "saldo de dias", "dias de saldo"
    ]

    private static let vocabularioFinanciero: Set<String> = [
        "ahorro", "ahorros", "amortizacion", "banco", "bancaria",
        "bancario", "cargo", "cargos", "cat", "credito", "creditos",
        "cuenta", "deuda", "deudas", "dinero",
        "finanzas", "financiero", "gasto", "gastos", "ingreso", "ingresos",
        "interes", "intereses", "liquidez", "limite", "mensualidad", "nomina",
        "pagar", "pago", "pagos", "patrimonio", "pension", "prestamo",
        "presupuesto", "saldo", "tarjeta", "tarjetas", "tasa", "bancarrota",
        "quiebra", "insolvencia", "minimo", "msi"
    ]
}
