//
//  FusionarCuentaView.swift
//  Claro
//
//  Corrige cuentas duplicadas sin borrar movimientos ni alterar el saldo total.
//

import SwiftData
import SwiftUI

struct FusionarCuentaView: View {
    let cuentaOrigen: CuentaBancaria
    let alCompletar: () -> Void

    @Environment(\.dismiss) private var cerrar
    @Environment(\.modelContext) private var contexto
    @Query(sort: \CuentaBancaria.nombre) private var cuentas: [CuentaBancaria]

    @State private var destino: CuentaBancaria?
    @State private var confirmando = false
    @State private var error: String?

    private var destinosPosibles: [CuentaBancaria] {
        cuentas.filter {
            $0.persistentModelID != cuentaOrigen.persistentModelID
            && $0.banco?.persistentModelID == cuentaOrigen.banco?.persistentModelID
        }
    }

    private var saldoCombinado: Double {
        cuentaOrigen.saldoCalculado + (destino?.saldoCalculado ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    filaCuenta(cuentaOrigen)
                } header: {
                    Text("Cuenta duplicada")
                } footer: {
                    Text("Todo lo registrado aquí se moverá a la cuenta que decidas conservar.")
                }

                Section("Cuenta que conservarás") {
                    if destinosPosibles.isEmpty {
                        ContentUnavailableView(
                            "No hay otra cuenta de este banco",
                            systemImage: "wallet.pass",
                            description: Text("Primero crea la cuenta correcta y después vuelve a esta opción."))
                    } else {
                        Picker("Mover todo a", selection: $destino) {
                            Text("Selecciona…").tag(nil as CuentaBancaria?)
                            ForEach(destinosPosibles) { cuenta in
                                Text("\(cuenta.nombre) · \(cuenta.saldoCalculado.comoDinero)")
                                    .tag(cuenta as CuentaBancaria?)
                            }
                        }
                        if let destino {
                            filaCuenta(destino)
                        }
                    }
                }

                if let destino {
                    Section {
                        LabeledContent("Cuenta final", value: destino.nombre)
                        LabeledContent("Saldo combinado",
                                       value: saldoCombinado.comoDinero)
                        LabeledContent("Movimientos que se trasladan",
                                       value: "\(MotorFusionCuentas.cantidadMovimientosUnicos(cuentaOrigen))")
                    } header: {
                        Text("Resultado")
                    } footer: {
                        Text("La cuenta \(cuentaOrigen.nombre) desaparecerá después de trasladar su saldo y movimientos. No se modifica ninguna tarjeta.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Fusionar cuentas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fusionar") { confirmando = true }
                        .disabled(destino == nil)
                }
            }
        }
        .aparienciaDeLaApp()
        .confirmationDialog(
            "¿Fusionar estas cuentas?",
            isPresented: $confirmando,
            titleVisibility: .visible) {
                Button("Sí, trasladar todo", role: .destructive) {
                    fusionar()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("El saldo total quedará en \(destino?.nombre ?? "la cuenta elegida") y conservarás todos los movimientos.")
            }
        .alert("No se pudo fusionar", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } })) {
                Button("Entendido", role: .cancel) { error = nil }
            } message: {
                Text(error ?? "")
            }
    }

    private func filaCuenta(_ cuenta: CuentaBancaria) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(cuenta.nombre)
                    .font(.body.weight(.semibold))
                Text(cuenta.banco?.nombre ?? "Sin banco")
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
            }
            Spacer()
            Text(cuenta.saldoCalculado.comoDinero)
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundStyle(cuenta.saldoCalculado >= 0
                                 ? Tema.positivo : Tema.urgente)
        }
    }

    private func fusionar() {
        guard let destino else { return }
        do {
            try MotorFusionCuentas.fusionar(origen: cuentaOrigen,
                                            en: destino,
                                            contexto: contexto)
            cerrar()
            alCompletar()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
