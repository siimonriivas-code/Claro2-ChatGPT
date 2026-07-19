import SwiftData
import SwiftUI

struct IngresosRecurrentesView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \IngresoRecurrente.nombre) private var ingresos: [IngresoRecurrente]
    @Query(sort: \CuentaBancaria.nombre) private var cuentas: [CuentaBancaria]
    @State private var mostrandoNuevo = false

    var body: some View {
        List {
            Section {
                if ingresos.isEmpty {
                    ContentUnavailableView("Sin ingresos habituales",
                                           systemImage: "calendar.badge.plus",
                                           description: Text("Agrega pensión y nómina; ambas pueden llegar a la misma cuenta BBVA."))
                } else {
                    ForEach(ingresos) { ingreso in
                        NavigationLink {
                            DetalleIngresoRecurrenteView(ingreso: ingreso)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(ingreso.nombre).font(.headline)
                                    Spacer()
                                    Text(ingreso.montoEsperado.comoDinero)
                                }
                                Text("Días \(ingreso.diaInicial)–\(ingreso.diaFinal) · \(ingreso.cuenta?.nombre ?? "sin cuenta")")
                                    .font(.caption).foregroundStyle(Tema.textoSecundario)
                            }
                        }
                    }
                }
            } footer: {
                Text("Un ingreso es una fuente de dinero, no una cuenta. Nómina y pensión se suman en la cuenta de débito donde realmente fueron depositadas.")
            }
        }
        .navigationTitle("Ingresos habituales")
        .toolbar {
            Button { mostrandoNuevo = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $mostrandoNuevo) {
            EditarIngresoRecurrenteView(cuentas: cuentas)
        }
    }
}

private struct DetalleIngresoRecurrenteView: View {
    let ingreso: IngresoRecurrente
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @State private var mostrandoEdicion = false
    @State private var mostrandoRecepcion = false
    @State private var confirmarEliminar = false

    private var ocurrenciaActual: OcurrenciaIngresoRecurrente? {
        let inicio = Calendar.current.dateInterval(of: .month, for: .now)?.start
        return ingreso.ocurrencias.first { Calendar.current.isDate($0.mes, inSameDayAs: inicio ?? .now) }
    }

    var body: some View {
        Form {
            Section("Este mes") {
                LabeledContent("Estado", value: estadoActual.rawValue)
                if let ocurrenciaActual, let fecha = ocurrenciaActual.fechaRecibida {
                    LabeledContent("Recibido", value: fecha.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Monto", value: ocurrenciaActual.montoRecibido.comoDinero)
                } else {
                    Button("Registrar que ya llegó") { mostrandoRecepcion = true }
                }
            }
            Section("Configuración") {
                LabeledContent("Monto esperado", value: ingreso.montoEsperado.comoDinero)
                LabeledContent("Ventana", value: "Días \(ingreso.diaInicial) a \(ingreso.diaFinal)")
                LabeledContent("Cuenta destino", value: ingreso.cuenta?.nombre ?? "Sin cuenta")
                Toggle("Activo", isOn: Binding(get: { ingreso.activo }, set: { ingreso.activo = $0 }))
            }
        }
        .navigationTitle(ingreso.nombre)
        .toolbar {
            Menu {
                Button("Editar", systemImage: "pencil") { mostrandoEdicion = true }
                Button("Eliminar", systemImage: "trash", role: .destructive) { confirmarEliminar = true }
            } label: { Image(systemName: "ellipsis.circle") }
        }
        .sheet(isPresented: $mostrandoEdicion) {
            EditarIngresoRecurrenteView(cuentas: [], ingreso: ingreso)
        }
        .sheet(isPresented: $mostrandoRecepcion) {
            RecibirIngresoRecurrenteView(ingreso: ingreso)
        }
        .confirmationDialog("¿Eliminar este ingreso habitual?", isPresented: $confirmarEliminar) {
            Button("Eliminar", role: .destructive) { contexto.delete(ingreso); cerrar() }
        }
    }

    private var estadoActual: EstadoIngresoRecurrente {
        if let ocurrenciaActual { return ocurrenciaActual.estado }
        return Calendar.current.component(.day, from: .now) > ingreso.diaFinal ? .retrasado : .esperado
    }
}

private struct EditarIngresoRecurrenteView: View {
    let cuentas: [CuentaBancaria]
    var ingreso: IngresoRecurrente? = nil
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @Query(sort: \CuentaBancaria.nombre) private var cuentasDisponibles: [CuentaBancaria]
    @State private var nombre = ""
    @State private var monto: Double?
    @State private var diaInicial = 1
    @State private var diaFinal = 3
    @State private var cuenta: CuentaBancaria?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre (ej. Nómina CIAPACOV)", text: $nombre)
                TextField("Monto esperado", value: $monto, format: .number).keyboardType(.decimalPad)
                Stepper("Puede llegar desde el día \(diaInicial)", value: $diaInicial, in: 1...28)
                Stepper("Hasta el día \(diaFinal)", value: $diaFinal, in: diaInicial...28)
                Picker("Cuenta donde entra", selection: $cuenta) {
                    Text("Selecciona…").tag(nil as CuentaBancaria?)
                    ForEach(cuentasDisponibles) { Text($0.nombre).tag($0 as CuentaBancaria?) }
                }
            }
            .navigationTitle(ingreso == nil ? "Nuevo ingreso" : "Editar ingreso")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }
                        .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty || (monto ?? 0) <= 0 || cuenta == nil)
                }
            }
            .onAppear {
                guard let ingreso else { return }
                nombre = ingreso.nombre; monto = ingreso.montoEsperado
                diaInicial = ingreso.diaInicial; diaFinal = ingreso.diaFinal; cuenta = ingreso.cuenta
            }
        }
    }
    private func guardar() {
        if let ingreso {
            ingreso.nombre = nombre; ingreso.montoEsperado = (monto ?? 0).redondeadoAMoneda
            ingreso.diaInicial = diaInicial; ingreso.diaFinal = diaFinal; ingreso.cuenta = cuenta
        } else {
            contexto.insert(IngresoRecurrente(nombre: nombre, montoEsperado: monto ?? 0,
                                               diaInicial: diaInicial, diaFinal: diaFinal, cuenta: cuenta))
        }
        cerrar()
    }
}

private struct RecibirIngresoRecurrenteView: View {
    let ingreso: IngresoRecurrente
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @State private var monto: Double?
    @State private var fecha = Date.now
    var body: some View {
        NavigationStack {
            Form {
                TextField("Monto recibido", value: $monto, format: .number).keyboardType(.decimalPad)
                DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
                LabeledContent("Entrará a", value: ingreso.cuenta?.nombre ?? "Sin cuenta")
            }
            .navigationTitle("Registrar depósito")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }.disabled((monto ?? 0) <= 0 || ingreso.cuenta == nil)
                }
            }
            .onAppear { monto = ingreso.montoEsperado }
        }
    }
    private func guardar() {
        let movimiento = Movimiento(tipo: .ingreso, monto: monto ?? 0, fecha: fecha,
                                    detalle: ingreso.nombre, cuenta: ingreso.cuenta)
        contexto.insert(movimiento)
        let ocurrencia = OcurrenciaIngresoRecurrente(mes: fecha, estado: .recibido,
                                                     montoRecibido: monto ?? 0, fechaRecibida: fecha,
                                                     ingreso: ingreso, movimiento: movimiento)
        contexto.insert(ocurrencia)
        cerrar()
    }
}
