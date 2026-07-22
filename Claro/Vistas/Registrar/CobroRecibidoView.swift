//
//  CobroRecibidoView.swift
//  Claro — Carpeta: Vistas/Registrar
//
//  Registrar que alguien te pagó. Doble efecto automático:
//  baja lo que te debe Y sube el saldo de la cuenta donde recibiste.
//

import SwiftUI
import SwiftData

struct CobroRecibidoView: View {
    var personaInicial: Persona? = nil

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @Query(filter: #Predicate<Persona> { !$0.archivada }, sort: \Persona.nombre) private var personas: [Persona]
    @Query(filter: #Predicate<CuentaBancaria> { !$0.archivada }, sort: \CuentaBancaria.nombre) private var cuentas: [CuentaBancaria]
    @Query(filter: #Predicate<TarjetaCredito> { !$0.archivada }) private var tarjetas: [TarjetaCredito]
    @AppStorage("notificacionesActivadas") private var notificacionesActivadas = false
    @AppStorage("respaldoICloudAutomatico") private var respaldoICloudAutomatico = true

    @State private var monto: Double?
    @State private var personaSeleccionada: Persona?
    @State private var cuentaDestino: CuentaBancaria?
    @State private var fecha: Date = .now
    @State private var detalle = ""

    init(personaInicial: Persona? = nil) {
        self.personaInicial = personaInicial
        _personaSeleccionada = State(initialValue: personaInicial)
    }

    private var puedeGuardar: Bool {
        (monto ?? 0) > 0 && personaSeleccionada != nil
    }

    private var distribucion: DistribucionCobroPersona? {
        guard let persona = personaSeleccionada, let monto, monto > 0 else {
            return nil
        }
        return MotorDePersonas.distribuirCobro(
            monto: monto, saldoPendiente: persona.saldoPendiente)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Monto recibido") {
                    TextField("0.00", value: $monto, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.bold))

                    if let p = personaSeleccionada, p.saldoPendiente > 0 {
                        Button {
                            monto = p.saldoPendiente
                        } label: {
                            Label("Usar saldo pendiente: \(p.saldoPendiente.comoDinero)",
                                  systemImage: "wand.and.stars")
                                .font(.footnote)
                        }
                    }
                }

                Section("Detalles") {
                    Picker("Quién te pagó", selection: $personaSeleccionada) {
                        Text("Selecciona…").tag(nil as Persona?)
                        ForEach(personas) { p in
                            Text(p.nombre).tag(p as Persona?)
                        }
                    }

                    Picker("Cuenta donde lo recibiste", selection: $cuentaDestino) {
                        Text("Efectivo / fuera de la app").tag(nil as CuentaBancaria?)
                        ForEach(cuentas) { c in
                            Text("\(c.banco?.nombre ?? "") · \(c.nombre)")
                                .tag(c as CuentaBancaria?)
                        }
                    }

                    DatePicker("Fecha", selection: $fecha,
                               displayedComponents: .date)

                    TextField("Descripción (opcional)", text: $detalle)
                }

                if let persona = personaSeleccionada, let distribucion {
                    Section("Cómo se registrará") {
                        if distribucion.aplicadoADeuda > 0 {
                            LabeledContent("Aplicado a lo que te debe") {
                                Text(distribucion.aplicadoADeuda.comoDinero)
                                    .foregroundStyle(Tema.positivo)
                            }
                        }
                        if distribucion.excedenteComoIngreso > 0 {
                            LabeledContent("Excedente como ingreso") {
                                Text(distribucion.excedenteComoIngreso.comoDinero)
                                    .foregroundStyle(Tema.acento)
                            }
                            Label("El depósito completo entra a tu cuenta. El excedente de \(persona.nombre) cuenta como ingreso y no crea una deuda a su favor.",
                                  systemImage: "info.circle.fill")
                                .font(.footnote)
                                .foregroundStyle(Tema.textoSecundario)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Cobro recibido")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        guardarCobro()
                    }
                    .disabled(!puedeGuardar)
                }
            }
        }
        .aparienciaDeLaApp()
    }

    private func guardarCobro() {
        guard let persona = personaSeleccionada,
              let distribucion else { return }
        let descripcion = detalle.trimmingCharacters(in: .whitespacesAndNewlines)

        if distribucion.aplicadoADeuda > 0 {
            contexto.insert(Movimiento(
                tipo: .cobroRecibido,
                monto: distribucion.aplicadoADeuda,
                fecha: fecha,
                detalle: descripcion,
                cuenta: cuentaDestino,
                persona: persona))
        }

        if distribucion.excedenteComoIngreso > 0 {
            let concepto = descripcion.isEmpty
                ? "Excedente recibido de \(persona.nombre)"
                : "\(descripcion) · excedente"
            contexto.insert(Movimiento(
                tipo: .ingreso,
                monto: distribucion.excedenteComoIngreso,
                fecha: fecha,
                detalle: concepto,
                cuenta: cuentaDestino,
                persona: persona))
        }

        try? contexto.save()
        if notificacionesActivadas {
            ProgramadorDeNotificaciones.reprogramar(tarjetas: tarjetas,
                                                     personas: personas)
        }
        if respaldoICloudAutomatico {
            Task {
                await AdministradorICloud.respaldarSiCorresponde(
                    contexto: contexto, intervaloMinimo: 0)
            }
        }
        cerrar()
    }
}
