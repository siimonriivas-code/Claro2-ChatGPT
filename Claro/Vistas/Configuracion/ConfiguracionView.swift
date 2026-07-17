 //
//  ConfiguracionView.swift
//  Claro — Carpeta: Vistas/Configuracion
//
//  Seguridad, notificaciones y las Leyes de la app.
//

import SwiftUI
import SwiftData

struct ConfiguracionView: View {
    @Environment(\.dismiss) private var cerrar
    @Environment(\.modelContext) private var contexto

    @AppStorage("bloqueoActivado") private var bloqueoActivado = false
    @AppStorage("notificacionesActivadas") private var notificacionesActivadas = false
    @AppStorage("importarConIA") private var importarConIA = true

    @State private var confirmandoBorrado = false

    @Query private var tarjetas: [TarjetaCredito]
    @Query private var personas: [Persona]

    @AppStorage("montosOcultos") private var montosOcultos = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Bloquear con Face ID / código", isOn: $bloqueoActivado)
                    Toggle("Ocultar montos (••••)", isOn: $montosOcultos)
                } header: {
                    Text("Seguridad y privacidad")
                } footer: {
                    Text("El bloqueo pide Face ID al abrir la app. Ocultar montos muestra •••• en toda la app (y en las notificaciones), ideal para usarla en público; también puedes alternarlo con el ojo 👁️ de Inicio.")
                }

                Section {
                    Toggle("Recordatorios de pagos", isOn: $notificacionesActivadas)
                        .onChange(of: notificacionesActivadas) { _, activadas in
                            if activadas {
                                ProgramadorDeNotificaciones.pedirPermiso()
                                ProgramadorDeNotificaciones.reprogramar(tarjetas: tarjetas,
                                                                        personas: personas)
                            } else {
                                ProgramadorDeNotificaciones.reprogramar(tarjetas: [])
                            }
                        }
                } header: {
                    Text("Notificaciones")
                } footer: {
                    Text("Avisos específicos por tarjeta 10, 5, 3 y 1 día antes y el día del vencimiento, a las 9:00 am, con el monto real que falta. Se actualizan solos cada vez que abres la app; si ya cubriste un corte, sus avisos desaparecen.")
                }

                Section {
                    Toggle("Analizar PDFs con Apple Intelligence", isOn: $importarConIA)
                } header: {
                    Text("Importación de estados de cuenta")
                } footer: {
                    Text("Si la IA de tu iPhone lee mal el formato de tu banco, apágala: se usará el lector de reglas, afinado para bancos mexicanos (BBVA, Banamex). Puedes alternar y comparar cuando quieras.")
                }

                Section {
                    Button(role: .destructive) {
                        confirmandoBorrado = true
                    } label: {
                        Label("Borrar todos los datos", systemImage: "trash.fill")
                    }
                } header: {
                    Text("Datos")
                } footer: {
                    Text("Elimina bancos, cuentas, tarjetas, movimientos, planes a meses, personas y estados de cuenta de este iPhone. Las categorías se restauran de fábrica. Esta acción NO se puede deshacer.")
                }

                Section("Las leyes de Claro") {
                    ley("1", "Una sola fuente de verdad: los saldos se calculan desde los movimientos, nunca se escriben a mano.")
                    ley("2", "Un estado de cuenta informa cuánto debes; no es un pago.")
                    ley("3", "Una compra a MSI solo concluye cuando todas las mensualidades fueron generadas Y cubiertas.")
                    ley("4", "Todo es corregible: editar o cancelar deja huella, nunca destruye la historia.")
                    ley("5", "Privacidad primero: todo vive en tu iPhone.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Configuración")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { cerrar() }
                }
            }
            .confirmationDialog("¿Borrar TODOS los datos?",
                                isPresented: $confirmandoBorrado,
                                titleVisibility: .visible) {
                Button("Sí, borrar todo definitivamente", role: .destructive) {
                    borrarTodo()
                }
                Button("No", role: .cancel) { }
            } message: {
                Text("Se eliminará todo tu registro financiero de este iPhone. No hay respaldo ni forma de deshacerlo.")
            }
        }
        .aparienciaDeLaApp()
    }

    /// Borra TODO en orden seguro (hijos primero, padres después)
    /// y vuelve a sembrar las categorías de fábrica.
    private func borrarTodo() {
        try? contexto.delete(model: RegistroDeCambio.self)
        try? contexto.delete(model: Participacion.self)
        try? contexto.delete(model: CompraCompartida.self)
        try? contexto.delete(model: MensualidadMSI.self)
        try? contexto.delete(model: PlanMSI.self)
        try? contexto.delete(model: EstadoDeCuenta.self)
        try? contexto.delete(model: Movimiento.self)
        try? contexto.delete(model: Deuda.self)
        try? contexto.delete(model: TarjetaCredito.self)
        try? contexto.delete(model: CuentaBancaria.self)
        try? contexto.delete(model: Banco.self)
        try? contexto.delete(model: Persona.self)
        try? contexto.delete(model: Categoria.self)
        try? contexto.save()

        // Dejar la app como recién instalada: categorías de fábrica
        Sembrador.sembrarSiHaceFalta(contexto: contexto)

        // Y sin recordatorios huérfanos de tarjetas que ya no existen
        ProgramadorDeNotificaciones.reprogramar(tarjetas: [])
    }

    private func ley(_ numero: String, _ texto: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(numero)
                .font(.headline)
                .foregroundStyle(Tema.positivo)
                .frame(width: 22)
            Text(texto)
                .font(.footnote)
                .foregroundStyle(Tema.textoPrincipal)
        }
        .padding(.vertical, 2)
    }
}
