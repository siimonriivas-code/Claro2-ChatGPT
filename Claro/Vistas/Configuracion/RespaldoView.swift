//
//  RespaldoView.swift
//  Claro
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension UTType {
    static let respaldoClaro = UTType(exportedAs: "com.simonrivas.claro.respaldo",
                                      conformingTo: .json)
}

struct DocumentoRespaldoClaro: FileDocument {
    static var readableContentTypes: [UTType] { [.respaldoClaro, .json] }
    let datos: Data

    init(datos: Data) { self.datos = datos }

    init(configuration: ReadConfiguration) throws {
        guard let datos = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.datos = datos
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: datos)
    }
}

struct RespaldoView: View {
    @Environment(\.modelContext) private var contexto

    @State private var exportando = false
    @State private var importando = false
    @State private var documento: DocumentoRespaldoClaro?
    @State private var respaldoPendiente: RespaldoClaro?
    @State private var puntosRecuperacion: [PuntoRecuperacionClaro] = []
    @State private var puntoPendiente: PuntoRecuperacionClaro?
    @State private var mensaje: String?
    @State private var esError = false

    var body: some View {
        Form {
            Section {
                Button {
                    crearRespaldo()
                } label: {
                    Label("Crear respaldo", systemImage: "square.and.arrow.up")
                }

                Button {
                    importando = true
                } label: {
                    Label("Restaurar respaldo", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Tus datos")
            } footer: {
                Text("Incluye bancos, cuentas, tarjetas, movimientos, personas, MSI, deudas, categorías y preferencias. Los estados de cuenta PDF no se copian.")
            }

            Section {
                if puntosRecuperacion.isEmpty {
                    Text("Los puntos de recuperación aparecerán aquí antes de importaciones, pagos y otros cambios importantes.")
                        .font(.footnote)
                        .foregroundStyle(Tema.textoSecundario)
                } else {
                    ForEach(puntosRecuperacion) { punto in
                        Button {
                            puntoPendiente = punto
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(Tema.positivo)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(punto.motivo)
                                        .foregroundStyle(Tema.textoPrincipal)
                                        .lineLimit(2)
                                    Text("\(punto.creadoEl.formatted(date: .abbreviated, time: .shortened)) · \(punto.totalRegistros) registros")
                                        .font(.caption)
                                        .foregroundStyle(Tema.textoSecundario)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Tema.textoSecundario)
                            }
                        }
                    }
                }
            } header: {
                Text("Recuperación automática")
            } footer: {
                Text("Claro conserva hasta 12 puntos cifrados dentro de este iPhone. Restaurar siempre crea primero una copia del estado actual.")
            }

            Section {
                Label("El archivo queda donde tú elijas: iCloud Drive, En mi iPhone o tu Mac.",
                      systemImage: "lock.shield.fill")
                    .font(.footnote)
                    .foregroundStyle(Tema.textoSecundario)
                Label("Para restaurar, la app muestra el contenido antes de reemplazar los datos actuales.",
                      systemImage: "checkmark.shield.fill")
                    .font(.footnote)
                    .foregroundStyle(Tema.textoSecundario)
            } header: {
                Text("Privacidad")
            }

            if let mensaje {
                Section {
                    Label(mensaje, systemImage: esError
                          ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(esError ? Tema.urgente : Tema.positivo)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tema.fondo.ignoresSafeArea())
        .navigationTitle("Respaldo")
        .onAppear { cargarPuntos() }
        .fileExporter(isPresented: $exportando,
                      document: documento,
                      contentType: .respaldoClaro,
                      defaultFilename: nombreRespaldo) { resultado in
            if case .failure = resultado {
                mostrarError("No se pudo guardar el archivo de respaldo.")
            }
            documento = nil
        }
        .fileImporter(isPresented: $importando,
                      allowedContentTypes: [.respaldoClaro, .json]) { resultado in
            leer(resultado)
        }
        .confirmationDialog("¿Restaurar este respaldo?",
                            isPresented: Binding(
                                get: { respaldoPendiente != nil },
                                set: { if !$0 { respaldoPendiente = nil } }
                            ),
                            titleVisibility: .visible,
                            presenting: respaldoPendiente) { respaldo in
            Button("Restaurar y reemplazar datos", role: .destructive) {
                restaurar(respaldo)
            }
            Button("Cancelar", role: .cancel) { respaldoPendiente = nil }
        } message: { respaldo in
            Text("Respaldo del \(respaldo.creadoEl.formatted(date: .abbreviated, time: .shortened)), con \(respaldo.totalRegistros) registros. Se reemplazarán los datos actuales de Claro.")
        }
        .confirmationDialog("¿Volver a este punto?",
                            isPresented: Binding(
                                get: { puntoPendiente != nil },
                                set: { if !$0 { puntoPendiente = nil } }
                            ),
                            titleVisibility: .visible,
                            presenting: puntoPendiente) { punto in
            Button("Restaurar este punto", role: .destructive) {
                restaurar(punto)
            }
            Button("Cancelar", role: .cancel) { puntoPendiente = nil }
        } message: { punto in
            Text("\(punto.motivo), guardado el \(punto.creadoEl.formatted(date: .abbreviated, time: .shortened)), con \(punto.totalRegistros) registros.")
        }
    }

    private var nombreRespaldo: String {
        let formato = DateFormatter()
        formato.dateFormat = "yyyy-MM-dd"
        return "Claro-Respaldo-\(formato.string(from: .now))"
    }

    private func crearRespaldo() {
        do {
            let respaldo = try AdministradorRespaldos.crear(contexto: contexto)
            documento = DocumentoRespaldoClaro(
                datos: try AdministradorRespaldos.codificar(respaldo))
            exportando = true
            mensaje = nil
        } catch {
            mostrarError("No se pudo preparar el respaldo. Tus datos no cambiaron.")
        }
    }

    private func leer(_ resultado: Result<URL, Error>) {
        guard case .success(let url) = resultado else {
            mostrarError("No se pudo abrir el archivo seleccionado.")
            return
        }
        let acceso = url.startAccessingSecurityScopedResource()
        defer { if acceso { url.stopAccessingSecurityScopedResource() } }
        do {
            let datos = try Data(contentsOf: url)
            respaldoPendiente = try AdministradorRespaldos.decodificar(datos)
            mensaje = nil
        } catch {
            mostrarError(error.localizedDescription)
        }
    }

    private func restaurar(_ respaldo: RespaldoClaro) {
        defer { respaldoPendiente = nil }
        do {
            try CoordinadorOperacionesClaro.prepararCambioCritico(
                contexto: contexto,
                motivo: "Antes de restaurar un respaldo manual"
            )
            try AdministradorRespaldos.restaurar(respaldo, contexto: contexto)
            CoordinadorOperacionesClaro.actualizarServicios(contexto: contexto)
            cargarPuntos()
            mensaje = "Respaldo restaurado correctamente."
            esError = false
        } catch {
            contexto.rollback()
            mostrarError("No se pudo restaurar. Se conservaron los datos anteriores.")
        }
    }

    private func restaurar(_ punto: PuntoRecuperacionClaro) {
        defer { puntoPendiente = nil }
        do {
            try CoordinadorOperacionesClaro.prepararCambioCritico(
                contexto: contexto,
                motivo: "Antes de volver a un punto de recuperación"
            )
            let respaldo = try AdministradorProteccionDatos.cargar(punto)
            try AdministradorRespaldos.restaurar(respaldo, contexto: contexto)
            CoordinadorOperacionesClaro.actualizarServicios(contexto: contexto)
            cargarPuntos()
            mensaje = "Punto de recuperación restaurado correctamente."
            esError = false
        } catch {
            contexto.rollback()
            mostrarError("No se pudo restaurar. Se conservaron los datos anteriores.")
        }
    }

    private func cargarPuntos() {
        do {
            puntosRecuperacion = try AdministradorProteccionDatos.listarPuntos()
        } catch {
            puntosRecuperacion = []
            mostrarError("No se pudo consultar el historial de recuperación.")
        }
    }

    private func mostrarError(_ texto: String) {
        mensaje = texto
        esError = true
    }
}
