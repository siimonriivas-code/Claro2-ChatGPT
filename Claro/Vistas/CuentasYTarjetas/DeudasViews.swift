//
//  DeudasViews.swift
//  Claro — Carpeta: Vistas/CuentasYTarjetas
//
//  Todo lo de deudas propias (préstamos fuera de tarjetas):
//  alta, detalle con abonos, abonar, editar y eliminar.
//

import SwiftUI
import SwiftData

// MARK: - Nueva deuda

struct NuevaDeudaView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @State private var acreedor = ""
    @State private var monto: Double?
    @State private var fecha: Date = .now
    @State private var notas = ""
    @State private var tasaAnual: Double?
    @State private var cat: Double?
    @State private var plazoMeses: Int?
    @State private var mensualidad: Double?

    private var puedeGuardar: Bool {
        !acreedor.trimmingCharacters(in: .whitespaces).isEmpty
        && (monto ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("¿A quién le debes? (ej. Tía Rosa, Coppel)",
                              text: $acreedor)
                    TextField("Monto total", value: $monto, format: .number)
                        .keyboardType(.decimalPad)
                    DatePicker("Fecha", selection: $fecha,
                               displayedComponents: .date)
                    TextField("Notas (opcional)", text: $notas)
                } header: {
                    Text("Datos de la deuda")
                } footer: {
                    Text("El saldo restante se calculará solo, conforme registres abonos (Ley 1).")
                }
                Section("Costo y plazo (opcional)") {
                    TextField("Tasa anual %", value: $tasaAnual, format: .number).keyboardType(.decimalPad)
                    TextField("CAT %", value: $cat, format: .number).keyboardType(.decimalPad)
                    TextField("Plazo en meses", value: $plazoMeses, format: .number).keyboardType(.numberPad)
                    TextField("Mensualidad", value: $mensualidad, format: .number).keyboardType(.decimalPad)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Nueva deuda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        contexto.insert(Deuda(
                            acreedor: acreedor.trimmingCharacters(in: .whitespaces),
                            montoOriginal: monto ?? 0,
                            fecha: fecha,
                            notas: notas.trimmingCharacters(in: .whitespaces),
                            tasaAnual: tasaAnual, cat: cat,
                            plazoMeses: plazoMeses, mensualidad: mensualidad))
                        cerrar()
                    }
                    .disabled(!puedeGuardar)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Abonar a una deuda

struct AbonoDeudaView: View {
    var deudaInicial: Deuda? = nil

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @Query(filter: #Predicate<Deuda> { !$0.archivada }, sort: \Deuda.acreedor) private var deudas: [Deuda]
    @Query(filter: #Predicate<CuentaBancaria> { !$0.archivada }, sort: \CuentaBancaria.nombre) private var cuentas: [CuentaBancaria]

    @State private var monto: Double?
    @State private var deudaSeleccionada: Deuda?
    @State private var cuentaOrigen: CuentaBancaria?
    @State private var fecha: Date = .now
    @State private var detalle = ""

    init(deudaInicial: Deuda? = nil) {
        self.deudaInicial = deudaInicial
        _deudaSeleccionada = State(initialValue: deudaInicial)
    }

    /// Espejo estricto: no puedes abonar más de lo que hay en la cuenta.
    private var fondosInsuficientes: Bool {
        guard let cuenta = cuentaOrigen, let m = monto else { return false }
        return m > cuenta.saldoCalculado
    }

    private var puedeGuardar: Bool {
        (monto ?? 0) > 0
        && deudaSeleccionada != nil
        && cuentaOrigen != nil          // el abono DEBE salir de una cuenta
        && !fondosInsuficientes
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Monto del abono") {
                    TextField("0.00", value: $monto, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.bold))

                    if let d = deudaSeleccionada, d.saldoRestante > 0 {
                        Button {
                            monto = d.saldoRestante
                        } label: {
                            Label("Usar saldo restante: \(d.saldoRestante.comoDinero)",
                                  systemImage: "wand.and.stars")
                                .font(.footnote)
                        }
                    }
                }

                Section {
                    Picker("Deuda", selection: $deudaSeleccionada) {
                        Text("Selecciona…").tag(nil as Deuda?)
                        ForEach(deudas) { d in
                            Text("\(d.acreedor) · restan \(d.saldoRestante.comoDinero)")
                                .tag(d as Deuda?)
                        }
                    }
                    Picker("Cuenta de donde sale", selection: $cuentaOrigen) {
                        Text("Selecciona…").tag(nil as CuentaBancaria?)
                        ForEach(cuentas) { c in
                            Text("\(c.banco?.nombre ?? "") · \(c.nombre)")
                                .tag(c as CuentaBancaria?)
                        }
                    }
                    DatePicker("Fecha", selection: $fecha,
                               displayedComponents: .date)
                    TextField("Descripción (opcional)", text: $detalle)
                } header: {
                    Text("Detalles")
                } footer: {
                    Text("🪞 Espejo estricto: el abono sale de una de tus cuentas y solo si tiene fondos. Para abonos en efectivo, crea una cuenta de tipo Efectivo y aliméntala con tus ingresos.")
                }

                if fondosInsuficientes, let c = cuentaOrigen, let m = monto {
                    Section {
                        Label("Fondos insuficientes: quieres abonar \(m.comoDinero) pero \(c.nombre) solo tiene \(c.saldoCalculado.comoDinero).",
                              systemImage: "nosign")
                            .font(.footnote)
                            .foregroundStyle(Tema.urgente)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Abonar a deuda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let movimiento = Movimiento(
                            tipo: .abonoDeuda,
                            monto: monto ?? 0,
                            fecha: fecha,
                            detalle: detalle.trimmingCharacters(in: .whitespaces),
                            cuenta: cuentaOrigen,
                            deuda: deudaSeleccionada)
                        contexto.insert(movimiento)
                        cerrar()
                    }
                    .disabled(!puedeGuardar)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Detalle de una deuda

struct DeudaDetalleView: View {
    let deuda: Deuda

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @State private var mostrandoAbono = false
    @State private var mostrandoEdicion = false
    @State private var confirmandoEliminacion = false

    private var abonosOrdenados: [Movimiento] {
        deuda.abonos
            .filter { $0.cuentaParaCalculos }
            .sorted { $0.fecha > $1.fecha }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Panel {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("SALDO RESTANTE")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Tema.textoSecundario)
                            Spacer()
                            Pildora(texto: deuda.estaLiquidada ? "Liquidada" : "Activa",
                                    color: deuda.estaLiquidada ? Tema.positivo : Tema.advertencia)
                        }
                        Text(deuda.saldoRestante.comoDinero)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(deuda.estaLiquidada
                                             ? Tema.positivo : Tema.advertencia)
                        Text("De \(deuda.montoOriginal.comoDinero) has abonado \(deuda.totalAbonado.comoDinero) · desde \(deuda.fecha.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(Tema.textoSecundario)
                        if !deuda.notas.isEmpty {
                            Text(deuda.notas)
                                .font(.caption)
                                .foregroundStyle(Tema.textoSecundario)
                        }
                        if deuda.cat != nil || deuda.tasaAnual != nil || deuda.mensualidad != nil {
                            Text([deuda.cat.map { "CAT \($0.formatted())%" },
                                  deuda.tasaAnual.map { "tasa \($0.formatted())% anual" },
                                  deuda.mensualidad.map { "mensualidad \($0.comoDinero)" }]
                                .compactMap { $0 }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(Tema.textoSecundario)
                        }
                    }
                }

                if !deuda.estaLiquidada {
                    Button {
                        mostrandoAbono = true
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Registrar abono")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(Tema.positivo)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Tema.positivo.opacity(0.15),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                TituloSeccion(texto: "Abonos")
                if abonosOrdenados.isEmpty {
                    Panel {
                        Text("Aún no registras abonos a esta deuda.")
                            .font(.footnote)
                            .foregroundStyle(Tema.textoSecundario)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Panel {
                        VStack(spacing: 0) {
                            ForEach(abonosOrdenados) { abono in
                                FilaMovimiento(movimiento: abono)
                                if abono.id != abonosOrdenados.last?.id {
                                    Divider().overlay(Tema.panelElevado)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Tema.fondo.ignoresSafeArea())
        .navigationTitle(deuda.acreedor)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        mostrandoEdicion = true
                    } label: {
                        Label("Editar deuda", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) {
                        confirmandoEliminacion = true
                    } label: {
                        Label("Archivar deuda", systemImage: "archivebox")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Tema.textoSecundario)
                }
            }
        }
        .sheet(isPresented: $mostrandoAbono) {
            AbonoDeudaView(deudaInicial: deuda)
        }
        .sheet(isPresented: $mostrandoEdicion) {
            EditarDeudaView(deuda: deuda)
        }
        .confirmationDialog("¿Archivar esta deuda?",
                            isPresented: $confirmandoEliminacion,
                            titleVisibility: .visible) {
            Button("Archivar y conservar los abonos") { archivarDeuda() }
            Button("No", role: .cancel) { }
        } message: {
            Text("Dejará de aparecer para abonos nuevos, pero conservará la deuda y el efecto de todos sus pagos.")
        }
    }

    private func archivarDeuda() {
        deuda.archivada = true
        try? contexto.save()
        cerrar()
    }
}

// MARK: - Editar deuda

struct EditarDeudaView: View {
    let deuda: Deuda

    @Environment(\.dismiss) private var cerrar
    @State private var acreedor: String
    @State private var monto: Double?
    @State private var fecha: Date
    @State private var notas: String
    @State private var tasaAnual: Double?
    @State private var cat: Double?
    @State private var plazoMeses: Int?
    @State private var mensualidad: Double?

    init(deuda: Deuda) {
        self.deuda = deuda
        _acreedor = State(initialValue: deuda.acreedor)
        _monto = State(initialValue: deuda.montoOriginal)
        _fecha = State(initialValue: deuda.fecha)
        _notas = State(initialValue: deuda.notas)
        _tasaAnual = State(initialValue: deuda.tasaAnual)
        _cat = State(initialValue: deuda.cat)
        _plazoMeses = State(initialValue: deuda.plazoMeses)
        _mensualidad = State(initialValue: deuda.mensualidad)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Acreedor", text: $acreedor)
                    TextField("Monto original", value: $monto, format: .number)
                        .keyboardType(.decimalPad)
                    DatePicker("Fecha", selection: $fecha,
                               displayedComponents: .date)
                    TextField("Notas", text: $notas)
                } header: {
                    Text("Datos de la deuda")
                } footer: {
                    Text("⚠️ Cambiar el monto original recalcula el saldo restante (Ley 1).")
                }
                Section("Costo y plazo") {
                    TextField("Tasa anual %", value: $tasaAnual, format: .number).keyboardType(.decimalPad)
                    TextField("CAT %", value: $cat, format: .number).keyboardType(.decimalPad)
                    TextField("Plazo en meses", value: $plazoMeses, format: .number).keyboardType(.numberPad)
                    TextField("Mensualidad", value: $mensualidad, format: .number).keyboardType(.decimalPad)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Editar deuda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        deuda.acreedor = acreedor.trimmingCharacters(in: .whitespaces)
                        deuda.montoOriginal = (monto ?? 0).redondeadoAMoneda
                        deuda.fecha = fecha
                        deuda.notas = notas.trimmingCharacters(in: .whitespaces)
                        deuda.tasaAnual = tasaAnual; deuda.cat = cat
                        deuda.plazoMeses = plazoMeses; deuda.mensualidad = mensualidad
                        cerrar()
                    }
                    .disabled(acreedor.trimmingCharacters(in: .whitespaces).isEmpty
                              || (monto ?? 0) <= 0)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
