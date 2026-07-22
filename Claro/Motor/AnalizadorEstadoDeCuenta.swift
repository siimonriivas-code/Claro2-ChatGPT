//
//  AnalizadorEstadoDeCuenta.swift
//  Claro — Carpeta: Motor
//
//  El cerebro del importador. Dos caminos, ambos gratis y 100% locales:
//  1. Apple Intelligence (Foundation Models, iOS 26, iPhone 15 Pro o más
//     nuevo): la IA del iPhone convierte el texto del PDF en datos.
//  2. Plan B automático: lector de reglas (patrones de texto) si el
//     equipo no soporta la IA. Menos fino, pero la pantalla de revisión
//     siempre te deja corregir antes de importar.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Lo que el analizador devuelve

struct MovimientoDetectado: Identifiable {
    let id = UUID()
    var fecha: Date
    var comercio: String
    var monto: Double
    var esMSI: Bool
    var msiNumero: Int
    var msiTotal: Int
    var montoOriginal: Double = 0   // "Monto Original" en tablas de compras a meses
}

struct ResumenDetectado {
    var bancoDetectado: String?
    var ultimosDigitosDetectados: String?
    var fechaCorte: Date?
    var fechaLimitePago: Date?
    var pagoParaNoGenerarIntereses: Double?
    var pagoMinimo: Double?
    var saldoAlCorte: Double?
    // Cadena contable reportada por el banco. En Banamex permite comprobar:
    // adeudo anterior + cargos/costos - pagos/abonos = nuevo PNGI.
    var adeudoPeriodoAnterior: Double?
    var cargosYCostosPeriodo: Double?
    var pagosYAbonosPeriodo: Double?
    var movimientos: [MovimientoDetectado] = []
    var usoIA: Bool = false
}

// MARK: - Analizador

enum AnalizadorEstadoDeCuenta {

    static func analizar(paginas: [String]) async -> ResumenDetectado {
        // Interruptor en Configuración: el usuario decide si usar la IA
        let usarIA = UserDefaults.standard.object(forKey: "importarConIA") as? Bool ?? true
        let conReglas = analizarConReglas(paginas: paginas)

        // Estos formatos ya tienen un camino determinista comprobable. En
        // particular, se evita que una respuesta vacía o imprecisa de la IA
        // sustituya la lectura por reglas de Hey Banco o Liverpool.
        if esFormatoDeterminista(paginas) {
            return conReglas
        }

        #if canImport(FoundationModels)
        if usarIA, #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                if let conIA = try? await analizarConIA(paginas: paginas),
                   esResultadoUtil(conIA) {
                    return completar(conIA, con: conReglas)
                }
            }
        }
        #endif
        return conReglas
    }

    private static func esFormatoDeterminista(_ paginas: [String]) -> Bool {
        let texto = normalizarParaBusqueda(paginas.joined(separator: "\n"))
        return texto.contains("HEY BANCO") || texto.contains("HEYBANCO")
            || texto.contains("LIVERPOOL")
            || texto.contains("RAPPICARD")
            || texto.contains("CITIBANAMEX") || texto.contains("BANAMEX")
    }

    private static func esResultadoUtil(_ resultado: ResumenDetectado) -> Bool {
        resultado.fechaCorte != nil
            || resultado.fechaLimitePago != nil
            || resultado.pagoParaNoGenerarIntereses != nil
            || resultado.pagoMinimo != nil
            || resultado.saldoAlCorte != nil
            || !resultado.movimientos.isEmpty
    }

    /// La IA puede acertar en los movimientos y omitir parte del resumen.
    /// Las reglas completan exclusivamente los campos ausentes.
    private static func completar(_ resultadoIA: ResumenDetectado,
                                  con reglas: ResumenDetectado) -> ResumenDetectado {
        var resultado = resultadoIA
        resultado.bancoDetectado = resultado.bancoDetectado ?? reglas.bancoDetectado
        resultado.ultimosDigitosDetectados = resultado.ultimosDigitosDetectados
            ?? reglas.ultimosDigitosDetectados
        resultado.fechaCorte = resultado.fechaCorte ?? reglas.fechaCorte
        resultado.fechaLimitePago = resultado.fechaLimitePago ?? reglas.fechaLimitePago
        resultado.pagoParaNoGenerarIntereses = resultado.pagoParaNoGenerarIntereses
            ?? reglas.pagoParaNoGenerarIntereses
        resultado.pagoMinimo = resultado.pagoMinimo ?? reglas.pagoMinimo
        resultado.saldoAlCorte = resultado.saldoAlCorte ?? reglas.saldoAlCorte
        resultado.adeudoPeriodoAnterior = reglas.adeudoPeriodoAnterior
        resultado.cargosYCostosPeriodo = reglas.cargosYCostosPeriodo
        resultado.pagosYAbonosPeriodo = reglas.pagosYAbonosPeriodo
        if resultado.movimientos.isEmpty {
            resultado.movimientos = reglas.movimientos
        }
        return resultado
    }

    // ─────────────────────────────────────────────
    // CAMINO 1: Apple Intelligence (en el iPhone)
    // ─────────────────────────────────────────────

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    @Generable
    struct ExtraccionPagina {
        @Guide(description: "Fecha de corte en formato yyyy-MM-dd, o cadena vacía si no aparece en esta página")
        var fechaCorte: String

        @Guide(description: "Fecha límite de pago en formato yyyy-MM-dd, o cadena vacía si no aparece")
        var fechaLimitePago: String

        @Guide(description: "Pago para no generar intereses en pesos, 0 si no aparece en esta página")
        var pagoParaNoGenerarIntereses: Double

        @Guide(description: "Pago mínimo en pesos, 0 si no aparece")
        var pagoMinimo: Double

        @Guide(description: "Saldo total al corte o saldo deudor total en pesos, 0 si no aparece")
        var saldoAlCorte: Double

        @Guide(description: "Compras y cargos de la tabla de movimientos de esta página. NO incluir pagos recibidos, abonos, intereses ni comisiones del banco.")
        var movimientos: [MovimientoIA]
    }

    @available(iOS 26.0, *)
    @Generable
    struct MovimientoIA {
        @Guide(description: "Fecha de la compra en formato yyyy-MM-dd")
        var fecha: String

        @Guide(description: "Nombre del comercio tal como aparece, pero SIN el contador inicial si lo tiene (de '14 DE 20 ISHOP' el comercio es solo 'ISHOP...')")
        var comercio: String

        @Guide(description: "Monto del cargo del mes en pesos. En tablas de compras a meses usa la columna 'Pago requerido'; puede ser 0 si la compra está diferida")
        var monto: Double

        @Guide(description: "Columna 'Monto Original' si la fila viene de una tabla de compras a meses; 0 si no aplica")
        var montoOriginal: Double

        @Guide(description: "true si la línea es una mensualidad de compra a meses, CON o SIN intereses (contiene algo como '5 de 13', '05/13', 'MSI', o viene de una tabla de compras diferidas)")
        var esMeses: Bool

        @Guide(description: "Número de la mensualidad actual (el 5 en '5 de 13', el 0 en '0 de 1'). Puede ser 0 si el cobro aún no inicia")
        var numeroMensualidad: Int

        @Guide(description: "Total de mensualidades del plan (el 13 en '5 de 13'), 0 si no aplica")
        var totalMensualidades: Int
    }

    @available(iOS 26.0, *)
    private static func analizarConIA(paginas: [String]) async throws -> ResumenDetectado {
        var resultado = ResumenDetectado()
        resultado.usoIA = true

        let instrucciones = """
        Eres un extractor de datos de estados de cuenta de tarjetas de \
        crédito de bancos mexicanos (BBVA, Banamex y similares). Recibes un \
        fragmento de texto y devuelves datos estructurados. Sé literal con \
        los montos y los nombres de comercios. Los montos usan coma para \
        miles y punto para decimales.

        EXTRAE MOVIMIENTOS ÚNICAMENTE DE ESTAS DOS TABLAS:

        1) La lista de movimientos del periodo (títulos como "CARGOS, \
        COMPRAS Y ABONOS REGULARES" o "DESGLOSE DE MOVIMIENTOS"): cada \
        renglón trae fecha(s), descripción y monto. Usa la fecha de la \
        operación y el monto del renglón. Si la descripción EMPIEZA con un \
        contador como "14 DE 20", es una mensualidad a meses: esMeses=true, \
        numeroMensualidad=14, totalMensualidades=20, y en comercio pon el \
        nombre SIN el contador.

        2) Las tablas de compras a meses ("COMPRAS Y CARGOS DIFERIDOS A \
        MESES SIN INTERESES" y "...CON INTERESES"): una fila por plan. \
        monto = columna "Pago requerido" (puede ser 0.00 si está diferida), \
        montoOriginal = columna "Monto original", y "Núm. de pago" \
        (ej. "6 de 20" o "0 de 1") da numeroMensualidad y totalMensualidades.

        NO EXTRAIGAS montos de ninguna otra parte del documento: resúmenes \
        del periodo, tablas de escenarios ("CUÁNTO PAGARÍAS..."), \
        "DISTRIBUCIÓN DE TU ÚLTIMO PAGO", "NIVEL DE USO", puntos o \
        beneficios, intereses calculados, totales ("TOTAL CARGOS", "TOTAL \
        ABONOS"), saldos, límites de crédito, glosarios ni notas. Esos \
        números NO son movimientos.

        OMITE TAMBIÉN: los pagos y abonos del cliente (montos negativos o \
        descripciones como "PAGO TDC", "SU PAGO", "BMOVIL.PAGO"); las líneas \
        de detalle "USD ... TIPO DE CAMBIO ..." (pertenecen al renglón \
        anterior); y la línea de la compra original a meses SIN contador \
        (ej. "AMAZON A MESES A 03 MESES S/I"), porque ese plan ya viene en \
        la tabla de diferidos.

        Variantes por banco: las fechas pueden venir como "2026-06-09", \
        "22-may-2026" o "03-JUL" sin año (usa el año del corte). Liverpool \
        llama al pago del cliente "GRACIAS POR SU PAGO": omítelo. Algunas \
        tablas de compras a meses (Banorte) traen columnas extra de intereses \
        e IVA entre el saldo y el pago: monto = SIEMPRE la columna "Pago \
        requerido" y montoOriginal = "Monto original".

        Los datos generales (fechaCorte, fechaLimitePago en formato \
        yyyy-MM-dd, pagoParaNoGenerarIntereses, pagoMinimo, y saldoAlCorte = \
        "saldo al corte" o "saldo deudor total") tómalos del resumen del \
        periodo si aparecen en este fragmento.
        """

        for pagina in paginas {
            // La página se rebana en fragmentos completos (cortando en fin
            // de línea) para que la IA lea TODO, sin importar lo densa que
            // sea la página. Antes se recortaba y se perdían movimientos.
            for fragmento in fragmentos(de: pagina, maximoCaracteres: 4500) {
            let sesion = LanguageModelSession(instructions: instrucciones)
            let texto = fragmento

            let respuesta = try await sesion.respond(
                to: "Extrae los datos de este fragmento del estado de cuenta:\n\n\(texto)",
                generating: ExtraccionPagina.self)

            let extraccion = respuesta.content

            // El resumen (fechas y montos) se toma de la primera página que lo traiga
            if resultado.fechaCorte == nil,
               let f = fecha(desde: extraccion.fechaCorte) { resultado.fechaCorte = f }
            if resultado.fechaLimitePago == nil,
               let f = fecha(desde: extraccion.fechaLimitePago) { resultado.fechaLimitePago = f }
            if resultado.pagoParaNoGenerarIntereses == nil,
               extraccion.pagoParaNoGenerarIntereses > 0 {
                resultado.pagoParaNoGenerarIntereses = extraccion.pagoParaNoGenerarIntereses
            }
            if resultado.pagoMinimo == nil, extraccion.pagoMinimo > 0 {
                resultado.pagoMinimo = extraccion.pagoMinimo
            }
            if resultado.saldoAlCorte == nil, extraccion.saldoAlCorte > 0 {
                resultado.saldoAlCorte = extraccion.saldoAlCorte
            }

            for mov in extraccion.movimientos
                where mov.monto > 0 || (mov.esMeses && mov.montoOriginal > 0) {
                resultado.movimientos.append(MovimientoDetectado(
                    fecha: fecha(desde: mov.fecha) ?? resultado.fechaCorte ?? .now,
                    comercio: mov.comercio.trimmingCharacters(in: .whitespacesAndNewlines),
                    monto: max(0, mov.monto),
                    esMSI: mov.esMeses && mov.totalMensualidades >= 1,
                    msiNumero: max(0, mov.numeroMensualidad),
                    msiTotal: max(0, mov.totalMensualidades),
                    montoOriginal: max(0, mov.montoOriginal)))
            }
            } // fin del bucle de fragmentos
        }
        return resultado
    }
    #endif

    // ─────────────────────────────────────────────
    // CAMINO 2 (plan B): lector de reglas
    // ─────────────────────────────────────────────

    private static func analizarConReglas(paginas: [String]) -> ResumenDetectado {
        var resultado = ResumenDetectado()
        let textoCompleto = paginas.joined(separator: "\n")
        let textoNormalizado = normalizarParaBusqueda(textoCompleto)
        let esHeyBanco = textoNormalizado.contains("HEY BANCO")
            || textoNormalizado.contains("HEYBANCO")
        let esRappiCard = textoNormalizado.contains("RAPPICARD")
        let esBanamex = textoNormalizado.contains("CITIBANAMEX")
            || textoNormalizado.contains("BANAMEX")

        // En Hey Banco la capa digital conserva con precisión el cuadro de
        // pago, pero sus tablas necesitan OCR. El extractor entrega ambas
        // fuentes y marca la digital para que aquí se use solo como resumen.
        let resumenDigital = paginas.first {
            $0.hasPrefix(ExtractorPDF.prefijoResumenDigital)
        }
        let textoDeResumen = esHeyBanco ? (resumenDigital ?? textoCompleto) : textoCompleto
        let textoDeMovimientos = paginas
            .filter { !$0.hasPrefix(ExtractorPDF.prefijoResumenDigital) }
            .joined(separator: "\n")

        resultado.bancoDetectado = detectarBanco(en: textoCompleto)
        resultado.ultimosDigitosDetectados = detectarUltimosDigitos(en: textoCompleto)

        // ── Datos generales del corte ──
        // PDFKit entrega el encabezado de Hey por columnas: después de
        // "Fecha de corte" aparece primero el inicio del periodo, y la fecha
        // límite queda varios renglones más abajo. Se leen los dos campos con
        // la estructura real del documento, no por mera cercanía.
        if esHeyBanco {
            resultado.fechaCorte = fechaFinalDelPeriodoHey(en: textoDeResumen)
                ?? fechaCercaDe(["FECHA DE CORTE"], en: textoDeResumen)
            resultado.fechaLimitePago = fechaDespuesDeClave(
                ["FECHA LÍMITE DE PAGO", "FECHA LIMITE DE PAGO"],
                en: textoDeResumen, maximoCaracteres: 1_200)
        } else {
            resultado.fechaCorte = fechaCercaDe(["FECHA DE CORTE"], en: textoDeResumen)
            resultado.fechaLimitePago = fechaCercaDe(
                ["FECHA LIMITE", "FECHA LÍMITE", "LIMITE DE PAGO", "LÍMITE DE PAGO", "PAGAR ANTES"],
                en: textoDeResumen)
        }
        resultado.pagoParaNoGenerarIntereses = montoCercaDe(
            ["NO GENERAR INTERESES"], excluyendo: [], en: textoDeResumen)
        resultado.pagoMinimo = montoCercaDe(
            ["PAGO MINIMO", "PAGO MÍNIMO"],
            excluyendo: ["COMPRAS", "DIFERIDOS", "MESES"],
            en: textoDeResumen)
        if esHeyBanco || esRappiCard {
            // En RappiCard, "Saldo cargos a meses" está justo encima de
            // "Saldo deudor total". La búsqueda por cercanía podía tomar el
            // primero; se exige que el importe aparezca después de la etiqueta.
            resultado.saldoAlCorte = montoDespuesDeClave(
                ["SALDO DEUDOR TOTAL"], en: textoDeResumen,
                maximoCaracteres: 180)
        } else {
            resultado.saldoAlCorte = montoCercaDe(
                ["SALDO DEUDOR TOTAL", "SALDO ACTUAL AL CORTE", "SALDO AL CORTE",
                 "SALDO ACTUAL", "SALDO TOTAL"],
                excluyendo: [], en: textoDeResumen)
        }

        if esBanamex {
            resultado.adeudoPeriodoAnterior = montoCercaIncluyendoCero(
                ["ADEUDO DEL PERIODO ANTERIOR"], en: textoDeResumen)
            let componentes: [Double?] = [
                montoCercaIncluyendoCero(
                    ["CARGOS REGULARES (NO A MESES)"], en: textoDeResumen),
                montoCercaIncluyendoCero(
                    ["CARGOS COMPRAS A MESES (CAPITAL)"], en: textoDeResumen),
                montoCercaIncluyendoCero(
                    ["MONTO DE INTERESES"], en: textoDeResumen),
                montoCercaIncluyendoCero(
                    ["MONTO DE COMISIONES"], en: textoDeResumen),
                montoCercaIncluyendoCero(
                    ["IVA DE INTERESES Y COMISIONES"], en: textoDeResumen)
            ]
            if componentes.allSatisfy({ $0 != nil }) {
                resultado.cargosYCostosPeriodo = componentes
                    .compactMap { $0 }.reduce(0, +).redondeadoAMoneda
            }
            resultado.pagosYAbonosPeriodo = montoCercaIncluyendoCero(
                ["PAGOS Y ABONOS"], en: textoDeResumen)
        }

        // Para fechas sin año (Liverpool escribe "03-JUL"), usamos el del corte
        let anioCorte = Calendar.current.component(.year,
                                                   from: resultado.fechaCorte ?? .now)

        // Hey sí contiene una capa digital precisa. Su tabla se reparte en
        // varios renglones (el importe puede quedar debajo de la descripción),
        // por lo que el lector genérico línea-a-línea perdía Telcel y CFE.
        // Si la sección digital está disponible, se reconstruye explícitamente.
        if esHeyBanco, let resumenDigital {
            let movimientosHey = analizarMovimientosHey(
                resumenDigital, fechaCorte: resultado.fechaCorte)
            if !movimientosHey.isEmpty {
                resultado.movimientos = movimientosHey
                return resultado
            }
        }

        for lineaCruda in textoDeMovimientos.components(separatedBy: .newlines) {
            let linea = lineaCruda.trimmingCharacters(in: .whitespaces)
            guard linea.count > 10 else { continue }

            // 1) Toda fila de movimiento empieza con una fecha (en cualquiera
            //    de los formatos de los bancos mexicanos)
            guard let (fechaDetectada, restoTrasFecha) = fechaInicial(
                de: linea, anioPorDefecto: anioCorte)
            else { continue }

            var fecha = fechaDetectada
            if let corte = resultado.fechaCorte {
                guard let fechaValidada = fechaDeMovimiento(fecha,
                                                             dentroDelCorte: corte)
                else { continue }
                fecha = fechaValidada
            }

            // Segunda fecha opcional (BBVA y Banorte traen operación + cargo)
            var cuerpo = restoTrasFecha
            if let (_, resto2) = fechaInicial(de: cuerpo, anioPorDefecto: anioCorte) {
                cuerpo = resto2
            }

            // 2) ¿Fila de tabla de compras a meses? (termina en "N de M  x%")
            if let dif = analizarFilaDiferido(cuerpo) {
                resultado.movimientos.append(MovimientoDetectado(
                    fecha: fecha,
                    comercio: limpiarComercio(dif.comercio),
                    monto: dif.pagoRequerido,
                    esMSI: true,
                    msiNumero: dif.numero,
                    msiTotal: dif.total,
                    montoOriginal: dif.montoOriginal))
                continue
            }

            // 3) ¿Fila regular? (termina con un monto, con signo opcional)
            guard let reg = analizarFilaRegular(cuerpo) else { continue }
            guard !reg.esNegativo else { continue }   // pagos/abonos del cliente

            var descripcion = quitarSegmentoDePresupuesto(reg.descripcion)
            guard !descripcion.isEmpty else { continue }
            let mayus = descripcion.uppercased()
            let esPago = ["PAGO TDC", "SU PAGO", "BMOVIL.PAGO",
                          "PAGO POR SPEI", "PAGO RECIBIDO", "GRACIAS POR SU PAGO",
                          "ABONO RECIBIDO", "TIPO DE CAMBIO"]
                .contains { mayus.contains($0) }
            let esCargoBancario = ["INTERESES", "IVA DE INTER", "IVA INTERES",
                                   "INTERES COMPRA EN CUOTAS",
                                   "COMISION", "COMISIÓN"]
                .contains { mayus.contains($0) }
            let esDesgloseHey = esHeyBanco && esDesgloseDePlanHey(mayus)
            guard !esPago && !esCargoBancario && !esDesgloseHey else { continue }

            // ¿Trae contador "14 DE 20" al inicio? → es mensualidad
            var esMSI = false
            var numero = 0
            var total = 0
            let (comercioLimpio, contadorNum, contadorTotal) = separarContador(descripcion)
            if let n = contadorNum, let t = contadorTotal, t >= 1, n <= t {
                esMSI = true; numero = n; total = t
                descripcion = comercioLimpio
            }

            resultado.movimientos.append(MovimientoDetectado(
                fecha: fecha,
                comercio: limpiarComercio(descripcion),
                monto: reg.monto,
                esMSI: esMSI,
                msiNumero: numero,
                msiTotal: total,
                montoOriginal: 0))
        }
        return resultado
    }

    /// Reconstruye la tabla digital de Hey Banco. El documento coloca los
    /// importes en renglones separados aunque visualmente pertenezcan a la
    /// misma fila. Se conservan cargos reales y la fila maestra del plan;
    /// pagos, intereses, IVA y el desglose de capital quedan fuera.
    private static func analizarMovimientosHey(
        _ texto: String, fechaCorte: Date?) -> [MovimientoDetectado] {
        guard let rangoInicio = texto.range(
            of: "DESGLOSE DE MOVIMIENTOS",
            options: [.caseInsensitive, .diacriticInsensitive]) else { return [] }

        let despuesDelTitulo = String(texto[rangoInicio.upperBound...])
        let seccion: String
        if let rangoFin = despuesDelTitulo.range(
            of: "UNIDAD ESPECIALIZADA DE ATENCIÓN A USUARIOS",
            options: [.caseInsensitive, .diacriticInsensitive]) {
            seccion = String(despuesDelTitulo[..<rangoFin.lowerBound])
        } else {
            seccion = despuesDelTitulo
        }

        var movimientos: [MovimientoDetectado] = []

        // Una fila de plan contiene: fecha, descripción, monto original,
        // saldo pendiente, interés, IVA, pago requerido y número de pago.
        let patronDiferido = #"(\d{1,2}[-/][A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{3,4}[-/]\d{4})\s+(.{3,260}?)\s+\$\s*([\d,]+\.\d{2})\s+\$\s*([\d,]+\.\d{2})\s+\$\s*([\d,]+\.\d{2})\s+\$\s*([\d,]+\.\d{2})\s+\$\s*([\d,]+\.\d{2})\s+(\d{1,2})\s+[Dd][Ee]\s+(\d{1,2})"#
        if let regex = try? NSRegularExpression(
            pattern: patronDiferido,
            options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let rango = NSRange(seccion.startIndex..., in: seccion)
            for coincidencia in regex.matches(in: seccion, range: rango) {
                func grupo(_ numero: Int) -> String {
                    guard let r = Range(coincidencia.range(at: numero), in: seccion)
                    else { return "" }
                    return String(seccion[r])
                }

                guard let fecha = extraerFecha(de: grupo(1)),
                      let numero = Int(grupo(8)),
                      let total = Int(grupo(9)),
                      total >= 1, numero <= total,
                      let montoOriginal = numeroMonetario(grupo(3)),
                      let pagoRequerido = numeroMonetario(grupo(7)),
                      pagoRequerido > 0 else { continue }
                if let fechaCorte,
                   fechaDeMovimiento(fecha, dentroDelCorte: fechaCorte) == nil {
                    continue
                }

                movimientos.append(MovimientoDetectado(
                    fecha: fecha,
                    comercio: limpiarComercioHey(grupo(2)),
                    monto: pagoRequerido,
                    esMSI: true,
                    msiNumero: numero,
                    msiTotal: total,
                    montoOriginal: montoOriginal))
            }
        }

        // Filas regulares: PDFKit deja el signo al final del renglón y el
        // importe en el siguiente. El patrón acepta ambas presentaciones.
        let patronRegular = #"^(\d{1,2}[-/][A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{3,4}[-/]\d{4})\s+(\d{1,2}[-/][A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{3,4}[-/]\d{4})\s+(.{3,260}?)\s+([+\-])\s*(?:\r?\n\s*)?\$\s*([\d,]+\.\d{2})"#
        if let regex = try? NSRegularExpression(
            pattern: patronRegular,
            options: [.caseInsensitive, .anchorsMatchLines]) {
            let rango = NSRange(seccion.startIndex..., in: seccion)
            for coincidencia in regex.matches(in: seccion, range: rango) {
                func grupo(_ numero: Int) -> String {
                    guard let r = Range(coincidencia.range(at: numero), in: seccion)
                    else { return "" }
                    return String(seccion[r])
                }

                guard grupo(4) == "+",
                      let fechaCruda = extraerFecha(de: grupo(1)),
                      let monto = numeroMonetario(grupo(5)), monto > 0 else { continue }
                let fecha: Date
                if let fechaCorte {
                    guard let validada = fechaDeMovimiento(
                        fechaCruda, dentroDelCorte: fechaCorte) else { continue }
                    fecha = validada
                } else {
                    fecha = fechaCruda
                }

                var descripcion = limpiarComercioHey(grupo(3))
                let mayus = normalizarParaBusqueda(descripcion)
                let esPago = ["PAGO TDC", "SU PAGO", "PAGO POR SPEI",
                              "PAGO RECIBIDO", "GRACIAS POR SU PAGO"]
                    .contains { mayus.contains($0) }
                let esCargoBancario = ["INTERESES", "INT. DE PD", "IVA INT.",
                                       "COMISION", "COMISIÓN"]
                    .contains { mayus.contains($0) }
                guard !esPago, !esCargoBancario,
                      !esDesgloseDePlanHey(mayus) else { continue }

                var esMSI = false
                var numero = 0
                var total = 0
                let separado = separarContador(descripcion)
                if let n = separado.1, let t = separado.2, t >= 1, n <= t {
                    descripcion = separado.0
                    esMSI = true
                    numero = n
                    total = t
                }

                movimientos.append(MovimientoDetectado(
                    fecha: fecha,
                    comercio: descripcion,
                    monto: monto,
                    esMSI: esMSI,
                    msiNumero: numero,
                    msiTotal: total,
                    montoOriginal: 0))
            }
        }

        return movimientos.sorted { $0.fecha < $1.fecha }
    }

    // MARK: - Piezas del lector multi-banco

    /// Detecta una fecha AL INICIO del texto en los formatos usados por los
    /// bancos mexicanos: "2026-06-09" (Banorte), "22-may-2026" (BBVA),
    /// "22/05/2026", o "03-JUL" sin año (Liverpool → usa el año del corte).
    /// Devuelve la fecha y el resto de la línea.
    private static func fechaInicial(de texto: String,
                                     anioPorDefecto: Int) -> (Date, String)? {
        let patrones = [
            "^(\\d{4})-(\\d{1,2})-(\\d{1,2})",
            "^(\\d{1,2})[-/ ]([A-Za-zÁÉáé]{3,4})[-/ ](\\d{4})",
            "^(\\d{1,2})[-/](\\d{1,2})[-/](\\d{2,4})",
            "^(\\d{1,2})[-/ ]([A-Za-zÁÉáé]{3,4})(?![A-Za-zÁÉáé-])"
        ]
        for (indice, patron) in patrones.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: patron),
                  let m = regex.firstMatch(in: texto,
                                           range: NSRange(texto.startIndex..., in: texto)),
                  let rangoTotal = Range(m.range, in: texto) else { continue }

            func grupo(_ n: Int) -> String {
                guard m.range(at: n).location != NSNotFound,
                      let r = Range(m.range(at: n), in: texto) else { return "" }
                return String(texto[r])
            }

            var comps = DateComponents()
            switch indice {
            case 0:
                comps.year = Int(grupo(1)); comps.month = Int(grupo(2))
                comps.day = Int(grupo(3))
            case 1:
                comps.day = Int(grupo(1)); comps.month = numeroDeMes(grupo(2))
                comps.year = Int(grupo(3))
            case 2:
                comps.day = Int(grupo(1)); comps.month = Int(grupo(2))
                var anio = Int(grupo(3)) ?? anioPorDefecto
                if anio < 100 { anio += 2000 }
                comps.year = anio
            default:
                comps.day = Int(grupo(1)); comps.month = numeroDeMes(grupo(2))
                comps.year = anioPorDefecto
            }

            guard let mes = comps.month, (1...12).contains(mes),
                  let dia = comps.day, (1...31).contains(dia),
                  let fecha = Calendar.current.date(from: comps) else { continue }

            let resto = String(texto[rangoTotal.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            return (fecha, resto)
        }
        return nil
    }

    private static func numeroDeMes(_ texto: String) -> Int? {
        let meses = ["ENE": 1, "FEB": 2, "MAR": 3, "ABR": 4, "MAY": 5, "JUN": 6,
                     "JUL": 7, "AGO": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DIC": 12]
        return meses[String(texto.uppercased().prefix(3))]
    }

    /// Fila de tabla de compras a meses: "DESC  $a  $b [...]  N de M  x%".
    /// Los bancos varían el número de columnas (Banorte mete intereses e IVA):
    /// el PRIMER monto es el Monto Original y el ÚLTIMO el Pago Requerido.
    private static func analizarFilaDiferido(_ cuerpo: String)
        -> (comercio: String, montoOriginal: Double, pagoRequerido: Double,
            numero: Int, total: Int)? {
        guard let regex = try? NSRegularExpression(pattern:
            "^(.+?)\\s+((?:[+\\-]?\\s*\\$?\\s*[\\d,]+\\.\\d{2}\\s+){2,7})" +
            "(\\d{1,2})\\s+[Dd][Ee]\\s+(\\d{1,2})\\s+[\\d.,]+\\s*%$"),
              let m = regex.firstMatch(in: cuerpo,
                                       range: NSRange(cuerpo.startIndex..., in: cuerpo))
        else { return nil }

        func grupo(_ n: Int) -> String {
            guard let r = Range(m.range(at: n), in: cuerpo) else { return "" }
            return String(cuerpo[r])
        }

        let montos = extraerMontos(de: grupo(2))
        guard montos.count >= 2,
              let numero = Int(grupo(3)), let total = Int(grupo(4)),
              total >= 1, numero <= total else { return nil }

        return (grupo(1), montos.first ?? 0, montos.last ?? 0, numero, total)
    }

    /// Fila regular: "DESCRIPCIÓN  [+|-] $monto" al final de la línea.
    private static func analizarFilaRegular(_ cuerpo: String)
        -> (descripcion: String, esNegativo: Bool, monto: Double)? {
        guard let regex = try? NSRegularExpression(pattern:
            "^(.{3,180}?)\\s*([+\\-])?\\s*\\$?\\s*([\\d,]+\\.\\d{2})\\s*([+\\-])?\\s*$"),
              let m = regex.firstMatch(in: cuerpo,
                                       range: NSRange(cuerpo.startIndex..., in: cuerpo))
        else { return nil }

        func grupo(_ n: Int) -> String {
            guard m.range(at: n).location != NSNotFound,
                  let r = Range(m.range(at: n), in: cuerpo) else { return "" }
            return String(cuerpo[r])
        }

        let monto = Double(grupo(3).replacingOccurrences(of: ",", with: "")) ?? 0
        guard monto > 0 else { return nil }
        return (grupo(1).trimmingCharacters(in: .whitespaces),
                grupo(2) == "-" || grupo(4) == "-", monto)
    }

    private static func extraerMontos(de texto: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: "[\\d,]+\\.\\d{2}")
        else { return [] }
        let rango = NSRange(texto.startIndex..., in: texto)
        return regex.matches(in: texto, range: rango).compactMap { m in
            guard let r = Range(m.range, in: texto) else { return nil }
            return Double(texto[r].replacingOccurrences(of: ",", with: ""))
        }
    }

    /// Separa un contador inicial tipo "14 DE 20 COMERCIO" → (COMERCIO, 14, 20)
    private static func separarContador(_ texto: String) -> (String, Int?, Int?) {
        if let regex = try? NSRegularExpression(pattern:
            "^(\\d{1,2})\\s+[Dd][Ee]\\s+(\\d{1,2})\\s+(.+)$"),
           let m = regex.firstMatch(in: texto,
                                    range: NSRange(texto.startIndex..., in: texto)),
           let r1 = Range(m.range(at: 1), in: texto),
           let r2 = Range(m.range(at: 2), in: texto),
           let r3 = Range(m.range(at: 3), in: texto) {
            return (String(texto[r3]), Int(texto[r1]), Int(texto[r2]))
        }

        // Hey y algunos comercios colocan el contador dentro del texto:
        // "PD (7/12) COMERCIO". Se elimina solo el contador.
        if let regex = try? NSRegularExpression(pattern:
            "^(.*?)\\(\\s*(\\d{1,2})\\s*/\\s*(\\d{1,2})\\s*\\)\\s*(.*)$"),
           let m = regex.firstMatch(in: texto,
                                    range: NSRange(texto.startIndex..., in: texto)),
           let prefijo = Range(m.range(at: 1), in: texto),
           let r1 = Range(m.range(at: 2), in: texto),
           let r2 = Range(m.range(at: 3), in: texto),
           let sufijo = Range(m.range(at: 4), in: texto) {
            let comercio = (String(texto[prefijo]) + " " + String(texto[sufijo]))
                .trimmingCharacters(in: .whitespaces)
            return (comercio, Int(texto[r1]), Int(texto[r2]))
        }

        return (texto, nil, nil)
    }

    /// Hey repite la mensualidad en la tabla principal y después la desglosa
    /// en capital, intereses e IVA. La tabla ya trae el pago requerido total;
    /// importar también estas líneas duplicaría el mismo plan.
    private static func esDesgloseDePlanHey(_ descripcionNormalizada: String) -> Bool {
        guard descripcionNormalizada.range(
            of: #"\(\s*\d{1,2}\s*/\s*\d{1,2}\s*\)"#,
            options: .regularExpression) != nil else { return false }

        return descripcionNormalizada.range(
            of: #"(?:^|\s)(?:PD|INT\.?\s+(?:DE\s+)?PD|IVA\s+INT\.?(?:\s+DE)?\s+PD)\s*\("#,
            options: .regularExpression) != nil
    }

    /// Limpia sufijos y prefijos repetitivos del comercio:
    /// "; Tarjeta Digital ***1234" al final, y el segmento numérico que
    /// Liverpool antepone ("001 PIF SUPERIOR...").
    private static func limpiarComercio(_ texto: String) -> String {
        var limpio = texto
        if let rango = limpio.range(of: ";") {
            limpio = String(limpio[..<rango.lowerBound])
        }
        limpio = limpio.trimmingCharacters(in: .whitespaces)
        if let regex = try? NSRegularExpression(pattern: "^\\d{2,4}\\s+"),
           let m = regex.firstMatch(in: limpio,
                                    range: NSRange(limpio.startIndex..., in: limpio)),
           let r = Range(m.range, in: limpio) {
            limpio.removeSubrange(r)
        }
        // Liverpool añade a veces una referencia numérica larga al final
        // del nombre del comercio; sirve al banco, no al usuario.
        if let regex = try? NSRegularExpression(pattern: "\\s+\\d{6,}\\s*$"),
           let m = regex.firstMatch(in: limpio,
                                    range: NSRange(limpio.startIndex..., in: limpio)),
           let r = Range(m.range, in: limpio) {
            limpio.removeSubrange(r)
        }
        return limpio.trimmingCharacters(in: .whitespaces)
    }

    /// En Liverpool la tabla informativa de proyección puede quedar pegada
    /// al movimiento anterior durante el OCR. Se conserva el comercio que
    /// está antes de "PRESUPUESTO"; si la fila empieza ahí, queda vacía y se
    /// descarta porque no es una compra.
    private static func quitarSegmentoDePresupuesto(_ texto: String) -> String {
        guard let rango = texto.range(of: "PRESUP",
                                      options: [.caseInsensitive, .diacriticInsensitive])
        else { return texto.trimmingCharacters(in: .whitespaces) }
        return String(texto[..<rango.lowerBound])
            .trimmingCharacters(in: .whitespaces)
    }

    /// Ningún movimiento real del estado puede ocurrir después del corte.
    /// En cortes de enero, una fecha "DIC" sin año pertenece al año anterior.
    private static func fechaDeMovimiento(_ fecha: Date,
                                          dentroDelCorte corte: Date) -> Date? {
        let calendario = Calendar.current
        let diaFecha = calendario.startOfDay(for: fecha)
        let diaCorte = calendario.startOfDay(for: corte)
        guard diaFecha > diaCorte else { return fecha }

        guard let unAnioAntes = calendario.date(byAdding: .year,
                                                 value: -1,
                                                 to: fecha) else { return nil }
        let diasHastaCorte = calendario.dateComponents(
            [.day], from: calendario.startOfDay(for: unAnioAntes),
            to: diaCorte).day ?? Int.max
        return (0...62).contains(diasHastaCorte) ? unAnioAntes : nil
    }

    // MARK: - Rebanador de texto

    /// Divide un texto largo en fragmentos de tamaño manejable para la IA
    /// del iPhone, cortando SIEMPRE en fin de línea para no partir
    /// ninguna transacción a la mitad.
    private static func fragmentos(de texto: String,
                                   maximoCaracteres: Int) -> [String] {
        guard texto.count > maximoCaracteres else { return [texto] }

        var resultado: [String] = []
        var actual = ""
        for linea in texto.components(separatedBy: .newlines) {
            if !actual.isEmpty && actual.count + linea.count + 1 > maximoCaracteres {
                resultado.append(actual)
                actual = ""
            }
            actual += (actual.isEmpty ? "" : "\n") + linea
        }
        if !actual.isEmpty { resultado.append(actual) }
        return resultado
    }

    // MARK: - Ayudantes de fechas y montos

    private static func fecha(desde texto: String) -> Date? {
        let limpio = texto.trimmingCharacters(in: .whitespaces)
        guard !limpio.isEmpty else { return nil }
        let formato = DateFormatter()
        formato.locale = Locale(identifier: "es_MX")
        for patron in ["yyyy-MM-dd", "dd/MM/yyyy", "dd-MM-yyyy", "dd-MMM-yyyy", "dd/MMM/yyyy"] {
            formato.dateFormat = patron
            if let f = formato.date(from: limpio) { return f }
        }
        return nil
    }

    private static func fechaDeLinea(dia: String, mes: String, anio: String) -> Date? {
        let meses = ["ENE": 1, "FEB": 2, "MAR": 3, "ABR": 4, "MAY": 5, "JUN": 6,
                     "JUL": 7, "AGO": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DIC": 12]
        guard let d = Int(dia) else { return nil }
        let m: Int
        if let numerico = Int(mes) { m = numerico }
        else if let porNombre = meses[String(mes.uppercased().prefix(3))] { m = porNombre }
        else { return nil }

        var componentes = DateComponents()
        componentes.day = d
        componentes.month = m
        componentes.year = Int(anio) ?? Calendar.current.component(.year, from: .now)
        if let a = componentes.year, a < 100 { componentes.year = 2000 + a }
        return Calendar.current.date(from: componentes)
    }

    /// Hey imprime el periodo como "14-jun-2026 al 13-jul-2026". El último
    /// día de ese intervalo es exactamente la fecha de corte.
    private static func fechaFinalDelPeriodoHey(en texto: String) -> Date? {
        let patron = #"(\d{1,2})[-/ ]([A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{3,4}|\d{1,2})[-/ ](\d{2,4})\s+(?:AL|A)\s+(\d{1,2})[-/ ]([A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{3,4}|\d{1,2})[-/ ](\d{2,4})"#
        guard let regex = try? NSRegularExpression(
            pattern: patron, options: [.caseInsensitive]),
              let coincidencia = regex.firstMatch(
                in: texto, range: NSRange(texto.startIndex..., in: texto))
        else { return nil }

        func grupo(_ numero: Int) -> String {
            guard let rango = Range(coincidencia.range(at: numero), in: texto)
            else { return "" }
            return String(texto[rango])
        }
        return fechaDeLinea(dia: grupo(4), mes: grupo(5), anio: grupo(6))
    }

    /// Busca una fecha solo después de una etiqueta concreta. Esto evita que
    /// una cantidad o fecha situada antes de la etiqueta se asocie al campo.
    private static func fechaDespuesDeClave(
        _ claves: [String], en texto: String,
        maximoCaracteres: Int) -> Date? {
        for clave in claves {
            guard let segmento = segmentoDespuesDeClave(
                clave, en: texto, maximoCaracteres: maximoCaracteres) else { continue }
            if let fecha = extraerFecha(de: segmento) { return fecha }
        }
        return nil
    }

    private static func montoDespuesDeClave(
        _ claves: [String], en texto: String,
        maximoCaracteres: Int) -> Double? {
        for clave in claves {
            guard let segmento = segmentoDespuesDeClave(
                clave, en: texto, maximoCaracteres: maximoCaracteres) else { continue }
            if let monto = primerMonto(en: segmento), monto > 0 { return monto }
        }
        return nil
    }

    private static func segmentoDespuesDeClave(
        _ clave: String, en texto: String,
        maximoCaracteres: Int) -> String? {
        guard let rango = texto.range(
            of: clave, options: [.caseInsensitive, .diacriticInsensitive]) else { return nil }
        let disponibles = texto.distance(from: rango.upperBound, to: texto.endIndex)
        let fin = texto.index(rango.upperBound,
                              offsetBy: min(maximoCaracteres, disponibles))
        return String(texto[rango.upperBound..<fin])
    }

    private static func fechaCercaDe(_ claves: [String], en texto: String) -> Date? {
        let lineas = texto.components(separatedBy: .newlines)
        let clavesNormalizadas = claves.map { normalizarParaBusqueda($0) }
        for indice in lineas.indices {
            let lineaNormalizada = normalizarParaBusqueda(lineas[indice])
            guard clavesNormalizadas.contains(where: { lineaNormalizada.contains($0) })
            else { continue }

            // OCR conserva etiqueta y valor en la misma fila. PDFKit a
            // veces manda el valor a alguno de los renglones siguientes.
            let limite = min(lineas.count - 1, indice + 4)
            for candidato in indice...limite {
                if candidato > indice,
                   esEtiquetaDeResumen(normalizarParaBusqueda(lineas[candidato])) {
                    break
                }
                if let fecha = extraerFecha(de: lineas[candidato]) { return fecha }
            }
        }
        return nil
    }

    private static func montoCercaDe(_ claves: [String],
                                     excluyendo: [String],
                                     en texto: String) -> Double? {
        let lineas = texto.components(separatedBy: .newlines)
        let clavesNormalizadas = claves.map { normalizarParaBusqueda($0) }
        let exclusionesNormalizadas = excluyendo.map { normalizarParaBusqueda($0) }
        for indice in lineas.indices {
            let lineaNormalizada = normalizarParaBusqueda(lineas[indice])
            // La clave debe pertenecer a este renglón. Usar también el
            // siguiente hacía que "Pago para no generar intereses" tomara
            // el lugar de "Pago mínimo", o que el pago mínimo se leyera
            // como saldo cuando las etiquetas venían una debajo de otra.
            guard clavesNormalizadas.contains(where: { lineaNormalizada.contains($0) })
            else { continue }
            if exclusionesNormalizadas.contains(where: { lineaNormalizada.contains($0) }) {
                continue
            }

            let limite = min(lineas.count - 1, indice + 3)
            for candidato in indice...limite {
                if candidato > indice,
                   esEtiquetaDeResumen(normalizarParaBusqueda(lineas[candidato])) {
                    break
                }
                if let monto = primerMonto(en: lineas[candidato]), monto > 0 {
                    return monto
                }
            }
        }
        return nil
    }

    /// Variante contable: $0.00 es un dato válido, no ausencia. Se usa en
    /// tablas cuya ecuación debe cerrar incluyendo componentes en cero.
    private static func montoCercaIncluyendoCero(
        _ claves: [String], en texto: String) -> Double? {
        let lineas = texto.components(separatedBy: .newlines)
        let clavesNormalizadas = claves.map { normalizarParaBusqueda($0) }
        for indice in lineas.indices {
            let lineaNormalizada = normalizarParaBusqueda(lineas[indice])
            guard clavesNormalizadas.contains(where: {
                lineaNormalizada.contains($0)
            }) else { continue }

            let limite = min(lineas.count - 1, indice + 3)
            for candidato in indice...limite {
                if candidato > indice,
                   esEtiquetaDeResumen(
                    normalizarParaBusqueda(lineas[candidato])) {
                    break
                }
                if let monto = primerMonto(en: lineas[candidato]) {
                    return monto
                }
            }
        }
        return nil
    }

    private static func extraerFecha(de texto: String) -> Date? {
        let patrones = [
            #"(\d{4})-(\d{1,2})-(\d{1,2})"#,
            #"(\d{1,2})[\/\-\s]([A-ZÁÉa-záé]{3,4}|\d{1,2})[\/\-\s](\d{2,4})"#
        ]

        for (indice, patron) in patrones.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: patron),
                  let coincidencia = regex.firstMatch(
                    in: texto, range: NSRange(texto.startIndex..., in: texto))
            else { continue }

            func grupo(_ numero: Int) -> String {
                guard let rango = Range(coincidencia.range(at: numero), in: texto)
                else { return "" }
                return String(texto[rango])
            }

            if indice == 0 {
                var componentes = DateComponents()
                componentes.year = Int(grupo(1))
                componentes.month = Int(grupo(2))
                componentes.day = Int(grupo(3))
                if let fecha = Calendar.current.date(from: componentes) { return fecha }
            } else if let fecha = fechaDeLinea(dia: grupo(1),
                                               mes: grupo(2),
                                               anio: grupo(3)) {
                return fecha
            }
        }
        return nil
    }

    private static func primerMonto(en texto: String) -> Double? {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?:\$\s*)?([0-9][0-9,\s]*[\.,][0-9]{2})"#),
              let coincidencia = regex.firstMatch(
                in: texto, range: NSRange(texto.startIndex..., in: texto)),
              let rango = Range(coincidencia.range(at: 1), in: texto)
        else { return nil }

        var numero = String(texto[rango])
            .replacingOccurrences(of: " ", with: "")
        if numero.contains(".") && numero.contains(",") {
            numero = numero.replacingOccurrences(of: ",", with: "")
        } else if numero.contains(","),
                  numero.split(separator: ",").last?.count == 2 {
            numero = numero.replacingOccurrences(of: ",", with: ".")
        } else {
            numero = numero.replacingOccurrences(of: ",", with: "")
        }
        return Double(numero)
    }

    private static func numeroMonetario(_ texto: String) -> Double? {
        Double(texto.replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Quita el identificador de la tarjeta que Hey antepone al comercio y
    /// compacta los saltos que PDFKit introduce dentro de una sola celda.
    private static func limpiarComercioHey(_ texto: String) -> String {
        var limpio = texto.replacingOccurrences(
            of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let regex = try? NSRegularExpression(
            pattern: #"^(?:TITULAR|VIRTUAL)\s+#?\d{12,19}\s+"#,
            options: [.caseInsensitive]),
           let coincidencia = regex.firstMatch(
            in: limpio, range: NSRange(limpio.startIndex..., in: limpio)),
           let rango = Range(coincidencia.range, in: limpio) {
            limpio.removeSubrange(rango)
        }
        return limpiarComercio(limpio)
    }

    private static func normalizarParaBusqueda(_ texto: String) -> String {
        texto.folding(options: [.diacriticInsensitive, .caseInsensitive],
                      locale: Locale(identifier: "es_MX"))
            .uppercased()
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    private static func detectarBanco(en texto: String) -> String? {
        let normalizado = normalizarParaBusqueda(texto)
        let bancos: [(claves: [String], nombre: String)] = [
            (["HEY BANCO", "HEYBANCO"], "Hey Banco"),
            (["LIVERPOOL"], "Liverpool"),
            (["RAPPICARD", "RAPPI CARD"], "RappiCard"),
            (["CITIBANAMEX", "BANAMEX"], "Banamex"),
            (["BBVA"], "BBVA"),
            (["BANORTE"], "Banorte"),
            (["SANTANDER"], "Santander"),
            (["HSBC"], "HSBC"),
            (["SCOTIABANK"], "Scotiabank"),
            (["AMERICAN EXPRESS"], "American Express"),
            (["NU MEXICO", "NU BANK", "NU PAGOS"], "Nu"),
            (["INBURSA"], "Inbursa"),
            (["BANCO AZTECA"], "Banco Azteca")
        ]
        return bancos.first { banco in
            banco.claves.contains { normalizado.contains($0) }
        }?.nombre
    }

    private static func detectarUltimosDigitos(en texto: String) -> String? {
        // 1. La fuente más fuerte es una terminación explícita o un PAN
        // enmascarado. En estos formatos el grupo ya representa los últimos 4.
        let patronesTerminacion = [
            #"(?:TERMINACION|TERMINACIÓN|ULTIMOS 4|ÚLTIMOS 4)[^\n]{0,30}?(\d{4})(?!\d)"#,
            #"(?:\*|X|•){2,}(?:\s+(?:\*|X|•){2,}){0,4}\s*(\d{4})(?!\d)"#
        ]
        for patron in patronesTerminacion {
            guard let regex = try? NSRegularExpression(
                pattern: patron, options: [.caseInsensitive]) else { continue }
            let rango = NSRange(texto.startIndex..., in: texto)
            for coincidencia in regex.matches(in: texto, range: rango) {
                guard let r = Range(coincidencia.range(at: 1), in: texto) else { continue }
                let valor = String(texto[r])
                // Evita tomar años impresos cerca de textos genéricos.
                if !(2000...2100).contains(Int(valor) ?? 0) { return valor }
            }
        }

        // 2. Hey Banco y Banamex imprimen el número completo, a veces junto y
        // a veces en bloques: "Número de tarjeta 5499 4905 6134 4490". La
        // regla anterior capturaba 5499 porque era el primer bloque. Ahora se
        // captura el PAN completo y únicamente después se toma su terminación.
        // Nunca usamos "CUENTA": Rappi, por ejemplo, también imprime un número
        // de cuenta de 20 dígitos que no identifica la tarjeta.
        let patronesPAN = [
            #"(?:NUMERO|NÚMERO)\s+DE\s+(?:LA\s+)?TARJETA\s*[:#]?\s*((?:\d[\s-]*){12,19})"#,
            #"TARJETA\s+(?:TITULAR|DIGITAL|VIRTUAL)\s*[:#]?\s*((?:\d[\s-]*){12,19})"#,
            #"(?:TITULAR|VIRTUAL)\s*#\s*((?:\d[\s-]*){12,19})"#
        ]
        for patron in patronesPAN {
            guard let regex = try? NSRegularExpression(
                pattern: patron, options: [.caseInsensitive]) else { continue }
            let rango = NSRange(texto.startIndex..., in: texto)
            for coincidencia in regex.matches(in: texto, range: rango) {
                guard let r = Range(coincidencia.range(at: 1), in: texto) else {
                    continue
                }
                let digitos = texto[r].filter(\.isNumber)
                guard (12...19).contains(digitos.count) else { continue }
                return String(digitos.suffix(4))
            }
        }
        return nil
    }

    private static func esEtiquetaDeResumen(_ textoNormalizado: String) -> Bool {
        ["FECHA DE CORTE", "FECHA LIMITE", "LIMITE DE PAGO", "PAGAR ANTES",
         "NO GENERAR INTERESES", "PAGO MINIMO", "SALDO DEUDOR TOTAL",
         "SALDO ACTUAL", "SALDO AL CORTE", "SALDO TOTAL"]
            .contains { textoNormalizado.contains($0) }
    }
}
