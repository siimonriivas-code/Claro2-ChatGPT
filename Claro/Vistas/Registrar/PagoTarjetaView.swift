//
//  PagoTarjetaView.swift
//  Claro — Carpeta: Vistas/Registrar
//  ⚠️ REEMPLAZA al existente.
//
//  Novedad (espejo estricto): si eliges una cuenta de origen, NO puedes
//  pagar más de lo que esa cuenta tiene, igual que en la vida real.
//

import SwiftUI
import SwiftData

struct PagoTarjetaView: View {
    var tarjetaInicial: TarjetaCredito? = nil

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @Query(filter: #Predicate<TarjetaCredito> { !$0.archivada }, sort: \TarjetaCredito.nombre) private var tarjetas: [TarjetaCredito]
    @Query(filter: #Predicate<CuentaBancaria> { !$0.archivada }, sort: \CuentaBancaria.nombre) private var cuentas: [CuentaBancaria]
    @Query(filter: #Predicate<Persona> { !$0.archivada }, sort: \Persona.nombre) private var personas: [Persona]
    @AppStorage("notificacionesActivadas") private var notificacionesActivadas = false
    @AppStorage("respaldoICloudAutomatico") private var respaldoICloudAutomatico = true

    @State private var monto: Double?
    @State private var tarjetaSeleccionada: TarjetaCredito?
    @State private var cuentaOrigen: CuentaBancaria?
    @State private var estadoObjetivo: EstadoDeCuenta?
    @State private var fecha: Date = .now
    @State private var detalle = ""
    @State private var errorGuardado: String?

    init(tarjetaInicial: TarjetaCredito? = nil) {
        self.tarjetaInicial = tarjetaInicial
        _tarjetaSeleccionada = State(initialValue: tarjetaInicial)
    }

    /// Espejo estricto: si eliges una cuenta, no puedes pagar más
    /// de lo que esa cuenta tiene (igual que en la vida real).
    private var fondosInsuficientes: Bool {
        guard let cuenta = cuentaOrigen, let m = monto else { return false }
        return m > cuenta.saldoCalculado
    }

    private var puedeGuardar: Bool {
        (monto ?? 0) > 0
        && tarjetaSeleccionada != nil
        && cuentaOrigen != nil          // el pago DEBE salir de una cuenta
        && !fondosInsuficientes
    }

    private var cortesPendientes: [EstadoDeCuenta] {
        (tarjetaSeleccionada?.estadosDeCuenta ?? [])
            .filter { $0.faltaPorCubrir > 0 }
            .sorted { $0.fechaCorte > $1.fechaCorte }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Monto del pago") {
                    if let vigente = tarjetaSeleccionada?.estadoDeCuentaVigente {
                        HStack {
                            Label(vigente.situacion.titulo,
                                  systemImage: vigente.faltaPorCubrir <= 0
                                  ? "checkmark.circle.fill"
                                  : "creditcard.and.123")
                                .foregroundStyle(vigente.faltaPorCubrir <= 0
                                                 ? Tema.positivo : Tema.advertencia)
                            Spacer()
                            Text(vigente.faltaPorCubrir <= 0
                                 ? "Sin pendiente"
                                 : "Faltan \(vigente.faltaPorCubrir.comoDinero)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(vigente.faltaPorCubrir <= 0
                                                 ? Tema.positivo : Tema.textoPrincipal)
                        }
                    }

                    TextField("0.00", value: $monto, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.bold))

                    // Atajos inteligentes según el corte vigente
                    if let t = tarjetaSeleccionada {
                        if let vigente = t.estadoDeCuentaVigente,
                           vigente.faltaPorCubrir > 0 {
                            Button {
                                monto = vigente.faltaPorCubrir
                            } label: {
                                Label("Usar falta por cubrir: \(vigente.faltaPorCubrir.comoDinero)",
                                      systemImage: "wand.and.stars")
                                    .font(.footnote)
                            }
                        }
                        if t.deudaCalculada > 0 {
                            Button {
                                monto = t.deudaCalculada
                            } label: {
                                Label("Usar deuda total: \(t.deudaCalculada.comoDinero)",
                                      systemImage: "creditcard.fill")
                                    .font(.footnote)
                            }
                        }
                    }
                }

                Section {
                    Picker("Tarjeta que pagas", selection: $tarjetaSeleccionada) {
                        Text("Selecciona…").tag(nil as TarjetaCredito?)
                        ForEach(tarjetas) { t in
                            Text(t.nombre).tag(t as TarjetaCredito?)
                        }
                    }

                    Picker("Cuenta de donde sale", selection: $cuentaOrigen) {
                        Text("Selecciona…").tag(nil as CuentaBancaria?)
                        ForEach(cuentas) { c in
                            Text("\(c.banco?.nombre ?? "") · \(c.nombre) · \(c.saldoCalculado.comoDinero)")
                                .tag(c as CuentaBancaria?)
                        }
                    }

                    if cortesPendientes.count > 1 {
                        Picker("Corte al que se aplica", selection: $estadoObjetivo) {
                            ForEach(cortesPendientes) { corte in
                                Text("Corte \(corte.fechaCorte.formatted(date: .abbreviated, time: .omitted)) · faltan \(corte.faltaPorCubrir.comoDinero)")
                                    .tag(corte as EstadoDeCuenta?)
                            }
                        }
                    }

                    DatePicker("Fecha del pago", selection: $fecha,
                               displayedComponents: .date)

                    TextField("Descripción (opcional)", text: $detalle)
                } header: {
                    Text("Detalles")
                } footer: {
                    Text("🪞 Todo pago sale de la cuenta real donde está el dinero. Si solo tienes una, Claro la selecciona automáticamente.")
                }

                // Espejo estricto: sin fondos no hay pago
                if fondosInsuficientes, let c = cuentaOrigen, let m = monto {
                    Section {
                        Label("Fondos insuficientes: quieres pagar \(m.comoDinero) pero \(c.nombre) solo tiene \(c.saldoCalculado.comoDinero). Claro es un espejo de tu dinero real: registra primero el ingreso, o paga menos.",
                              systemImage: "nosign")
                            .font(.footnote)
                            .foregroundStyle(Tema.urgente)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Pago de tarjeta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let movimiento = Movimiento(
                            tipo: .pagoTarjeta,
                            monto: monto ?? 0,
                            fecha: fecha,
                            detalle: detalle.trimmingCharacters(in: .whitespaces),
                            cuenta: cuentaOrigen,
                            tarjeta: tarjetaSeleccionada)
                        movimiento.fechaCorteObjetivoPago = (estadoObjetivo
                            ?? cortesPendientes.first
                            ?? tarjetaSeleccionada?.estadoDeCuentaVigente)?.fechaCorte
                        contexto.insert(movimiento)
                        do {
                            try contexto.save()
                            if notificacionesActivadas {
                                ProgramadorDeNotificaciones.reprogramar(
                                    tarjetas: tarjetas, personas: personas)
                            }
                            if respaldoICloudAutomatico {
                                Task {
                                    await AdministradorICloud.respaldarSiCorresponde(
                                        contexto: contexto, intervaloMinimo: 0)
                                }
                            }
                            cerrar()
                        } catch {
                            contexto.delete(movimiento)
                            errorGuardado = "El pago no se guardó: \(error.localizedDescription)"
                        }
                    }
                    .disabled(!puedeGuardar)
                }
            }
        }
        .aparienciaDeLaApp()
        .onAppear { seleccionarCuentaUnica() }
        .onChange(of: cuentas.count) { _, _ in seleccionarCuentaUnica() }
        .onChange(of: tarjetaSeleccionada) { _, _ in
            estadoObjetivo = cortesPendientes.first
        }
        .alert("No se pudo registrar el pago", isPresented: Binding(
            get: { errorGuardado != nil },
            set: { if !$0 { errorGuardado = nil } })) {
                Button("Entendido", role: .cancel) { }
            } message: { Text(errorGuardado ?? "") }
    }

    private func seleccionarCuentaUnica() {
        if cuentaOrigen == nil, cuentas.count == 1 {
            cuentaOrigen = cuentas[0]
        }
    }
}
