import Foundation

enum FechaAnalisisClaro {
    static let claveActiva = "modoHistoricoActivo"
    static let claveFecha = "fechaAnalisisReferencia"
    private static let claveAlineacionActual = "alineacionPeriodoActualV2"

    static var actual: Date {
        guard UserDefaults.standard.bool(forKey: claveActiva) else { return .now }
        let valor = UserDefaults.standard.double(forKey: claveFecha)
        return valor > 0 ? Date(timeIntervalSince1970: valor) : .now
    }

    static var estaEnModoHistorico: Bool {
        UserDefaults.standard.bool(forKey: claveActiva)
    }

    /// Todos los formularios financieros nacen en la misma fecha que usan
    /// los motores de saldos. En uso normal es hoy; durante una prueba
    /// histórica es la fecha de referencia, evitando movimientos invisibles.
    static var fechaPredeterminadaParaOperacion: Date {
        actual
    }

    static func volverAHoy() {
        UserDefaults.standard.set(false, forKey: claveActiva)
        UserDefaults.standard.set(
            Date.now.timeIntervalSince1970,
            forKey: claveFecha
        )
    }

    /// Esta migración se ejecuta una sola vez al instalar la corrección. Si
    /// ya existen estados de cuenta del ciclo real actual, abandona el modo
    /// de pruebas que pudo quedar activado durante el desarrollo.
    static func alinearUnaVezConPeriodoActual(
        tarjetas: [TarjetaCredito],
        hoy: Date = .now
    ) {
        let preferencias = UserDefaults.standard
        guard !preferencias.bool(forKey: claveAlineacionActual) else {
            return
        }
        let cortes = tarjetas.compactMap(\.estadoDeCuentaVigente)
        guard !cortes.isEmpty else { return }

        if cortes.contains(where: {
            perteneceAlPeriodoActual(
                fechaCorte: $0.fechaCorte,
                fechaLimite: $0.fechaLimitePago,
                hoy: hoy
            )
        }) {
            volverAHoy()
        }
        preferencias.set(true, forKey: claveAlineacionActual)
    }

    /// Al importar un estado que pertenece al ciclo bancario actual, Claro
    /// vuelve al presente automáticamente. Un PDF antiguo nunca activa ni
    /// desactiva por sí solo una prueba histórica.
    @discardableResult
    static func reconocerCorteImportado(
        fechaCorte: Date,
        fechaLimite: Date,
        hoy: Date = .now
    ) -> Bool {
        guard perteneceAlPeriodoActual(
            fechaCorte: fechaCorte,
            fechaLimite: fechaLimite,
            hoy: hoy
        ) else { return false }
        volverAHoy()
        return true
    }

    /// Un corte actual suele haberse emitido en los últimos 45 días y su
    /// fecha límite no lleva más de 15 días vencida. La regla tolera bancos
    /// con calendarios distintos sin confundir estados antiguos.
    static func perteneceAlPeriodoActual(
        fechaCorte: Date,
        fechaLimite: Date,
        hoy: Date = .now
    ) -> Bool {
        let calendario = Calendar.current
        let diaHoy = calendario.startOfDay(for: hoy)
        let corte = calendario.startOfDay(for: fechaCorte)
        let limite = calendario.startOfDay(for: fechaLimite)
        let antiguedad = calendario.dateComponents(
            [.day],
            from: corte,
            to: diaHoy
        ).day ?? Int.max
        let vencimiento = calendario.dateComponents(
            [.day],
            from: diaHoy,
            to: limite
        ).day ?? Int.min
        return (-3...45).contains(antiguedad) && vencimiento >= -15
    }
}
