import Foundation
import SwiftData

enum MigradorDatosClaro {
    private static let clave = "versionModeloDatosClaro"
    static let versionActual = 8

    /// Las etapas son idempotentes: interrumpir la app no deja una migración
    /// a medias y volver a abrirla es seguro.
    @MainActor static func ejecutarSiHaceFalta(contexto: ModelContext) {
        var version = UserDefaults.standard.integer(forKey: clave)
        if version < 1 {
            // La versión original no almacenaba número de esquema.
            version = 1
            UserDefaults.standard.set(version, forKey: clave)
        }
        if version < 2 {
            // Los nuevos campos financieros son opcionales y los modelos
            // avanzados nacen vacíos; SwiftData realiza la migración ligera.
            // Esta etapa deja el punto explícito para futuras normalizaciones.
            try? contexto.save()
            version = 2
            UserDefaults.standard.set(version, forKey: clave)
        }
        if version < 3 {
            do {
                try reclasificarExcedentesHistoricos(contexto: contexto)
                try contexto.save()
                version = 3
                UserDefaults.standard.set(version, forKey: clave)
            } catch {
                return
            }
        }
        if version < 4 {
            // El módulo de gastos compartidos nace vacío y aislado. SwiftData
            // agrega sus modelos mediante migración ligera.
            try? contexto.save()
            version = 4
            UserDefaults.standard.set(version, forKey: clave)
        }
        if version < 5 {
            do {
                try repararPagosReutilizados(contexto: contexto)
                try contexto.save()
                version = 5
                UserDefaults.standard.set(version, forKey: clave)
            } catch {
                return
            }
        }
        if version < 6 {
            do {
                let tarjetas = try contexto.fetch(
                    FetchDescriptor<TarjetaCredito>())
                for tarjeta in tarjetas {
                    tarjeta.sellarAsignacionUnicaDePagos()
                }
                try contexto.save()
                version = 6
                UserDefaults.standard.set(version, forKey: clave)
            } catch {
                return
            }
        }
        if version < 7 {
            // La primera versión de esta conciliación podía ejecutarse antes
            // de que CloudKit hidratara el almacén. Avanzamos a la etapa
            // reintentable, que solo se marca al completar el ajuste.
            version = 7
            UserDefaults.standard.set(version, forKey: clave)
        }
        if version < 8 {
            do {
                UserDefaults.standard.set(
                    "iniciando",
                    forKey: "diagnosticoConciliacionJulio2026"
                )
                guard let resultado = try prepararInicioOficialJulio2026(
                    contexto: contexto
                ) else { return }
                try contexto.save()
                version = 8
                UserDefaults.standard.set(version, forKey: clave)
                UserDefaults.standard.set(
                    "aplicada: \(resultado)",
                    forKey: "diagnosticoConciliacionJulio2026"
                )
            } catch {
                UserDefaults.standard.set(
                    "error: \(error)",
                    forKey: "diagnosticoConciliacionJulio2026"
                )
                return
            }
        }
    }

    /// Cierra una sola vez el periodo de pruebas confirmado por el usuario.
    ///
    /// La reparación exige la huella completa del conjunto oficial de julio
    /// y los dos pagos reales. Así no modifica instalaciones nuevas ni datos
    /// de otra persona que casualmente tenga una cuenta con nombre parecido.
    ///
    /// La cuenta parte de la fotografía real de $4,314.35 tomada justo antes
    /// de pagar Liverpool y Rappi. Los movimientos históricos se conservan
    /// como bitácora, pero dejan de alterar el disponible desde esa foto.
    @MainActor private static func prepararInicioOficialJulio2026(
        contexto: ModelContext
    ) throws -> String? {
        let calendario = Calendar(identifier: .gregorian)
        let estados = try contexto.fetch(FetchDescriptor<EstadoDeCuenta>())
        let cuentas = try contexto.fetch(FetchDescriptor<CuentaBancaria>())
        let movimientos = try contexto.fetch(FetchDescriptor<Movimiento>())

        // Huella tomada de los siete PDF oficiales. No depende del vínculo
        // EstadoDeCuenta → Tarjeta, que CloudKit puede hidratar después.
        let cortesOficiales: [
            (fecha: (Int, Int, Int), saldo: Double, pago: Double)
        ] = [
            ((2026, 7, 6), 903.36, 476.89),
            ((2026, 7, 10), 41_685.01, 2_074.70),
            ((2026, 7, 13), 299.00, 299.00),
            ((2026, 7, 13), 13_985.11, 5_776.46),
            ((2026, 7, 17), 21_399.54, 13_828.60),
            ((2026, 7, 17), 6_295.08, 6_295.08),
            ((2026, 7, 20), 39_380.29, 14_248.79)
        ]

        let tieneConjuntoOficial = cortesOficiales.allSatisfy { esperado in
            estados.contains { estado in
                componentesDeFecha(
                    estado.fechaCorte,
                    calendario: calendario
                ) == esperado.fecha
                    && abs(estado.saldoAlCorte - esperado.saldo) < 0.01
                    && abs(
                        estado.pagoParaNoGenerarIntereses - esperado.pago
                    ) < 0.01
            }
        }
        guard tieneConjuntoOficial else {
            UserDefaults.standard.set(
                "faltan cortes",
                forKey: "diagnosticoConciliacionJulio2026"
            )
            return nil
        }

        guard let cuenta = cuentas.first(where: {
            !$0.archivada
                && normalizar($0.nombre).contains("DEBITO")
                && normalizar($0.nombre).contains("BBVA")
        }) else {
            UserDefaults.standard.set(
                "falta cuenta",
                forKey: "diagnosticoConciliacionJulio2026"
            )
            return nil
        }

        let pagosRealesEsperados: [
            (monto: Double, corte: (Int, Int, Int))
        ] = [
            (476.89, (2026, 7, 6)),
            (299.00, (2026, 7, 13))
        ]
        let pagosReales = pagosRealesEsperados.compactMap { esperado in
            movimientos
                .filter {
                    $0.cuentaParaCalculos
                        && $0.tipo == .pagoTarjeta
                        && $0.cuenta?.persistentModelID
                            == cuenta.persistentModelID
                        && abs($0.monto - esperado.monto) < 0.01
                        && $0.fechaCorteObjetivoPago.map {
                            componentesDeFecha($0, calendario: calendario)
                                == esperado.corte
                        } == true
                }
                .max { $0.creadoEl < $1.creadoEl }
        }
        guard pagosReales.count == pagosRealesEsperados.count,
              let primerPago = pagosReales.map(\.fecha).min()
        else {
            UserDefaults.standard.set(
                "faltan pagos: \(pagosReales.count)",
                forKey: "diagnosticoConciliacionJulio2026"
            )
            return nil
        }

        // Los tres pagos fueron capturas de prueba y el usuario confirmó que
        // no ocurrieron. Cancelar conserva la trazabilidad sin descontarlos.
        let pagosDePrueba: [(monto: Double, corte: (Int, Int, Int))] = [
            (9_977.51, (2026, 6, 20)),
            (11_297.44, (2026, 6, 19)),
            (20_551.46, (2026, 6, 18))
        ]
        for pago in movimientos where pago.cuentaParaCalculos
            && pago.tipo == .pagoTarjeta
            && pago.cuenta?.persistentModelID == cuenta.persistentModelID {
            guard pagosDePrueba.contains(where: { esperado in
                abs(pago.monto - esperado.monto) < 0.01
                    && pago.fechaCorteObjetivoPago.map {
                        componentesDeFecha($0, calendario: calendario)
                            == esperado.corte
                    } == true
            }) else { continue }

            pago.estado = .cancelado
            pago.editadoEl = .now
            pago.detalle = pago.detalle.isEmpty
                ? "Cancelado al cerrar el periodo de pruebas"
                : "\(pago.detalle) · cancelado al cerrar pruebas"
        }

        // Solo retiramos las fichas de los tres cortes simulados. No borramos
        // sus compras o asignaciones: sirven como memoria para reconocer MSI
        // y personas en los estados oficiales posteriores.
        let cortesDePrueba: [
            (fecha: (Int, Int, Int), saldo: Double, pago: Double)
        ] = [
            ((2026, 6, 18), 29_002.93, 20_551.46),
            ((2026, 6, 19), 11_297.44, 11_297.44),
            ((2026, 6, 20), 38_690.01, 9_977.51)
        ]
        for estado in estados where cortesDePrueba.contains(where: {
            componentesDeFecha(
                estado.fechaCorte,
                calendario: calendario
            ) == $0.fecha
                && abs(estado.saldoAlCorte - $0.saldo) < 0.01
                && abs(
                    estado.pagoParaNoGenerarIntereses - $0.pago
                ) < 0.01
        }) {
            contexto.delete(estado)
        }

        cuenta.saldoInicial = 4_314.35
        cuenta.fechaSaldoInicial = primerPago.addingTimeInterval(-1)
        return "saldo preparado"
    }

    private static func normalizar(_ texto: String) -> String {
        texto
            .folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "es_MX"))
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func componentesDeFecha(
        _ fecha: Date,
        calendario: Calendar
    ) -> (Int, Int, Int) {
        let componentes = calendario.dateComponents(
            [.year, .month, .day],
            from: fecha
        )
        return (
            componentes.year ?? 0,
            componentes.month ?? 0,
            componentes.day ?? 0
        )
    }

    /// Versiones anteriores restaban el depósito completo a la persona. Si
    /// alguien pagaba más que sus compras capturadas, aparecía como si el
    /// usuario le debiera. Conservamos el dinero en la cuenta, aplicamos solo
    /// lo adeudado y convertimos el resto en un ingreso vinculado a la persona.
    @MainActor private static func reclasificarExcedentesHistoricos(
        contexto: ModelContext
    ) throws {
        let personas = try contexto.fetch(FetchDescriptor<Persona>())
        for persona in personas {
            let cobros = persona.movimientos
                .filter { $0.cuentaParaCalculos && $0.tipo == .cobroRecibido }
                .sorted {
                    if $0.fecha != $1.fecha { return $0.fecha < $1.fecha }
                    return $0.creadoEl < $1.creadoEl
                }
            var aplicadoAnterior = 0.0

            for cobro in cobros {
                let deudaDisponible = persona.participaciones
                    .filter {
                        guard let movimiento = $0.compra?.movimiento else {
                            return false
                        }
                        return movimiento.cuentaParaCalculos
                            && movimiento.fecha <= cobro.fecha
                    }
                    .reduce(0) { $0 + $1.monto }
                let distribucion = MotorDePersonas.distribuirCobro(
                    monto: cobro.monto,
                    saldoPendiente: max(0, deudaDisponible - aplicadoAnterior))
                aplicadoAnterior += distribucion.aplicadoADeuda

                guard distribucion.excedenteComoIngreso > 0 else { continue }
                let detalleAnterior = cobro.detalle
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let concepto = detalleAnterior.isEmpty
                    ? "Excedente recibido de \(persona.nombre)"
                    : "\(detalleAnterior) · excedente"

                if distribucion.aplicadoADeuda > 0 {
                    cobro.monto = distribucion.aplicadoADeuda
                    cobro.editadoEl = .now
                    let ingreso = Movimiento(
                        tipo: .ingreso,
                        monto: distribucion.excedenteComoIngreso,
                        fecha: cobro.fecha,
                        detalle: concepto,
                        cuenta: cobro.cuenta,
                        persona: persona)
                    ingreso.importacionID = cobro.importacionID
                    contexto.insert(ingreso)
                } else {
                    cobro.tipo = .ingreso
                    cobro.detalle = concepto
                    cobro.editadoEl = .now
                }
            }
        }
    }

    /// Repara el caso histórico detectado al importar un corte nuevo: un pago
    /// ya registrado antes de esa importación tenía una fecha capturada
    /// posterior al corte y coincidía exactamente con el PNGI anterior. La
    /// coincidencia de importe + orden de creación evita reasignar pagos
    /// legítimos del corte actual.
    @MainActor private static func repararPagosReutilizados(
        contexto: ModelContext
    ) throws {
        let tarjetas = try contexto.fetch(FetchDescriptor<TarjetaCredito>())
        let calendario = Calendar.current

        for tarjeta in tarjetas {
            let estados = tarjeta.estadosDeCuenta.sorted {
                $0.fechaCorte < $1.fechaCorte
            }
            guard estados.count >= 2 else { continue }

            for indice in 1..<estados.count {
                let anterior = estados[indice - 1]
                let actual = estados[indice]
                guard let loteActual = actual.importacionID,
                      let importadoEl = tarjeta.movimientos
                        .filter({ $0.importacionID == loteActual })
                        .map(\.creadoEl).min()
                else { continue }

                let inicioActual = calendario.startOfDay(for: actual.fechaCorte)
                let candidatos = tarjeta.movimientos.filter {
                    $0.cuentaParaCalculos
                        && $0.tipo == .pagoTarjeta
                        && $0.fechaCorteObjetivoPago == nil
                        && $0.creadoEl < importadoEl
                        && calendario.startOfDay(for: $0.fecha) >= inicioActual
                }
                let total = candidatos.reduce(0) { $0 + $1.monto }
                    .redondeadoAMoneda
                guard !candidatos.isEmpty,
                      abs(total - anterior.pagoParaNoGenerarIntereses) <= 1.0
                else { continue }

                for pago in candidatos {
                    pago.fechaCorteObjetivoPago = anterior.fechaCorte
                }
            }
        }
    }
}
