//
//  NuevoEstadoDeCuentaView.swift
//  Claro — Carpeta: Vistas/CuentasYTarjetas
//  ⚠️ REEMPLAZA al existente.
//
//  Novedad: al registrar el corte, marcas qué mensualidades MSI incluyó
//  el banco. Generarlas NO las paga (Ley 3).
//

import SwiftUI
import SwiftData

struct NuevoEstadoDeCuentaView: View {
    let tarjeta: TarjetaCredito

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @State private var fechaCorte: Date = .now
    @State private var fechaLimitePago: Date =
        Calendar.current.date(byAdding: .day, value: 20, to: .now) ?? .now
    @State private var saldoAlCorte: Double?
    @State private var pagoNoIntereses: Double?
    @State private var pagoMinimo: Double?

    @State private var seleccionadas: Set<PersistentIdentifier> = []
    @State private var seleccionInicializada = false

    /// Planes de esta tarjeta que tienen una mensualidad por generar.
    private var planesConPendiente: [PlanMSI] {
        tarjeta.planesMSI
            .filter { $0.siguientePendienteDeGenerar != nil }
            .sorted { $0.fechaCompra < $1.fechaCompra }
    }

    private var fechasValidas: Bool { fechaLimitePago > fechaCorte }

    private var puedeGuardar: Bool {
        fechasValidas
        && (saldoAlCorte ?? -1) >= 0
        && (pagoNoIntereses ?? -1) >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Fecha de corte", selection: $fechaCorte,
                               displayedComponents: .date)
                    DatePicker("Fecha límite de pago", selection: $fechaLimitePago,
                               displayedComponents: .date)
                    if !fechasValidas {
                        Label("La fecha límite debe ser posterior al corte.",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Tema.advertencia)
                    }
                } header: {
                    Text("Fechas (cópialas de tu banco)")
                }

                Section {
                    TextField("Saldo al corte", value: $saldoAlCorte, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Pago para no generar intereses",
                              value: $pagoNoIntereses, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Pago mínimo", value: $pagoMinimo, format: .number)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Montos del estado de cuenta")
                } footer: {
                    Text("Registrar el corte no registra un pago. Los pagos se aplican únicamente cuando los captures en Claro.")
                }

                if !planesConPendiente.isEmpty {
                    Section {
                        ForEach(planesConPendiente) { plan in
                            if let mens = plan.siguientePendienteDeGenerar {
                                Toggle(isOn: bindingSeleccion(mens)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(plan.detalle) — \(mens.numero) de \(plan.numeroMeses)")
                                            .font(.subheadline)
                                        Text(mens.monto.comoDinero)
                                            .font(.caption)
                                            .foregroundStyle(Tema.textoSecundario)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Mensualidades MSI incluidas en este corte")
                    } footer: {
                        Text("Una mensualidad incluida quedará pendiente hasta que el pago correspondiente cubra este corte.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Registrar corte")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !seleccionInicializada {
                    seleccionadas = Set(planesConPendiente.compactMap {
                        $0.siguientePendienteDeGenerar?.id
                    })
                    seleccionInicializada = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }
                        .disabled(!puedeGuardar)
                }
            }
        }
        .aparienciaDeLaApp()
    }

    private func bindingSeleccion(_ mens: MensualidadMSI) -> Binding<Bool> {
        Binding(
            get: { seleccionadas.contains(mens.id) },
            set: { activo in
                if activo { seleccionadas.insert(mens.id) }
                else { seleccionadas.remove(mens.id) }
            }
        )
    }

    private func guardar() {
        let calendario = Calendar.current
        let inicioPeriodo: Date
        if let corteAnterior = tarjeta.estadosDeCuenta
            .map(\.fechaCorte)
            .filter({ $0 < fechaCorte })
            .max() {
            inicioPeriodo = calendario.date(byAdding: .day, value: 1,
                                            to: corteAnterior) ?? corteAnterior
        } else {
            inicioPeriodo = calendario.date(byAdding: .day, value: -30,
                                            to: fechaCorte) ?? fechaCorte
        }

        let estado = EstadoDeCuenta(
            fechaCorte: fechaCorte,
            fechaLimitePago: fechaLimitePago,
            inicioPeriodo: inicioPeriodo,
            finPeriodo: fechaCorte,
            pagoParaNoGenerarIntereses: pagoNoIntereses ?? 0,
            pagoMinimo: pagoMinimo ?? 0,
            saldoAlCorte: saldoAlCorte ?? 0,
            tarjeta: tarjeta)
        contexto.insert(estado)

        // Generar (que no es pagar) las mensualidades marcadas
        for plan in planesConPendiente {
            if let mens = plan.siguientePendienteDeGenerar,
               seleccionadas.contains(mens.id) {
                mens.fechaGeneracion = fechaCorte
                mens.estadoDeCuenta = estado
            }
        }

        cerrar()
    }
}
