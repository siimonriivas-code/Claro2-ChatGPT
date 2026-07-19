//
//  AdministradorRespaldos.swift
//  Claro
//
//  Respaldo JSON local. El PDF original nunca se incluye.
//

import Foundation
import SwiftData

struct RespaldoClaro: Codable {
    var version: Int = 2
    var creadoEl: Date = .now
    var bancos: [BancoDTO]
    var categorias: [CategoriaDTO]
    var cuentas: [CuentaDTO]
    var tarjetas: [TarjetaDTO]
    var personas: [PersonaDTO]
    var deudas: [DeudaDTO]
    var estados: [EstadoDTO]
    var planes: [PlanDTO]
    var mensualidades: [MensualidadDTO]
    var movimientos: [MovimientoDTO]
    var compartidas: [CompartidaDTO]
    var cambios: [CambioDTO]
    var ingresosRecurrentes: [IngresoRecurrenteDTO]? = nil
    var ocurrenciasIngreso: [OcurrenciaIngresoDTO]? = nil
    var conversaciones: [ConversacionDTO]? = nil
    var conciliaciones: [ConciliacionDTO]? = nil
    var preferencias: PreferenciasDTO

    var totalRegistros: Int {
        bancos.count + categorias.count + cuentas.count + tarjetas.count
            + personas.count + deudas.count + estados.count + planes.count
            + mensualidades.count + movimientos.count + compartidas.count
            + compartidas.reduce(0) { $0 + $1.partes.count } + cambios.count
            + (ingresosRecurrentes?.count ?? 0) + (ocurrenciasIngreso?.count ?? 0)
            + (conversaciones?.reduce(0) { $0 + 1 + $1.mensajes.count } ?? 0)
            + (conciliaciones?.count ?? 0)
    }
}

struct BancoDTO: Codable { let id: UUID; let nombre, colorHex, icono: String }
struct CategoriaDTO: Codable {
    let id: UUID; let nombre, icono, colorHex: String; let esPredefinida: Bool
}
struct CuentaDTO: Codable {
    let id: UUID; let bancoID: UUID?; let nombre, tipoRaw: String
    let saldoInicial: Double; let fechaSaldoInicial: Date
}
struct TarjetaDTO: Codable {
    let id: UUID; let bancoID: UUID?; let nombre, ultimosDigitos, colorHex: String
    let limiteCredito: Double; let diaCorte, diaLimitePago: Int
    let saldoInicial: Double; let fechaSaldoInicial: Date
    let tasaAnual, cat: Double?
}
struct PersonaDTO: Codable { let id: UUID; let nombre, colorHex: String }
struct DeudaDTO: Codable {
    let id: UUID; let acreedor: String; let montoOriginal: Double
    let fecha: Date; let notas: String
    let tasaAnual, cat: Double?; let plazoMeses: Int?; let mensualidad: Double?
}
struct IngresoRecurrenteDTO: Codable {
    let id: UUID; let cuentaID: UUID?; let nombre: String; let montoEsperado: Double
    let diaInicial, diaFinal: Int; let activo: Bool; let creadoEl: Date
}
struct OcurrenciaIngresoDTO: Codable {
    let ingresoID, movimientoID: UUID?; let mes: Date; let estadoRaw: String
    let montoRecibido: Double; let fechaRecibida: Date?
}
struct ConversacionDTO: Codable {
    struct MensajeDTO: Codable {
        let esUsuario: Bool; let texto: String; let fuenteRaw: String?
        let ambitoRaw: String; let creadoEl: Date
    }
    let titulo: String; let creadaEl, actualizadaEl: Date; let resumen: String
    let mensajes: [MensajeDTO]
}
struct ConciliacionDTO: Codable {
    let cuentaID: UUID?; let bancoDetectado, archivoOrigen: String
    let fechaInicial, fechaFinal: Date?; let saldoInicialReportado, saldoFinalReportado: Double?
    let saldoCalculadoAlImportar: Double; let movimientosImportados: Int
    let importacionID: UUID; let creadaEl: Date
}
struct EstadoDTO: Codable {
    let id: UUID; let tarjetaID: UUID?
    let fechaCorte, fechaLimitePago, inicioPeriodo, finPeriodo: Date
    let pagoParaNoGenerarIntereses, pagoMinimo, saldoAlCorte: Double
    let importacionID: UUID?; let huellaPDF, archivoOrigen, bancoDetectado: String?
}
struct PlanDTO: Codable {
    let id: UUID; let tarjetaID: UUID?; let detalle: String
    let montoTotal: Double; let numeroMeses: Int; let fechaCompra: Date
    let importacionID: UUID?
}
struct MensualidadDTO: Codable {
    let id: UUID; let planID, estadoID: UUID?; let numero: Int; let monto: Double
    let fechaGeneracion: Date?; let cubierta: Bool; let importacionID: UUID?
}
struct MovimientoDTO: Codable {
    let id: UUID
    let cuentaID, cuentaDestinoID, tarjetaID, categoriaID, personaID: UUID?
    let planID, deudaID: UUID?
    let tipoRaw: String; let monto: Double; let fecha: Date; let detalle, estadoRaw: String
    let creadoEl, editadoEl: Date?; let importacionID: UUID?
}
struct CompartidaDTO: Codable {
    struct ParteDTO: Codable {
        let personaID: UUID?; let monto: Double; let importacionID: UUID?
    }
    let movimientoID: UUID; let partes: [ParteDTO]
}
struct CambioDTO: Codable {
    let movimientoID: UUID?; let fecha: Date
    let campo, valorAnterior, valorNuevo: String
}
struct PreferenciasDTO: Codable {
    let bloqueoActivado, notificacionesActivadas, importarConIA, montosOcultos: Bool
    let apariencia: String
    let planificacionJSON: Data?
    var modoHistoricoActivo: Bool? = nil
    var fechaAnalisisReferencia: Double? = nil
}

enum AdministradorRespaldos {

    static func crear(contexto: ModelContext) throws -> RespaldoClaro {
        let bancos = try contexto.fetch(FetchDescriptor<Banco>())
        let categorias = try contexto.fetch(FetchDescriptor<Categoria>())
        let cuentas = try contexto.fetch(FetchDescriptor<CuentaBancaria>())
        let tarjetas = try contexto.fetch(FetchDescriptor<TarjetaCredito>())
        let personas = try contexto.fetch(FetchDescriptor<Persona>())
        let deudas = try contexto.fetch(FetchDescriptor<Deuda>())
        let estados = try contexto.fetch(FetchDescriptor<EstadoDeCuenta>())
        let planes = try contexto.fetch(FetchDescriptor<PlanMSI>())
        let mensualidades = try contexto.fetch(FetchDescriptor<MensualidadMSI>())
        let movimientos = try contexto.fetch(FetchDescriptor<Movimiento>())
        let ingresos = try contexto.fetch(FetchDescriptor<IngresoRecurrente>())
        let ocurrencias = try contexto.fetch(FetchDescriptor<OcurrenciaIngresoRecurrente>())
        let conversaciones = try contexto.fetch(FetchDescriptor<ConversacionFinanciera>())
        let conciliaciones = try contexto.fetch(FetchDescriptor<ConciliacionCuentaBancaria>())

        let bancoID = ids(bancos)
        let categoriaID = ids(categorias)
        let cuentaID = ids(cuentas)
        let tarjetaID = ids(tarjetas)
        let personaID = ids(personas)
        let deudaID = ids(deudas)
        let estadoID = ids(estados)
        let planID = ids(planes)
        let mensualidadID = ids(mensualidades)
        let movimientoID = ids(movimientos)
        let ingresoID = ids(ingresos)

        let preferencias = UserDefaults.standard
        return RespaldoClaro(
            bancos: bancos.map { BancoDTO(id: bancoID[$0.persistentModelID]!,
                nombre: $0.nombre, colorHex: $0.colorHex, icono: $0.icono) },
            categorias: categorias.map { CategoriaDTO(
                id: categoriaID[$0.persistentModelID]!, nombre: $0.nombre,
                icono: $0.icono, colorHex: $0.colorHex,
                esPredefinida: $0.esPredefinida) },
            cuentas: cuentas.map { CuentaDTO(
                id: cuentaID[$0.persistentModelID]!,
                bancoID: referencia($0.banco, en: bancoID), nombre: $0.nombre,
                tipoRaw: $0.tipoRaw, saldoInicial: $0.saldoInicial,
                fechaSaldoInicial: $0.fechaSaldoInicial) },
            tarjetas: tarjetas.map { TarjetaDTO(
                id: tarjetaID[$0.persistentModelID]!,
                bancoID: referencia($0.banco, en: bancoID), nombre: $0.nombre,
                ultimosDigitos: $0.ultimosDigitos, colorHex: $0.colorHex,
                limiteCredito: $0.limiteCredito, diaCorte: $0.diaCorte,
                diaLimitePago: $0.diaLimitePago, saldoInicial: $0.saldoInicial,
                fechaSaldoInicial: $0.fechaSaldoInicial,
                tasaAnual: $0.tasaAnual, cat: $0.cat) },
            personas: personas.map { PersonaDTO(id: personaID[$0.persistentModelID]!,
                nombre: $0.nombre, colorHex: $0.colorHex) },
            deudas: deudas.map { DeudaDTO(id: deudaID[$0.persistentModelID]!,
                acreedor: $0.acreedor, montoOriginal: $0.montoOriginal,
                fecha: $0.fecha, notas: $0.notas, tasaAnual: $0.tasaAnual,
                cat: $0.cat, plazoMeses: $0.plazoMeses, mensualidad: $0.mensualidad) },
            estados: estados.map { EstadoDTO(id: estadoID[$0.persistentModelID]!,
                tarjetaID: referencia($0.tarjeta, en: tarjetaID),
                fechaCorte: $0.fechaCorte, fechaLimitePago: $0.fechaLimitePago,
                inicioPeriodo: $0.inicioPeriodo, finPeriodo: $0.finPeriodo,
                pagoParaNoGenerarIntereses: $0.pagoParaNoGenerarIntereses,
                pagoMinimo: $0.pagoMinimo, saldoAlCorte: $0.saldoAlCorte,
                importacionID: $0.importacionID, huellaPDF: $0.huellaPDF,
                archivoOrigen: $0.archivoOrigen, bancoDetectado: $0.bancoDetectado) },
            planes: planes.map { PlanDTO(id: planID[$0.persistentModelID]!,
                tarjetaID: referencia($0.tarjeta, en: tarjetaID), detalle: $0.detalle,
                montoTotal: $0.montoTotal, numeroMeses: $0.numeroMeses,
                fechaCompra: $0.fechaCompra, importacionID: $0.importacionID) },
            mensualidades: mensualidades.map { MensualidadDTO(
                id: mensualidadID[$0.persistentModelID]!,
                planID: referencia($0.plan, en: planID),
                estadoID: referencia($0.estadoDeCuenta, en: estadoID), numero: $0.numero,
                monto: $0.monto, fechaGeneracion: $0.fechaGeneracion,
                cubierta: $0.cubierta, importacionID: $0.importacionID) },
            movimientos: movimientos.map { MovimientoDTO(
                id: movimientoID[$0.persistentModelID]!,
                cuentaID: referencia($0.cuenta, en: cuentaID),
                cuentaDestinoID: referencia($0.cuentaDestino, en: cuentaID),
                tarjetaID: referencia($0.tarjeta, en: tarjetaID),
                categoriaID: referencia($0.categoria, en: categoriaID),
                personaID: referencia($0.persona, en: personaID),
                planID: referencia($0.planMSI, en: planID),
                deudaID: referencia($0.deuda, en: deudaID), tipoRaw: $0.tipoRaw,
                monto: $0.monto, fecha: $0.fecha, detalle: $0.detalle,
                estadoRaw: $0.estadoRaw, creadoEl: $0.creadoEl,
                editadoEl: $0.editadoEl, importacionID: $0.importacionID) },
            compartidas: movimientos.compactMap { movimiento in
                guard let compartida = movimiento.compraCompartida,
                      let id = movimientoID[movimiento.persistentModelID] else { return nil }
                return CompartidaDTO(movimientoID: id,
                    partes: compartida.participaciones.map { parte in
                        CompartidaDTO.ParteDTO(
                            personaID: referencia(parte.persona, en: personaID),
                            monto: parte.monto,
                            importacionID: parte.importacionID)
                    })
            },
            cambios: movimientos.flatMap { movimiento in
                movimiento.cambios.map { cambio in
                    CambioDTO(movimientoID: movimientoID[movimiento.persistentModelID],
                              fecha: cambio.fecha, campo: cambio.campo,
                              valorAnterior: cambio.valorAnterior,
                              valorNuevo: cambio.valorNuevo)
                }
            },
            ingresosRecurrentes: ingresos.map { IngresoRecurrenteDTO(
                id: ingresoID[$0.persistentModelID]!,
                cuentaID: referencia($0.cuenta, en: cuentaID), nombre: $0.nombre,
                montoEsperado: $0.montoEsperado, diaInicial: $0.diaInicial,
                diaFinal: $0.diaFinal, activo: $0.activo, creadoEl: $0.creadoEl) },
            ocurrenciasIngreso: ocurrencias.map { OcurrenciaIngresoDTO(
                ingresoID: referencia($0.ingreso, en: ingresoID),
                movimientoID: referencia($0.movimiento, en: movimientoID),
                mes: $0.mes, estadoRaw: $0.estadoRaw,
                montoRecibido: $0.montoRecibido, fechaRecibida: $0.fechaRecibida) },
            conversaciones: conversaciones.map { conversacion in ConversacionDTO(
                titulo: conversacion.titulo, creadaEl: conversacion.creadaEl,
                actualizadaEl: conversacion.actualizadaEl, resumen: conversacion.resumen,
                mensajes: conversacion.mensajes.map { ConversacionDTO.MensajeDTO(
                    esUsuario: $0.esUsuario, texto: $0.texto, fuenteRaw: $0.fuenteRaw,
                    ambitoRaw: $0.ambitoRaw, creadoEl: $0.creadoEl) }) },
            conciliaciones: conciliaciones.map { ConciliacionDTO(
                cuentaID: referencia($0.cuenta, en: cuentaID),
                bancoDetectado: $0.bancoDetectado, archivoOrigen: $0.archivoOrigen,
                fechaInicial: $0.fechaInicial, fechaFinal: $0.fechaFinal,
                saldoInicialReportado: $0.saldoInicialReportado,
                saldoFinalReportado: $0.saldoFinalReportado,
                saldoCalculadoAlImportar: $0.saldoCalculadoAlImportar,
                movimientosImportados: $0.movimientosImportados,
                importacionID: $0.importacionID, creadaEl: $0.creadaEl) },
            preferencias: PreferenciasDTO(
                bloqueoActivado: preferencias.bool(forKey: "bloqueoActivado"),
                notificacionesActivadas: preferencias.bool(forKey: "notificacionesActivadas"),
                importarConIA: preferencias.object(forKey: "importarConIA") as? Bool ?? true,
                montosOcultos: preferencias.bool(forKey: "montosOcultos"),
                apariencia: preferencias.string(forKey: "apariencia")
                    ?? Apariencia.oscuro.rawValue,
                planificacionJSON: preferencias.data(forKey: "planificacionClaro"),
                modoHistoricoActivo: preferencias.bool(forKey: "modoHistoricoActivo"),
                fechaAnalisisReferencia: preferencias.double(forKey: "fechaAnalisisReferencia")))
    }

    static func codificar(_ respaldo: RespaldoClaro) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(respaldo)
    }

    static func decodificar(_ datos: Data) throws -> RespaldoClaro {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let respaldo = try decoder.decode(RespaldoClaro.self, from: datos)
        guard (1...2).contains(respaldo.version) else { throw ErrorRespaldo.versionNoCompatible }
        return respaldo
    }

    static func restaurar(_ respaldo: RespaldoClaro,
                          contexto: ModelContext) throws {
        try eliminarActuales(contexto: contexto)

        var bancos: [UUID: Banco] = [:]
        var categorias: [UUID: Categoria] = [:]
        var cuentas: [UUID: CuentaBancaria] = [:]
        var tarjetas: [UUID: TarjetaCredito] = [:]
        var personas: [UUID: Persona] = [:]
        var deudas: [UUID: Deuda] = [:]
        var estados: [UUID: EstadoDeCuenta] = [:]
        var planes: [UUID: PlanMSI] = [:]
        var movimientos: [UUID: Movimiento] = [:]

        for dto in respaldo.bancos {
            let modelo = Banco(nombre: dto.nombre, colorHex: dto.colorHex, icono: dto.icono)
            contexto.insert(modelo); bancos[dto.id] = modelo
        }
        for dto in respaldo.categorias {
            let modelo = Categoria(nombre: dto.nombre, icono: dto.icono,
                                   colorHex: dto.colorHex,
                                   esPredefinida: dto.esPredefinida)
            contexto.insert(modelo); categorias[dto.id] = modelo
        }
        for dto in respaldo.personas {
            let modelo = Persona(nombre: dto.nombre, colorHex: dto.colorHex)
            contexto.insert(modelo); personas[dto.id] = modelo
        }
        for dto in respaldo.deudas {
            let modelo = Deuda(acreedor: dto.acreedor, montoOriginal: dto.montoOriginal,
                               fecha: dto.fecha, notas: dto.notas,
                               tasaAnual: dto.tasaAnual, cat: dto.cat,
                               plazoMeses: dto.plazoMeses, mensualidad: dto.mensualidad)
            contexto.insert(modelo); deudas[dto.id] = modelo
        }
        for dto in respaldo.cuentas {
            let modelo = CuentaBancaria(nombre: dto.nombre,
                tipo: TipoCuenta(rawValue: dto.tipoRaw) ?? .debito,
                saldoInicial: dto.saldoInicial, fechaSaldoInicial: dto.fechaSaldoInicial,
                banco: dto.bancoID.flatMap { bancos[$0] })
            contexto.insert(modelo); cuentas[dto.id] = modelo
        }
        for dto in respaldo.tarjetas {
            let modelo = TarjetaCredito(nombre: dto.nombre,
                ultimosDigitos: dto.ultimosDigitos, limiteCredito: dto.limiteCredito,
                diaCorte: dto.diaCorte, diaLimitePago: dto.diaLimitePago,
                saldoInicial: dto.saldoInicial, fechaSaldoInicial: dto.fechaSaldoInicial,
                colorHex: dto.colorHex, banco: dto.bancoID.flatMap { bancos[$0] },
                tasaAnual: dto.tasaAnual, cat: dto.cat)
            contexto.insert(modelo); tarjetas[dto.id] = modelo
        }
        for dto in respaldo.estados {
            let modelo = EstadoDeCuenta(fechaCorte: dto.fechaCorte,
                fechaLimitePago: dto.fechaLimitePago, inicioPeriodo: dto.inicioPeriodo,
                finPeriodo: dto.finPeriodo,
                pagoParaNoGenerarIntereses: dto.pagoParaNoGenerarIntereses,
                pagoMinimo: dto.pagoMinimo, saldoAlCorte: dto.saldoAlCorte,
                tarjeta: dto.tarjetaID.flatMap { tarjetas[$0] })
            modelo.importacionID = dto.importacionID; modelo.huellaPDF = dto.huellaPDF
            modelo.archivoOrigen = dto.archivoOrigen; modelo.bancoDetectado = dto.bancoDetectado
            contexto.insert(modelo); estados[dto.id] = modelo
        }
        for dto in respaldo.planes {
            let modelo = PlanMSI(detalle: dto.detalle, montoTotal: dto.montoTotal,
                numeroMeses: dto.numeroMeses, fechaCompra: dto.fechaCompra,
                tarjeta: dto.tarjetaID.flatMap { tarjetas[$0] })
            modelo.importacionID = dto.importacionID
            contexto.insert(modelo); planes[dto.id] = modelo
        }
        for dto in respaldo.mensualidades {
            let modelo = MensualidadMSI(numero: dto.numero, monto: dto.monto,
                                        plan: dto.planID.flatMap { planes[$0] })
            modelo.fechaGeneracion = dto.fechaGeneracion
            modelo.estadoDeCuenta = dto.estadoID.flatMap { estados[$0] }
            modelo.cubierta = dto.cubierta; modelo.importacionID = dto.importacionID
            contexto.insert(modelo)
        }
        for dto in respaldo.movimientos {
            let modelo = Movimiento(
                tipo: TipoMovimiento(rawValue: dto.tipoRaw) ?? .gasto,
                monto: dto.monto, fecha: dto.fecha, detalle: dto.detalle,
                cuenta: dto.cuentaID.flatMap { cuentas[$0] },
                cuentaDestino: dto.cuentaDestinoID.flatMap { cuentas[$0] },
                tarjeta: dto.tarjetaID.flatMap { tarjetas[$0] },
                categoria: dto.categoriaID.flatMap { categorias[$0] },
                persona: dto.personaID.flatMap { personas[$0] },
                planMSI: dto.planID.flatMap { planes[$0] },
                deuda: dto.deudaID.flatMap { deudas[$0] })
            modelo.tipoRaw = dto.tipoRaw; modelo.estadoRaw = dto.estadoRaw
            modelo.creadoEl = dto.creadoEl ?? dto.fecha; modelo.editadoEl = dto.editadoEl
            modelo.importacionID = dto.importacionID
            contexto.insert(modelo); movimientos[dto.id] = modelo
        }
        for dto in respaldo.compartidas {
            guard let movimiento = movimientos[dto.movimientoID] else { continue }
            let compartida = CompraCompartida(); contexto.insert(compartida)
            movimiento.compraCompartida = compartida
            for parte in dto.partes {
                let modelo = Participacion(monto: parte.monto,
                    persona: parte.personaID.flatMap { personas[$0] },
                    compra: compartida)
                modelo.importacionID = parte.importacionID
                contexto.insert(modelo)
            }
        }
        for dto in respaldo.cambios {
            let modelo = RegistroDeCambio(campo: dto.campo,
                valorAnterior: dto.valorAnterior, valorNuevo: dto.valorNuevo,
                movimiento: dto.movimientoID.flatMap { movimientos[$0] })
            modelo.fecha = dto.fecha; contexto.insert(modelo)
        }
        var ingresos: [UUID: IngresoRecurrente] = [:]
        for dto in respaldo.ingresosRecurrentes ?? [] {
            let modelo = IngresoRecurrente(nombre: dto.nombre,
                montoEsperado: dto.montoEsperado, diaInicial: dto.diaInicial,
                diaFinal: dto.diaFinal, cuenta: dto.cuentaID.flatMap { cuentas[$0] },
                activo: dto.activo)
            modelo.creadoEl = dto.creadoEl; contexto.insert(modelo); ingresos[dto.id] = modelo
        }
        for dto in respaldo.ocurrenciasIngreso ?? [] {
            let modelo = OcurrenciaIngresoRecurrente(
                mes: dto.mes,
                estado: EstadoIngresoRecurrente(rawValue: dto.estadoRaw) ?? .esperado,
                montoRecibido: dto.montoRecibido, fechaRecibida: dto.fechaRecibida,
                ingreso: dto.ingresoID.flatMap { ingresos[$0] },
                movimiento: dto.movimientoID.flatMap { movimientos[$0] })
            contexto.insert(modelo)
        }
        for dto in respaldo.conversaciones ?? [] {
            let conversacion = ConversacionFinanciera(titulo: dto.titulo)
            conversacion.creadaEl = dto.creadaEl; conversacion.actualizadaEl = dto.actualizadaEl
            conversacion.resumen = dto.resumen; contexto.insert(conversacion)
            for mensaje in dto.mensajes {
                let modelo = MensajeFinanciero(esUsuario: mensaje.esUsuario,
                    texto: mensaje.texto, fuenteRaw: mensaje.fuenteRaw,
                    ambitoRaw: mensaje.ambitoRaw, conversacion: conversacion)
                modelo.creadoEl = mensaje.creadoEl; contexto.insert(modelo)
            }
        }
        for dto in respaldo.conciliaciones ?? [] {
            let modelo = ConciliacionCuentaBancaria(
                bancoDetectado: dto.bancoDetectado, archivoOrigen: dto.archivoOrigen,
                cuenta: dto.cuentaID.flatMap { cuentas[$0] }, fechaInicial: dto.fechaInicial,
                fechaFinal: dto.fechaFinal, saldoInicialReportado: dto.saldoInicialReportado,
                saldoFinalReportado: dto.saldoFinalReportado,
                saldoCalculadoAlImportar: dto.saldoCalculadoAlImportar,
                movimientosImportados: dto.movimientosImportados, importacionID: dto.importacionID)
            modelo.creadaEl = dto.creadaEl; contexto.insert(modelo)
        }

        try contexto.save()
        aplicar(respaldo.preferencias)
        if respaldo.preferencias.notificacionesActivadas {
            ProgramadorDeNotificaciones.reprogramar(
                tarjetas: Array(tarjetas.values),
                personas: Array(personas.values)
            )
        } else {
            ProgramadorDeNotificaciones.cancelarTodas()
        }
    }

    private static func ids<T: PersistentModel>(_ modelos: [T])
        -> [PersistentIdentifier: UUID] {
        Dictionary(uniqueKeysWithValues: modelos.map { ($0.persistentModelID, UUID()) })
    }

    private static func referencia<T: PersistentModel>(
        _ modelo: T?, en mapa: [PersistentIdentifier: UUID]) -> UUID? {
        guard let modelo else { return nil }
        return mapa[modelo.persistentModelID]
    }

    private static func eliminarActuales(contexto: ModelContext) throws {
        for modelo in try contexto.fetch(FetchDescriptor<MensajeFinanciero>()) { contexto.delete(modelo) }
        for modelo in try contexto.fetch(FetchDescriptor<ConversacionFinanciera>()) { contexto.delete(modelo) }
        for modelo in try contexto.fetch(FetchDescriptor<OcurrenciaIngresoRecurrente>()) { contexto.delete(modelo) }
        for modelo in try contexto.fetch(FetchDescriptor<IngresoRecurrente>()) { contexto.delete(modelo) }
        for modelo in try contexto.fetch(FetchDescriptor<ConciliacionCuentaBancaria>()) { contexto.delete(modelo) }
        for modelo in try contexto.fetch(FetchDescriptor<RegistroDeCambio>()) { contexto.delete(modelo) }
        for modelo in try contexto.fetch(FetchDescriptor<Participacion>()) { contexto.delete(modelo) }
        for modelo in try contexto.fetch(FetchDescriptor<CompraCompartida>()) { contexto.delete(modelo) }
        for modelo in try contexto.fetch(FetchDescriptor<MensualidadMSI>()) { contexto.delete(modelo) }
        for modelo in try contexto.fetch(FetchDescriptor<PlanMSI>()) { contexto.delete(modelo) }
        for modelo in try contexto.fetch(FetchDescriptor<EstadoDeCuenta>()) { contexto.delete(modelo) }
        for modelo in try contexto.fetch(FetchDescriptor<Movimiento>()) { contexto.delete(modelo) }
        for modelo in try contexto.fetch(FetchDescriptor<Deuda>()) { contexto.delete(modelo) }
        for modelo in try contexto.fetch(FetchDescriptor<TarjetaCredito>()) { contexto.delete(modelo) }
        for modelo in try contexto.fetch(FetchDescriptor<CuentaBancaria>()) { contexto.delete(modelo) }
        for modelo in try contexto.fetch(FetchDescriptor<Banco>()) { contexto.delete(modelo) }
        for modelo in try contexto.fetch(FetchDescriptor<Persona>()) { contexto.delete(modelo) }
        for modelo in try contexto.fetch(FetchDescriptor<Categoria>()) { contexto.delete(modelo) }
    }

    private static func aplicar(_ preferencias: PreferenciasDTO) {
        let defaults = UserDefaults.standard
        defaults.set(preferencias.bloqueoActivado, forKey: "bloqueoActivado")
        defaults.set(preferencias.notificacionesActivadas,
                     forKey: "notificacionesActivadas")
        defaults.set(preferencias.importarConIA, forKey: "importarConIA")
        defaults.set(preferencias.montosOcultos, forKey: "montosOcultos")
        defaults.set(preferencias.apariencia, forKey: "apariencia")
        defaults.set(preferencias.planificacionJSON, forKey: "planificacionClaro")
        if let valor = preferencias.modoHistoricoActivo {
            defaults.set(valor, forKey: "modoHistoricoActivo")
        }
        if let valor = preferencias.fechaAnalisisReferencia {
            defaults.set(valor, forKey: "fechaAnalisisReferencia")
        }
    }
}

enum ErrorRespaldo: LocalizedError {
    case versionNoCompatible
    var errorDescription: String? {
        "Este respaldo pertenece a una versión no compatible de Claro."
    }
}
