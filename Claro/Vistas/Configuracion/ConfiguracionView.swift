 //
//  ConfiguracionView.swift
//  Claro — Carpeta: Vistas/Configuracion
//
//  Seguridad, notificaciones y preferencias de la app.
//

import SwiftUI
import SwiftData

struct ConfiguracionView: View {
    @Environment(\.dismiss) private var cerrar
    @Environment(\.modelContext) private var contexto

    @AppStorage("bloqueoActivado") private var bloqueoActivado = false
    @AppStorage("notificacionesActivadas") private var notificacionesActivadas = false
    @AppStorage("mostrarMontosEnNotificaciones") private var mostrarMontosEnNotificaciones = false
    @AppStorage("importarConIA") private var importarConIA = true
    @AppStorage("apariencia") private var apariencia = Apariencia.oscuro.rawValue
    @AppStorage("modoHistoricoActivo") private var modoHistoricoActivo = false
    @AppStorage("fechaAnalisisReferencia") private var fechaAnalisisReferencia = Date.now.timeIntervalSince1970

    @State private var confirmandoBorrado = false

    @Query(filter: #Predicate<TarjetaCredito> { !$0.archivada }) private var tarjetas: [TarjetaCredito]
    @Query(filter: #Predicate<Persona> { !$0.archivada }) private var personas: [Persona]

    @AppStorage("montosOcultos") private var montosOcultos = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Bloquear con Face ID / código", isOn: $bloqueoActivado)
                    Toggle("Ocultar montos (••••)", isOn: $montosOcultos)
                    Picker("Apariencia", selection: $apariencia) {
                        ForEach(Apariencia.allCases, id: \.rawValue) { opcion in
                            Text(opcion.titulo).tag(opcion.rawValue)
                        }
                    }
                } header: {
                    Text("Seguridad y privacidad")
                } footer: {
                    Text("El bloqueo pide Face ID al abrir la app. Ocultar montos muestra •••• en toda la app (y en las notificaciones), ideal para usarla en público; también puedes alternarlo con el ojo 👁️ de Inicio.")
                }

                Section {
                    Toggle("Recordatorios de pagos", isOn: $notificacionesActivadas)
                        .onChange(of: notificacionesActivadas) { _, activadas in
                            if activadas {
                                ProgramadorDeNotificaciones.pedirPermiso { autorizado in
                                    if autorizado {
                                        ProgramadorDeNotificaciones.reprogramar(
                                            tarjetas: tarjetas, personas: personas)
                                    } else {
                                        notificacionesActivadas = false
                                    }
                                }
                            } else {
                                ProgramadorDeNotificaciones.cancelarTodas()
                            }
                        }
                    Toggle("Mostrar cantidades en la pantalla bloqueada",
                           isOn: $mostrarMontosEnNotificaciones)
                        .disabled(!notificacionesActivadas)
                } header: {
                    Text("Notificaciones")
                } footer: {
                    Text("Claro avisa cuando llega el día de corte para subir el PDF, muestra el resumen importado, recuerda los pagos a 10, 5 y 3 días y el día límite, y te recuerda cobrar las partes compartidas. Al tocar un aviso abre directamente la tarjeta, el pago o la persona correcta.")
                }

                Section {
                    Toggle("Análisis inteligente de documentos", isOn: $importarConIA)
                } header: {
                    Text("Importación de estados de cuenta")
                } footer: {
                    Text("Mejora la lectura de documentos complejos sin enviar tus estados de cuenta fuera del iPhone.")
                }

                Section {
                    Toggle("Analizar como si hoy fuera otra fecha", isOn: $modoHistoricoActivo)
                    if modoHistoricoActivo {
                        DatePicker("Fecha de referencia", selection: Binding(
                            get: { Date(timeIntervalSince1970: fechaAnalisisReferencia) },
                            set: { fechaAnalisisReferencia = $0.timeIntervalSince1970 }),
                                   displayedComponents: .date)
                    }
                } header: { Text("Análisis histórico") }
                  footer: { Text("Permite consultar tus finanzas desde una fecha anterior sin modificar movimientos ni fechas guardadas.") }

                Section {
                    NavigationLink { IngresosRecurrentesView() } label: {
                        Label("Ingresos habituales", systemImage: "calendar.badge.plus")
                    }
                } header: { Text("Planeación") }

                Section {
                    NavigationLink {
                        ICloudView()
                    } label: {
                        Label("iCloud automático", systemImage: "icloud.fill")
                    }
                    NavigationLink {
                        ElementosArchivadosView()
                    } label: {
                        Label("Elementos archivados", systemImage: "archivebox.fill")
                    }
                    NavigationLink {
                        RespaldoView()
                    } label: {
                        Label("Respaldo y restauración", systemImage: "externaldrive.fill")
                    }
                    NavigationLink {
                        HistorialImportacionesView()
                    } label: {
                        Label("Historial de importaciones", systemImage: "clock.arrow.circlepath")
                    }
                    Button(role: .destructive) {
                        confirmandoBorrado = true
                    } label: {
                        Label("Borrar todos los datos", systemImage: "trash.fill")
                    }
                } header: {
                    Text("Datos")
                } footer: {
                    Text("El respaldo privado de iCloud protege la información sin incluir los PDF originales. Borrar datos en este iPhone no borra automáticamente el respaldo remoto.")
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
                Text("Se eliminará todo tu registro financiero de este iPhone. Solo podrás recuperarlo si antes creaste un respaldo.")
            }
        }
        .aparienciaDeLaApp()
    }

    /// Borra TODO en orden seguro (hijos primero, padres después)
    /// y vuelve a sembrar las categorías de fábrica.
    private func borrarTodo() {
        try? AdministradorDatos.borrarTodo(contexto: contexto,
                                           restaurarCategorias: true)
    }

}

private struct ElementosArchivadosView: View {
    @Environment(\.modelContext) private var contexto

    @Query(filter: #Predicate<CuentaBancaria> { $0.archivada },
           sort: \CuentaBancaria.nombre) private var cuentas: [CuentaBancaria]
    @Query(filter: #Predicate<TarjetaCredito> { $0.archivada },
           sort: \TarjetaCredito.nombre) private var tarjetas: [TarjetaCredito]
    @Query(filter: #Predicate<Persona> { $0.archivada },
           sort: \Persona.nombre) private var personas: [Persona]
    @Query(filter: #Predicate<Deuda> { $0.archivada },
           sort: \Deuda.acreedor) private var deudas: [Deuda]

    private var estaVacio: Bool {
        cuentas.isEmpty && tarjetas.isEmpty && personas.isEmpty && deudas.isEmpty
    }

    var body: some View {
        List {
            if estaVacio {
                ContentUnavailableView("No hay elementos archivados",
                                       systemImage: "archivebox")
            }
            seccion("Cuentas", elementos: cuentas, nombre: \.nombre) {
                $0.archivada = false
            }
            seccion("Tarjetas", elementos: tarjetas, nombre: \.nombre) {
                $0.archivada = false
            }
            seccion("Personas", elementos: personas, nombre: \.nombre) {
                $0.archivada = false
            }
            seccion("Deudas", elementos: deudas, nombre: \.acreedor) {
                $0.archivada = false
            }
        }
        .navigationTitle("Archivados")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Tema.fondo.ignoresSafeArea())
    }

    @ViewBuilder
    private func seccion<T: PersistentModel>(
        _ titulo: String,
        elementos: [T],
        nombre: KeyPath<T, String>,
        restaurar: @escaping (T) -> Void
    ) -> some View {
        if !elementos.isEmpty {
            Section(titulo) {
                ForEach(elementos) { elemento in
                    HStack {
                        Text(elemento[keyPath: nombre])
                        Spacer()
                        Button("Restaurar") {
                            restaurar(elemento)
                            try? contexto.save()
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }
}
