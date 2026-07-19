import Foundation

struct MovimientoDebitoDetectado: Identifiable {
    let id = UUID()
    var fecha: Date
    var detalle: String
    var monto: Double
    var esIngreso: Bool
    var seleccionado = true
}

struct ResultadoEstadoDebito {
    var banco: String
    var fechaInicial: Date?
    var fechaFinal: Date?
    var saldoInicial: Double?
    var saldoFinal: Double?
    var movimientos: [MovimientoDebitoDetectado]
}

enum AnalizadorEstadoDebito {
    nonisolated static func analizar(texto: String, referencia: Date = .now) -> ResultadoEstadoDebito {
        let limpio = texto.replacingOccurrences(of: "\u{00a0}", with: " ")
        let normal = normalizar(limpio)
        let banco = normal.contains("BBVA") || normal.contains("BANCOMER") ? "BBVA" : "Banco no confirmado"
        let ano = detectarAno(normal, referencia: referencia)
        let saldoInicial = importeTras(etiquetas: ["SALDO INICIAL", "SALDO ANTERIOR"], texto: normal)
        let saldoFinal = importeTras(etiquetas: ["SALDO FINAL", "SALDO AL CORTE", "SALDO ACTUAL"], texto: normal)
        let movimientos = limpio.components(separatedBy: .newlines).compactMap {
            movimiento(en: $0, ano: ano)
        }
        let fechas = movimientos.map(\.fecha)
        return ResultadoEstadoDebito(banco: banco,
                                     fechaInicial: fechas.min(), fechaFinal: fechas.max(),
                                     saldoInicial: saldoInicial, saldoFinal: saldoFinal,
                                     movimientos: deduplicar(movimientos))
    }

    private nonisolated static func movimiento(en linea: String, ano: Int) -> MovimientoDebitoDetectado? {
        let texto = linea.trimmingCharacters(in: .whitespacesAndNewlines)
        guard texto.count >= 8,
              let regexFecha = try? NSRegularExpression(pattern: #"(?i)\b(\d{1,2})[\-/ ](ENE|FEB|MAR|ABR|MAY|JUN|JUL|AGO|SEP|OCT|NOV|DIC|\d{1,2})(?:[\-/ ](\d{2,4}))?\b"#),
              let match = regexFecha.firstMatch(in: texto, range: NSRange(texto.startIndex..., in: texto)),
              let rDia = Range(match.range(at: 1), in: texto),
              let rMes = Range(match.range(at: 2), in: texto),
              let dia = Int(texto[rDia]),
              let mes = mesNumero(String(texto[rMes])) else { return nil }
        var anoFila = ano
        if match.range(at: 3).location != NSNotFound,
           let rAno = Range(match.range(at: 3), in: texto), let valor = Int(texto[rAno]) {
            anoFila = valor < 100 ? 2000 + valor : valor
        }
        guard let fecha = Calendar.current.date(from: DateComponents(year: anoFila, month: mes, day: dia)) else { return nil }
        let normal = normalizar(texto)
        guard !normal.contains("SALDO INICIAL"), !normal.contains("SALDO FINAL"),
              !normal.contains("SALDO AL CORTE") else { return nil }
        let importes = extraerImportes(texto)
        guard let bruto = importes.first(where: { abs($0) > 0.0001 }) else { return nil }
        let palabrasIngreso = ["NOMINA", "PENSION", "DEPOSITO", "ABONO", "SPEI RECIBIDO", "TRANSFERENCIA RECIBIDA"]
        let palabrasSalida = ["COMPRA", "PAGO", "RETIRO", "CARGO", "DOMICILIACION", "TRANSFERENCIA ENVIADA", "SPEI ENVIADO"]
        let esIngreso: Bool
        if bruto < 0 { esIngreso = false }
        else if palabrasIngreso.contains(where: normal.contains) { esIngreso = true }
        else if palabrasSalida.contains(where: normal.contains) { esIngreso = false }
        else if normal.contains("+") { esIngreso = true }
        else { return nil } // una columna ambigua nunca se importa silenciosamente
        let detalle = texto.replacingOccurrences(of: String(texto[Range(match.range, in: texto)!]), with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return MovimientoDebitoDetectado(fecha: fecha,
                                         detalle: detalle.isEmpty ? "Movimiento bancario" : detalle,
                                         monto: redondear(abs(bruto)),
                                         esIngreso: esIngreso)
    }

    private nonisolated static func extraerImportes(_ texto: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: #"[-+]?\$?\s*\d[\d,]*\.\d{2}"#) else { return [] }
        return regex.matches(in: texto, range: NSRange(texto.startIndex..., in: texto)).compactMap {
            guard let rango = Range($0.range, in: texto) else { return nil }
            return Double(texto[rango].replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: ",", with: "").replacingOccurrences(of: " ", with: ""))
        }
    }

    private nonisolated static func importeTras(etiquetas: [String], texto: String) -> Double? {
        for etiqueta in etiquetas {
            guard let rango = texto.range(of: etiqueta) else { continue }
            let fragmento = String(texto[rango.upperBound...].prefix(100))
            if let valor = extraerImportes(fragmento).first { return redondear(abs(valor)) }
        }
        return nil
    }

    private nonisolated static func detectarAno(_ texto: String, referencia: Date) -> Int {
        if let regex = try? NSRegularExpression(pattern: #"\b(20\d{2})\b"#),
           let match = regex.firstMatch(in: texto, range: NSRange(texto.startIndex..., in: texto)),
           let rango = Range(match.range(at: 1), in: texto), let ano = Int(texto[rango]) { return ano }
        return Calendar.current.component(.year, from: referencia)
    }

    private nonisolated static func mesNumero(_ texto: String) -> Int? {
        if let numero = Int(texto), (1...12).contains(numero) { return numero }
        return ["ENE":1,"FEB":2,"MAR":3,"ABR":4,"MAY":5,"JUN":6,
                "JUL":7,"AGO":8,"SEP":9,"OCT":10,"NOV":11,"DIC":12][normalizar(texto)]
    }

    private nonisolated static func normalizar(_ texto: String) -> String {
        texto.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_MX")).uppercased()
    }

    private nonisolated static func redondear(_ valor: Double) -> Double {
        (valor * 100).rounded() / 100
    }

    private nonisolated static func deduplicar(_ movimientos: [MovimientoDebitoDetectado]) -> [MovimientoDebitoDetectado] {
        var claves = Set<String>()
        return movimientos.filter {
            claves.insert("\($0.fecha.timeIntervalSinceReferenceDate)|\($0.monto)|\($0.esIngreso)|\(normalizar($0.detalle))").inserted
        }
    }
}
