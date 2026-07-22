import Foundation

struct SaldoGastoCompartido: Identifiable {
    let id: String
    let nombre: String
    let saldo: Double
}

struct DeudaGastoSimplificada: Identifiable {
    let id: String
    let deudor: String
    let acreedor: String
    let monto: Double
}

enum MotorGastosCompartidos {
    private static let claveUsuario = "__usuario__"

    static func saldos(de grupo: GrupoGastosCompartidos) -> [SaldoGastoCompartido] {
        var montos: [String: Double] = [:]
        var nombres: [String: String] = [claveUsuario: "Tú"]

        for gasto in grupo.gastos {
            let clavePagador = clave(esUsuario: gasto.pagadorEsUsuario,
                                     persona: gasto.pagador,
                                     nombreGuardado: gasto.pagadorNombreGuardado)
            nombres[clavePagador] = gasto.nombrePagador
            montos[clavePagador, default: 0] += gasto.monto

            for parte in gasto.partes {
                let claveParte = clave(esUsuario: parte.esUsuario,
                                       persona: parte.persona,
                                       nombreGuardado: parte.personaNombreGuardado)
                nombres[claveParte] = parte.nombreParticipante
                montos[claveParte, default: 0] -= parte.monto
            }
        }

        for pago in grupo.liquidaciones {
            let clavePagador = clave(esUsuario: pago.pagadorEsUsuario,
                                     persona: pago.pagador,
                                     nombreGuardado: pago.pagadorNombreGuardado)
            let claveReceptor = clave(esUsuario: pago.receptorEsUsuario,
                                      persona: pago.receptor,
                                      nombreGuardado: pago.receptorNombreGuardado)
            nombres[clavePagador] = pago.nombrePagador
            nombres[claveReceptor] = pago.nombreReceptor
            montos[clavePagador, default: 0] += pago.monto
            montos[claveReceptor, default: 0] -= pago.monto
        }

        return montos.map { clave, monto in
            SaldoGastoCompartido(id: clave,
                                 nombre: nombres[clave] ?? "Participante",
                                 saldo: monto.redondeadoAMoneda)
        }
        .filter { abs($0.saldo) >= 0.01 }
        .sorted { $0.nombre.localizedCaseInsensitiveCompare($1.nombre) == .orderedAscending }
    }

    /// Reduce las transferencias necesarias sin alterar ningún gasto.
    static func deudasSimplificadas(
        de grupo: GrupoGastosCompartidos
    ) -> [DeudaGastoSimplificada] {
        let balances = saldos(de: grupo)
        var deudores = balances
            .filter { $0.saldo < -0.009 }
            .map { (nombre: $0.nombre, monto: -$0.saldo) }
            .sorted { $0.monto > $1.monto }
        var acreedores = balances
            .filter { $0.saldo > 0.009 }
            .map { (nombre: $0.nombre, monto: $0.saldo) }
            .sorted { $0.monto > $1.monto }
        var resultado: [DeudaGastoSimplificada] = []
        var indiceDeudor = 0
        var indiceAcreedor = 0

        while indiceDeudor < deudores.count
                && indiceAcreedor < acreedores.count {
            let monto = min(deudores[indiceDeudor].monto,
                            acreedores[indiceAcreedor].monto)
                .redondeadoAMoneda
            if monto >= 0.01 {
                let deudor = deudores[indiceDeudor].nombre
                let acreedor = acreedores[indiceAcreedor].nombre
                resultado.append(DeudaGastoSimplificada(
                    id: "\(deudor)|\(acreedor)|\(resultado.count)",
                    deudor: deudor, acreedor: acreedor, monto: monto))
            }
            deudores[indiceDeudor].monto -= monto
            acreedores[indiceAcreedor].monto -= monto
            if deudores[indiceDeudor].monto < 0.01 { indiceDeudor += 1 }
            if acreedores[indiceAcreedor].monto < 0.01 { indiceAcreedor += 1 }
        }
        return resultado
    }

    private static func clave(esUsuario: Bool, persona: Persona?,
                              nombreGuardado: String) -> String {
        if esUsuario { return claveUsuario }
        if let persona { return "persona:\(persona.id)" }
        let nombreNormalizado = nombreGuardado.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "es_MX"))
        return "eliminada:\(nombreNormalizado)"
    }
}
