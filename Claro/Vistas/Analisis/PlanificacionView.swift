//
//  PlanificacionView.swift
//  Claro
//

import SwiftUI
import SwiftData

struct PlanificacionView: View {
    @Query(sort: \Categoria.nombre) private var categorias: [Categoria]
    @Query private var movimientos: [Movimiento]

    @State private var store = PlanificacionStore()
    @State private var editandoPresupuesto: PresupuestoCategoria?
    @State private var mostrandoPresupuesto = false
    @State private var editandoMeta: MetaAhorro?
    @State private var mostrandoMeta = false

    var body: some View {
        List {
            Section {
                if store.datos.presupuestos.isEmpty {
                    Text("Define cuánto quieres gastar al mes en categorías como comida, transporte o entretenimiento.")
                        .font(.footnote)
                        .foregroundStyle(Tema.textoSecundario)
                } else {
                    ForEach(store.datos.presupuestos) { presupuesto in
                        filaPresupuesto(presupuesto)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editandoPresupuesto = presupuesto
                                mostrandoPresupuesto = true
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    store.eliminarPresupuesto(presupuesto)
                                } label: { Label("Eliminar", systemImage: "trash") }
                            }
                    }
                }
                Button {
                    editandoPresupuesto = nil
                    mostrandoPresupuesto = true
                } label: {
                    Label("Agregar presupuesto", systemImage: "plus.circle")
                }
            } header: {
                Text("Presupuesto mensual")
            }

            Section {
                if store.datos.metas.isEmpty {
                    Text("Crea metas para vacaciones, emergencias o compras importantes.")
                        .font(.footnote)
                        .foregroundStyle(Tema.textoSecundario)
                } else {
                    ForEach(store.datos.metas) { meta in
                        filaMeta(meta)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editandoMeta = meta
                                mostrandoMeta = true
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    store.eliminarMeta(meta)
                                } label: { Label("Eliminar", systemImage: "trash") }
                            }
                    }
                }
                Button {
                    editandoMeta = nil
                    mostrandoMeta = true
                } label: {
                    Label("Agregar meta de ahorro", systemImage: "plus.circle")
                }
            } header: {
                Text("Metas de ahorro")
            }
        }
        .scrollContentBackground(.hidden)
        .background(FondoClaro())
        .navigationTitle("Planificación")
        .sheet(isPresented: $mostrandoPresupuesto) {
            EditarPresupuestoView(categorias: categorias,
                                  existente: editandoPresupuesto) { nuevo in
                store.guardarPresupuesto(nuevo)
            }
        }
        .sheet(isPresented: $mostrandoMeta) {
            EditarMetaAhorroView(existente: editandoMeta) { nueva in
                store.guardarMeta(nueva)
            }
        }
    }

    private func gastado(_ categoria: String) -> Double {
        let calendario = Calendar.current
        return movimientos.filter {
            $0.cuentaParaCalculos
                && ($0.tipo == .gasto || $0.tipo == .compraCredito)
                && $0.categoria?.nombre == categoria
                && calendario.isDate($0.fecha, equalTo: .now,
                                     toGranularity: .month)
        }.reduce(0) { $0 + $1.montoPropio }
    }

    private func filaPresupuesto(_ presupuesto: PresupuestoCategoria) -> some View {
        let gasto = gastado(presupuesto.categoria)
        let progreso = presupuesto.limiteMensual > 0
            ? gasto / presupuesto.limiteMensual : 0
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(presupuesto.categoria).font(.headline)
                Spacer()
                Text("\(gasto.comoDinero) de \(presupuesto.limiteMensual.comoDinero)")
                    .font(.caption)
                    .foregroundStyle(progreso > 1 ? Tema.urgente : Tema.textoSecundario)
            }
            ProgressView(value: min(progreso, 1))
                .tint(progreso > 1 ? Tema.urgente
                      : progreso > 0.8 ? Tema.advertencia : Tema.positivo)
            if progreso > 1 {
                Text("Excedido por \((gasto - presupuesto.limiteMensual).comoDinero)")
                    .font(.caption2)
                    .foregroundStyle(Tema.urgente)
            }
        }
        .padding(.vertical, 4)
    }

    private func filaMeta(_ meta: MetaAhorro) -> some View {
        let progreso = meta.objetivo > 0 ? meta.acumulado / meta.objetivo : 0
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(meta.nombre).font(.headline)
                Spacer()
                Text("\(Int(min(progreso, 1) * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Tema.positivo)
            }
            ProgressView(value: min(progreso, 1)).tint(Tema.positivo)
            Text("\(meta.acumulado.comoDinero) de \(meta.objetivo.comoDinero)")
                .font(.caption)
                .foregroundStyle(Tema.textoSecundario)
            if let fecha = meta.fechaObjetivo {
                Text("Meta: \(fecha.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(Tema.textoSecundario)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct EditarPresupuestoView: View {
    let categorias: [Categoria]
    let existente: PresupuestoCategoria?
    let guardar: (PresupuestoCategoria) -> Void
    @Environment(\.dismiss) private var cerrar
    @State private var categoria: String
    @State private var limite: Double?

    init(categorias: [Categoria], existente: PresupuestoCategoria?,
         guardar: @escaping (PresupuestoCategoria) -> Void) {
        self.categorias = categorias; self.existente = existente; self.guardar = guardar
        _categoria = State(initialValue: existente?.categoria
                           ?? categorias.first?.nombre ?? "Otro")
        _limite = State(initialValue: existente?.limiteMensual)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Categoría", selection: $categoria) {
                    ForEach(categorias) { Text($0.nombre).tag($0.nombre) }
                }
                TextField("Límite mensual", value: $limite,
                          format: .currency(code: "MXN"))
                    .keyboardType(.decimalPad)
            }
            .navigationTitle(existente == nil ? "Nuevo presupuesto" : "Editar presupuesto")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        guardar(PresupuestoCategoria(id: existente?.id ?? UUID(),
                            categoria: categoria, limiteMensual: limite ?? 0))
                        cerrar()
                    }.disabled((limite ?? 0) <= 0)
                }
            }
        }.aparienciaDeLaApp()
    }
}

private struct EditarMetaAhorroView: View {
    let existente: MetaAhorro?
    let guardar: (MetaAhorro) -> Void
    @Environment(\.dismiss) private var cerrar
    @State private var nombre: String
    @State private var objetivo: Double?
    @State private var acumulado: Double?
    @State private var usaFecha: Bool
    @State private var fecha: Date

    init(existente: MetaAhorro?, guardar: @escaping (MetaAhorro) -> Void) {
        self.existente = existente; self.guardar = guardar
        _nombre = State(initialValue: existente?.nombre ?? "")
        _objetivo = State(initialValue: existente?.objetivo)
        _acumulado = State(initialValue: existente?.acumulado ?? 0)
        _usaFecha = State(initialValue: existente?.fechaObjetivo != nil)
        _fecha = State(initialValue: existente?.fechaObjetivo
                       ?? Calendar.current.date(byAdding: .month, value: 6, to: .now)!)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre de la meta", text: $nombre)
                TextField("Objetivo", value: $objetivo,
                          format: .currency(code: "MXN"))
                    .keyboardType(.decimalPad)
                TextField("Ya tengo ahorrado", value: $acumulado,
                          format: .currency(code: "MXN"))
                    .keyboardType(.decimalPad)
                Toggle("Definir fecha objetivo", isOn: $usaFecha)
                if usaFecha {
                    DatePicker("Fecha", selection: $fecha,
                               in: Date.now..., displayedComponents: .date)
                }
            }
            .navigationTitle(existente == nil ? "Nueva meta" : "Editar meta")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        guardar(MetaAhorro(id: existente?.id ?? UUID(), nombre: nombre,
                            objetivo: objetivo ?? 0, acumulado: acumulado ?? 0,
                            fechaObjetivo: usaFecha ? fecha : nil))
                        cerrar()
                    }.disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty
                               || (objetivo ?? 0) <= 0 || (acumulado ?? 0) < 0)
                }
            }
        }.aparienciaDeLaApp()
    }
}
