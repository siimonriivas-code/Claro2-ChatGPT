//
//  MovimientoDetalleView.swift
//  Claro — Carpeta: Vistas/Componentes
//
//  ⭐ LA LEY 4 EN ACCIÓN.
//  Editar monto, fecha, categoría o descripción de un movimiento,
//  cancelarlo (sin borrarlo) o reactivarlo. Cada cambio importante
//  deja huella en la bitácora, y todos los saldos se recalculan solos.
//

import SwiftUI
import SwiftData

struct MovimientoDetalleView: View {
    let movimiento: Movimiento

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @Query(sort: \Categoria.nombre) private var categorias: [Categoria]
    @Query(sort: \Persona.nombre) private var personas: [Persona]

    @State private var montoEditado: Double?
    @State private var fechaEditada: Date
    @State private var detalleEditado: String
    @State private var categoriaEditada: Categoria?
    @State private var confirmandoCancelacion = false
    @State private var mostrandoDivision = false
    @State private var partesEdicion: [PersistentIdentifier: Double] = [:]

    init(movimiento: Movimiento) {
        self.movimiento = movimiento
        _montoEditado = State(initialValue: movimiento.monto)
        _fechaEditada = State(initialValue: movimiento.fecha)
        _detalleEditado = State(initialValue: movimiento.detalle)
        _categoriaEditada = State(initialValue: movimiento.categoria)
    }

    private var estaCancelado: Bool { movimiento.estado == .cancelado }

    private var hayCambios: Bool {
        (montoEditado ?? 0) != movimiento.monto
        || fechaEditada != movimiento.fecha
        || detalleEditado != movimiento.detalle
        || categoriaEditada != movimiento.categoria
    }

    private var cambiosOrdenados: [RegistroDeCambio] {
        movimiento.cambios.sorted { $0.fecha > $1.fecha }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Movimiento") {
                    filaInfo("Tipo", movimiento.tipo.rawValue)
                    if let cuenta = movimiento.cuenta {
                        filaInfo("Cuenta", "\(cuenta.banco?.nombre ?? "") · \(cuenta.nombre)")
                    }
                    if let destino = movimiento.cuentaDestino {
                        filaInfo("Cuenta destino", "\(destino.banco?.nombre ?? "") · \(destino.nombre)")
                    }
                    if let tarjeta = movimiento.tarjeta {
                        filaInfo("Tarjeta", tarjeta.nombre)
                    }
                    if let persona = movimiento.persona {
                        filaInfo("Persona", persona.nombre)
                    }
                    if estaCancelado {
                        Label("Movimiento CANCELADO: no cuenta en ningún cálculo.",
                              systemImage: "xmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Tema.urgente)
                    }
                }

                if !estaCancelado {
                    Section {
                        TextField("Monto", value: $montoEditado, format: .number)
                            .keyboardType(.decimalPad)
                        DatePicker("Fecha", selection: $fechaEditada,
                                   displayedComponents: .date)
                        Picker("Categoría", selection: $categoriaEditada) {
                            Text("Sin categoría").tag(nil as Categoria?)
                            ForEach(categorias) { cat in
                                Label(cat.nombre, systemImage: cat.icono)
                                    .tag(cat as Categoria?)
                            }
                        }
                        TextField("Descripción", text: $detalleEditado)
                    } header: {
                        Text("Editar movimiento")
                    } footer: {
                        Text("Al guardar, cada cambio queda en la bitácora y todos los saldos se recalculan solos.")
                    }
                }

                // ── División de dueños (compras regulares, domiciliados) ──
                if !estaCancelado && esCompartible {
                    Section {
                        Button {
                            cargarPartesActuales()
                            mostrandoDivision = true
                        } label: {
                            Label(resumenDivision, systemImage: "person.2.fill")
                        }
                        .disabled(personas.isEmpty)
                    } header: {
                        Text("División de dueños")
                    } footer: {
                        Text(personas.isEmpty
                             ? "Primero agrega personas en la pestaña Personas."
                             : "Para cargos domiciliados (CFE, agua) o compras regulares que corresponden a varias personas.")
                    }
                }

                Section {
                    if estaCancelado {
                        Button {
                            reactivar()
                        } label: {
                            Label("Reactivar movimiento", systemImage: "arrow.uturn.backward.circle.fill")
                                .foregroundStyle(Tema.positivo)
                        }
                    } else {
                        Button(role: .destructive) {
                            confirmandoCancelacion = true
                        } label: {
                            Label("Cancelar movimiento", systemImage: "xmark.circle.fill")
                        }
                    }
                } footer: {
                    Text("Cancelar no borra: el movimiento queda visible y tachado, sin efecto en los cálculos, y puedes reactivarlo cuando quieras.")
                }

                if !cambiosOrdenados.isEmpty {
                    Section("Bitácora de cambios") {
                        ForEach(cambiosOrdenados) { cambio in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(cambio.campo): \(cambio.valorAnterior) → \(cambio.valorNuevo)")
                                    .font(.footnote)
                                Text(cambio.fecha.formatted(date: .abbreviated,
                                                            time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(Tema.textoSecundario)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Detalle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { cerrar() }
                }
                if !estaCancelado {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Guardar") { guardarCambios() }
                            .disabled(!hayCambios || (montoEditado ?? 0) <= 0)
                    }
                }
            }
            .sheet(isPresented: $mostrandoDivision, onDismiss: aplicarDivision) {
                AsignacionCompartidaView(
                    titulo: movimiento.detalle.isEmpty
                            ? movimiento.tipo.rawValue : movimiento.detalle,
                    montoBase: movimiento.monto,
                    esMensual: false,
                    personas: personas,
                    partes: $partesEdicion)
            }
            .confirmationDialog("¿Cancelar este movimiento?",
                                isPresented: $confirmandoCancelacion,
                                titleVisibility: .visible) {
                Button("Sí, cancelar movimiento", role: .destructive) { cancelar() }
                Button("No", role: .cancel) { }
            } message: {
                Text("Dejará de contar en todos los cálculos, pero quedará visible en el historial.")
            }
        }
        .aparienciaDeLaApp()
    }

    private func filaInfo(_ titulo: String, _ valor: String) -> some View {
        HStack {
            Text(titulo)
            Spacer()
            Text(valor)
                .foregroundStyle(Tema.textoSecundario)
        }
    }

    // MARK: - División de dueños

    /// Solo gastos y compras se comparten. Los movimientos que
    /// pertenecen a un plan a meses se dividen desde el detalle del plan.
    private var esCompartible: Bool {
        (movimiento.tipo == .gasto || movimiento.tipo == .compraCredito)
        && movimiento.planMSI == nil
    }

    private var resumenDivision: String {
        guard let compartida = movimiento.compraCompartida,
              !compartida.participaciones.isEmpty else {
            return "100% mía · toca para compartir"
        }
        var nombres: [String] = []
        for parte in compartida.participaciones {
            if let nombre = parte.persona?.nombre, !nombres.contains(nombre) {
                nombres.append(nombre)
            }
        }
        return "Compartida con \(nombres.joined(separator: ", "))"
    }

    private func cargarPartesActuales() {
        partesEdicion = [:]
        guard let compartida = movimiento.compraCompartida else { return }
        for parte in compartida.participaciones {
            if let persona = parte.persona, partesEdicion[persona.id] == nil {
                partesEdicion[persona.id] = parte.monto
            }
        }
    }

    private func aplicarDivision() {
        let conMonto = partesEdicion.filter { $0.value > 0 }

        // 100% mía: retirar la división si existía
        if conMonto.isEmpty {
            if let compartida = movimiento.compraCompartida {
                for parte in compartida.participaciones { contexto.delete(parte) }
                movimiento.compraCompartida = nil
                contexto.delete(compartida)
            }
            return
        }

        let compartida: CompraCompartida
        if let existente = movimiento.compraCompartida {
            compartida = existente
            for parte in compartida.participaciones { contexto.delete(parte) }
        } else {
            compartida = CompraCompartida()
            contexto.insert(compartida)
            movimiento.compraCompartida = compartida
        }

        for persona in personas {
            if let monto = conMonto[persona.id], monto > 0 {
                contexto.insert(Participacion(monto: monto,
                                              persona: persona,
                                              compra: compartida))
            }
        }
    }

    // MARK: - Acciones (Ley 4)

    private func registrar(campo: String, anterior: String, nuevo: String) {
        let registro = RegistroDeCambio(campo: campo,
                                        valorAnterior: anterior,
                                        valorNuevo: nuevo,
                                        movimiento: movimiento)
        contexto.insert(registro)
    }

    private func guardarCambios() {
        if let nuevoMonto = montoEditado, nuevoMonto != movimiento.monto {
            registrar(campo: "Monto",
                      anterior: movimiento.monto.comoDinero,
                      nuevo: nuevoMonto.comoDinero)
            movimiento.monto = nuevoMonto.redondeadoAMoneda
        }
        if fechaEditada != movimiento.fecha {
            registrar(campo: "Fecha",
                      anterior: movimiento.fecha.formatted(date: .abbreviated, time: .omitted),
                      nuevo: fechaEditada.formatted(date: .abbreviated, time: .omitted))
            movimiento.fecha = fechaEditada
        }
        if categoriaEditada != movimiento.categoria {
            registrar(campo: "Categoría",
                      anterior: movimiento.categoria?.nombre ?? "Sin categoría",
                      nuevo: categoriaEditada?.nombre ?? "Sin categoría")
            movimiento.categoria = categoriaEditada
        }
        if detalleEditado != movimiento.detalle {
            registrar(campo: "Descripción",
                      anterior: movimiento.detalle.isEmpty ? "—" : movimiento.detalle,
                      nuevo: detalleEditado.isEmpty ? "—" : detalleEditado)
            movimiento.detalle = detalleEditado
        }
        movimiento.editadoEl = .now
        cerrar()
    }

    private func cancelar() {
        registrar(campo: "Estado", anterior: "Activo", nuevo: "Cancelado")
        movimiento.estado = .cancelado
        movimiento.editadoEl = .now
        cerrar()
    }

    private func reactivar() {
        registrar(campo: "Estado", anterior: "Cancelado", nuevo: "Activo")
        movimiento.estado = .activo
        movimiento.editadoEl = .now
        cerrar()
    }
}
