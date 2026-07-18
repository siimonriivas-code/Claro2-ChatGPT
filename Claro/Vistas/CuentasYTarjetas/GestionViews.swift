//
//  GestionViews.swift
//  Claro — Carpeta: Vistas/CuentasYTarjetas
//
//  Los formularios para EDITAR bancos, cuentas, tarjetas y personas.
//  (La eliminación vive en cada pantalla de detalle, con confirmación.)
//

import SwiftUI
import SwiftData

// MARK: - Editar banco

struct EditarBancoView: View {
    let banco: Banco

    @Environment(\.dismiss) private var cerrar
    @State private var nombre: String
    @State private var colorHex: String

    private let colores = ["004481", "EB0029", "820AD1", "6C8CFF",
                           "4ADE9C", "F5B14C", "FF8CC8", "D9A66C"]

    init(banco: Banco) {
        self.banco = banco
        _nombre = State(initialValue: banco.nombre)
        _colorHex = State(initialValue: banco.colorHex)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos del banco") {
                    TextField("Nombre", text: $nombre)
                }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4),
                              spacing: 14) {
                        ForEach(colores, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    if colorHex == hex {
                                        Image(systemName: "checkmark")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Editar banco")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        banco.nombre = nombre.trimmingCharacters(in: .whitespaces)
                        banco.colorHex = colorHex
                        cerrar()
                    }
                    .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Editar cuenta

struct EditarCuentaView: View {
    let cuenta: CuentaBancaria

    @Environment(\.dismiss) private var cerrar
    @Query(sort: \Banco.nombre) private var bancos: [Banco]

    @State private var nombre: String
    @State private var tipo: TipoCuenta
    @State private var bancoSeleccionado: Banco?
    @State private var saldoInicial: Double?
    @State private var fecha: Date

    init(cuenta: CuentaBancaria) {
        self.cuenta = cuenta
        _nombre = State(initialValue: cuenta.nombre)
        _tipo = State(initialValue: cuenta.tipo)
        _bancoSeleccionado = State(initialValue: cuenta.banco)
        _saldoInicial = State(initialValue: cuenta.saldoInicial)
        _fecha = State(initialValue: cuenta.fechaSaldoInicial)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos de la cuenta") {
                    Picker("Banco", selection: $bancoSeleccionado) {
                        ForEach(bancos) { b in
                            Text(b.nombre).tag(b as Banco?)
                        }
                    }
                    TextField("Alias", text: $nombre)
                    Picker("Tipo", selection: $tipo) {
                        ForEach(TipoCuenta.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                }
                Section {
                    TextField("Saldo inicial", value: $saldoInicial, format: .number)
                        .keyboardType(.decimalPad)
                    DatePicker("Al día", selection: $fecha,
                               displayedComponents: .date)
                } header: {
                    Text("Punto de partida")
                } footer: {
                    Text("⚠️ Cambiar el saldo inicial recalcula el saldo actual de toda la cuenta (Ley 1). Úsalo solo para corregir el punto de partida.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Editar cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        cuenta.nombre = nombre.trimmingCharacters(in: .whitespaces)
                        cuenta.tipo = tipo
                        cuenta.banco = bancoSeleccionado
                        cuenta.saldoInicial = (saldoInicial ?? 0).redondeadoAMoneda
                        cuenta.fechaSaldoInicial = fecha
                        cerrar()
                    }
                    .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Editar tarjeta

struct EditarTarjetaView: View {
    let tarjeta: TarjetaCredito

    @Environment(\.dismiss) private var cerrar
    @Query(sort: \Banco.nombre) private var bancos: [Banco]

    @State private var nombre: String
    @State private var ultimosDigitos: String
    @State private var bancoSeleccionado: Banco?
    @State private var limiteCredito: Double?
    @State private var diaCorte: Int
    @State private var diaLimitePago: Int
    @State private var saldoInicial: Double?
    @State private var colorHex: String

    private let colores = ["004481", "EB0029", "820AD1", "6C8CFF",
                           "4ADE9C", "F5B14C", "FF8CC8", "1C2230"]

    init(tarjeta: TarjetaCredito) {
        self.tarjeta = tarjeta
        _nombre = State(initialValue: tarjeta.nombre)
        _ultimosDigitos = State(initialValue: tarjeta.ultimosDigitos)
        _bancoSeleccionado = State(initialValue: tarjeta.banco)
        _limiteCredito = State(initialValue: tarjeta.limiteCredito)
        _diaCorte = State(initialValue: tarjeta.diaCorte)
        _diaLimitePago = State(initialValue: tarjeta.diaLimitePago)
        _saldoInicial = State(initialValue: tarjeta.saldoInicial)
        _colorHex = State(initialValue: tarjeta.colorHex)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos de la tarjeta") {
                    Picker("Banco", selection: $bancoSeleccionado) {
                        ForEach(bancos) { b in
                            Text(b.nombre).tag(b as Banco?)
                        }
                    }
                    TextField("Alias", text: $nombre)
                    TextField("Últimos 4 dígitos", text: $ultimosDigitos)
                        .keyboardType(.numberPad)
                    TextField("Límite de crédito", value: $limiteCredito, format: .number)
                        .keyboardType(.decimalPad)
                }
                Section("Calendario") {
                    Picker("Día de corte", selection: $diaCorte) {
                        ForEach(1...31, id: \.self) { Text("Día \($0)").tag($0) }
                    }
                    Picker("Día límite de pago", selection: $diaLimitePago) {
                        ForEach(1...31, id: \.self) { Text("Día \($0)").tag($0) }
                    }
                }
                Section {
                    TextField("Deuda inicial", value: $saldoInicial, format: .number)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Punto de partida")
                } footer: {
                    Text("⚠️ Cambiar la deuda inicial recalcula la deuda actual de la tarjeta (Ley 1).")
                }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4),
                              spacing: 14) {
                        ForEach(colores, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    if colorHex == hex {
                                        Image(systemName: "checkmark")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Editar tarjeta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        tarjeta.nombre = nombre.trimmingCharacters(in: .whitespaces)
                        tarjeta.ultimosDigitos = ultimosDigitos
                        tarjeta.banco = bancoSeleccionado
                        tarjeta.limiteCredito = (limiteCredito ?? 0).redondeadoAMoneda
                        tarjeta.diaCorte = diaCorte
                        tarjeta.diaLimitePago = diaLimitePago
                        tarjeta.saldoInicial = (saldoInicial ?? 0).redondeadoAMoneda
                        tarjeta.colorHex = colorHex
                        cerrar()
                    }
                    .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Editar persona

struct EditarPersonaView: View {
    let persona: Persona

    @Environment(\.dismiss) private var cerrar
    @State private var nombre: String
    @State private var colorHex: String

    private let colores = ["004481", "EB0029", "820AD1", "6C8CFF",
                           "4ADE9C", "F5B14C", "FF8CC8", "D9A66C"]

    init(persona: Persona) {
        self.persona = persona
        _nombre = State(initialValue: persona.nombre)
        _colorHex = State(initialValue: persona.colorHex)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos") {
                    TextField("Nombre", text: $nombre)
                }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4),
                              spacing: 14) {
                        ForEach(colores, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    if colorHex == hex {
                                        Image(systemName: "checkmark")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Editar persona")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        persona.nombre = nombre.trimmingCharacters(in: .whitespaces)
                        persona.colorHex = colorHex
                        cerrar()
                    }
                    .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
