//
//  MotorMSI.swift
//  Claro — Carpeta: Motor
//
//  ⭐ LA LEY 3 EN ACCIÓN.
//  · generada = el banco ya la incluyó en un corte
//  · cubierta = el corte que la incluyó fue CUBIERTO con pagos reales
//  Un plan solo concluye cuando TODAS están generadas Y cubiertas.
//

import Foundation

extension MensualidadMSI {
    /// ¿Ya quedó respaldada por pagos reales? Una mensualidad está
    /// cubierta cuando el estado de cuenta que la incluyó alcanzó el
    /// pago para no generar intereses (Ley 2 + Ley 3).
    var estaCubiertaReal: Bool {
        // Mensualidades de historial importado llegan marcadas como cubiertas
        if cubierta { return true }
        guard let estado = estadoDeCuenta else { return false }
        return estado.situacion == .cubierto
    }
}

extension PlanMSI {

    var mensualidadesOrdenadas: [MensualidadMSI] {
        mensualidades.sorted { $0.numero < $1.numero }
    }

    /// Cuántas están cubiertas con pagos REALES.
    var cubiertasReal: Int {
        mensualidades.filter { $0.estaCubiertaReal }.count
    }

    /// ⭐ La regla de oro: generadas completas Y cubiertas completas.
    var estaConcluidoReal: Bool {
        generadas == numeroMeses && cubiertasReal == numeroMeses
    }

    /// La próxima mensualidad que el banco aún no genera (la "que sigue").
    var siguientePendienteDeGenerar: MensualidadMSI? {
        mensualidades.filter { !$0.fueGenerada }
                     .min(by: { $0.numero < $1.numero })
    }

    /// Dinero de mensualidades YA generadas pero AÚN no cubiertas.
    var montoPendienteDeCubrir: Double {
        mensualidades.filter { $0.fueGenerada && !$0.estaCubiertaReal }
                     .reduce(0) { $0 + $1.monto }
    }

    /// Dinero que este plan seguirá cobrando en meses futuros.
    var compromisoFuturo: Double {
        mensualidades.filter { !$0.fueGenerada }
                     .reduce(0) { $0 + $1.monto }
    }

    /// La mensualidad "normal" del plan (la que más se repite).
    /// Útil cuando hay un pago final congelado de monto distinto.
    var mensualidadTipica: Double {
        let montos = mensualidades.map(\.monto)
        guard !montos.isEmpty else { return montoMensualidad }
        var conteo: [Double: Int] = [:]
        for monto in montos { conteo[monto, default: 0] += 1 }
        return conteo.max(by: { $0.value < $1.value })?.key ?? montoMensualidad
    }

    /// El pago final congelado (esquemas tipo Banamex: X meses + un pago
    /// diferido al final). Es la última mensualidad si su monto es
    /// distinto a la mensualidad típica.
    var pagoCongelado: Double? {
        guard mensualidades.count > 1,
              let ultima = mensualidadesOrdenadas.last,
              abs(ultima.monto - mensualidadTipica) > 0.01 else { return nil }
        return ultima.monto
    }
}
