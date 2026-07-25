//
//  ClaroFamiliaView.swift
//  Claro
//
//  Una conexión privada por persona. El propietario ve todas; cada invitado
//  solo puede abrir el vínculo que recibió.
//

import CloudKit
import SwiftData
import SwiftUI
import UIKit

struct ClaroFamiliaView: View {
    @Query(
        filter: #Predicate<Persona> { !$0.archivada },
        sort: \Persona.nombre
    ) private var personas: [Persona]

    @AppStorage("nombrePerfilClaroFamilia")
    private var nombrePerfil = ""

    @State private var propios: [String: VinculoClaroFamilia] = [:]
    @State private var compartidos: [VinculoClaroFamilia] = []
    @State private var cargando = false
    @State private var mensajeError: String?
    @State private var presentacionCompartir: PresentacionCompartirFamilia?
    @State private var reportandoEn: VinculoClaroFamilia?
    @State private var pagoParaRegistrar: PagoFamiliarParaRegistrar?

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    OrbeClaro(
                        icono: "person.2.badge.key.fill",
                        color: Tema.violeta,
                        lado: 52
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tu familia, con acceso controlado")
                            .font(.headline)
                        Text("Cada invitado ve únicamente su propio desglose.")
                            .font(.caption)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                TextField("Tu nombre", text: $nombrePerfil)
                    .textContentType(.name)
            } header: {
                Text("Tu identidad")
            } footer: {
                Text("Este nombre identifica tus actualizaciones familiares; no es un usuario ni una contraseña.")
            }

            if !personas.isEmpty {
                Section {
                    ForEach(personas) { persona in
                        filaPropietario(persona)
                    }
                } header: {
                    Text("Personas que administras")
                } footer: {
                    Text("La invitación es privada y de lectura y escritura. Invita solamente a la persona indicada en cada conexión.")
                }
            }

            if !compartidos.isEmpty {
                Section {
                    ForEach(compartidos) { vinculo in
                        NavigationLink {
                            DetalleVinculoFamiliarView(
                                vinculo: vinculo,
                                reportar: { reportandoEn = vinculo }
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(vinculo.personaNombre)
                                        .font(.headline)
                                    Spacer()
                                    Text(vinculo.saldoPendiente.comoDinero)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(
                                            vinculo.saldoPendiente > 0
                                                ? Tema.advertencia
                                                : Tema.positivo
                                        )
                                }
                                Label(
                                    "Compartido contigo",
                                    systemImage: "checkmark.icloud.fill"
                                )
                                .font(.caption)
                                .foregroundStyle(Tema.positivo)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Compartido contigo")
                }
            }

            if personas.isEmpty && compartidos.isEmpty && !cargando {
                Section {
                    ContentUnavailableView(
                        "Aún no hay conexiones",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text(
                            "Agrega personas en Claro o acepta una invitación familiar."
                        )
                    )
                }
            }

            if cargando {
                Section {
                    HStack {
                        ProgressView()
                        Text("Actualizando Claro Familia…")
                            .foregroundStyle(Tema.textoSecundario)
                    }
                }
            }

            Section {
                Label(
                    "Tus cuentas, tarjetas, estados de cuenta y conversaciones de IA nunca se comparten. Solo se publica el desglose de la persona invitada.",
                    systemImage: "lock.shield.fill"
                )
                .font(.footnote)
                .foregroundStyle(Tema.textoSecundario)
            } header: {
                Text("Privacidad")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tema.fondo.ignoresSafeArea())
        .navigationTitle("Claro Familia")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await recargar() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(cargando)
            }
        }
        .task { await recargar() }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .claroFamiliaCambio
            )
        ) { _ in
            Task { await recargar() }
        }
        .sheet(item: $presentacionCompartir) { presentacion in
            ControlCompartirICloud(
                share: presentacion.share,
                titulo: "Claro Familia · \(presentacion.personaNombre)",
                alCambiar: {
                    Task { await recargar() }
                },
                alFallar: { mensajeError = $0.localizedDescription }
            )
        }
        .sheet(item: $reportandoEn) { vinculo in
            ReportarPagoFamiliarView(
                vinculo: vinculo,
                nombreInicial: nombrePerfil
            ) {
                Task { await recargar() }
            }
        }
        .sheet(item: $pagoParaRegistrar) { pendiente in
            CobroRecibidoView(
                personaInicial: pendiente.persona,
                montoInicial: pendiente.actualizacion.monto,
                fechaInicial: pendiente.actualizacion.fecha,
                detalleInicial: pendiente.actualizacion.concepto
            ) {
                Task {
                    do {
                        try await AdministradorClaroFamilia.cambiarEstado(
                            de: pendiente.actualizacion,
                            a: .confirmada,
                            en: pendiente.vinculo
                        )
                    } catch {
                        mensajeError = "El cobro quedó registrado localmente, pero iCloud no pudo marcar el reporte como revisado. No lo registres otra vez; usa “Marcar revisado”."
                    }
                    await recargar()
                }
            }
        }
        .alert(
            "Claro Familia",
            isPresented: Binding(
                get: { mensajeError != nil },
                set: { if !$0 { mensajeError = nil } }
            )
        ) {
            Button("Entendido", role: .cancel) { }
        } message: {
            Text(mensajeError ?? "")
        }
    }

    @ViewBuilder
    private func filaPropietario(_ persona: Persona) -> some View {
        let vinculo = propios[persona.identificadorNotificaciones]
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(persona.nombre)
                        .font(.headline)
                    if let vinculo {
                        Label(
                            vinculo.participantesAceptados > 0
                                ? "Conectado"
                                : "Invitación pendiente",
                            systemImage:
                                vinculo.participantesAceptados > 0
                                ? "person.crop.circle.badge.checkmark"
                                : "envelope.badge"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            vinculo.participantesAceptados > 0
                                ? Tema.positivo
                                : Tema.advertencia
                        )
                    } else {
                        Text("Sin invitación")
                            .font(.caption)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                }
                Spacer()
                Text(persona.saldoPendiente.comoDinero)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(
                        persona.saldoPendiente > 0
                            ? Tema.advertencia
                            : Tema.positivo
                    )
            }

            if let vinculo {
                ForEach(vinculo.pagosPendientes) { actualizacion in
                    reportePendiente(
                        actualizacion,
                        vinculo: vinculo,
                        persona: persona
                    )
                }
            }

            Button {
                invitarOAdministrar(persona)
            } label: {
                Label(
                    vinculo == nil
                        ? "Preparar invitación"
                        : "Administrar acceso",
                    systemImage: vinculo == nil
                        ? "person.badge.plus"
                        : "person.2.badge.gearshape"
                )
                .font(.footnote.weight(.semibold))
            }
            .disabled(cargando)
        }
        .padding(.vertical, 5)
    }

    private func reportePendiente(
        _ actualizacion: ActualizacionFamiliar,
        vinculo: VinculoClaroFamilia,
        persona: Persona
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(Tema.acento)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pago reportado: \(actualizacion.monto.comoDinero)")
                        .font(.subheadline.weight(.semibold))
                    Text("\(actualizacion.autor) · \(actualizacion.fecha.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                }
            }
            HStack {
                Button("Registrar en Claro") {
                    pagoParaRegistrar = PagoFamiliarParaRegistrar(
                        vinculo: vinculo,
                        actualizacion: actualizacion,
                        persona: persona
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(Tema.positivo)

                Menu {
                    Button("Marcar revisado") {
                        cambiarEstado(
                            actualizacion,
                            a: .confirmada,
                            vinculo: vinculo
                        )
                    }
                    Button("Descartar reporte", role: .destructive) {
                        cambiarEstado(
                            actualizacion,
                            a: .descartada,
                            vinculo: vinculo
                        )
                    }
                } label: {
                    Text("Más")
                }
                .buttonStyle(.bordered)
            }
            .font(.caption.weight(.semibold))
        }
        .padding(10)
        .background(
            Tema.acento.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 13)
        )
    }

    private func invitarOAdministrar(_ persona: Persona) {
        cargando = true
        Task {
            do {
                let vinculo: VinculoClaroFamilia
                if let existente =
                    propios[persona.identificadorNotificaciones],
                   let share = existente.share {
                    presentacionCompartir = PresentacionCompartirFamilia(
                        share: share,
                        personaNombre: persona.nombre
                    )
                    cargando = false
                    return
                } else {
                    vinculo = try await AdministradorClaroFamilia
                        .prepararInvitacion(
                            persona: persona,
                            propietarioNombre: nombrePerfil
                        )
                }
                propios[persona.identificadorNotificaciones] = vinculo
                if let share = vinculo.share {
                    presentacionCompartir = PresentacionCompartirFamilia(
                        share: share,
                        personaNombre: persona.nombre
                    )
                }
            } catch {
                mensajeError = error.localizedDescription
            }
            cargando = false
        }
    }

    private func cambiarEstado(
        _ actualizacion: ActualizacionFamiliar,
        a estado: EstadoActualizacionFamiliar,
        vinculo: VinculoClaroFamilia
    ) {
        Task {
            do {
                try await AdministradorClaroFamilia.cambiarEstado(
                    de: actualizacion,
                    a: estado,
                    en: vinculo
                )
                await recargar()
            } catch {
                mensajeError = error.localizedDescription
            }
        }
    }

    private func recargar() async {
        guard !cargando else { return }
        cargando = true
        defer { cargando = false }

        var nuevos: [String: VinculoClaroFamilia] = [:]
        do {
            for persona in personas {
                if let vinculo = try await AdministradorClaroFamilia
                    .vinculoPropio(
                        para: persona,
                        propietarioNombre: nombrePerfil
                    ) {
                    nuevos[persona.identificadorNotificaciones] = vinculo
                }
            }
            propios = nuevos
            compartidos = try await AdministradorClaroFamilia
                .vinculosCompartidosConmigo()

            if let errorAceptacion = UserDefaults.standard.string(
                forKey: "ultimoErrorClaroFamilia"
            ) {
                mensajeError = errorAceptacion
            }
        } catch {
            // La pantalla sigue siendo utilizable sin red; conserva lo ya
            // mostrado y explica el problema sin tocar datos locales.
            mensajeError = error.localizedDescription
        }
    }
}

private struct DetalleVinculoFamiliarView: View {
    let vinculo: VinculoClaroFamilia
    let reportar: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Panel {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("SALDO COMPARTIDO")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Tema.textoSecundario)
                        Text(vinculo.saldoPendiente.comoDinero)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                vinculo.saldoPendiente > 0
                                    ? Tema.advertencia
                                    : Tema.positivo
                            )
                        Text("Actualizado \(vinculo.actualizadoEl.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Panel {
                    Text(vinculo.resumenCobro)
                        .font(.callout)
                        .foregroundStyle(Tema.textoPrincipal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }

                Button(action: reportar) {
                    Label(
                        "Reportar pago enviado",
                        systemImage: "arrow.up.circle.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(Tema.fondo)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Tema.positivo, in: Capsule())
                }
                .buttonStyle(Presionable())
            }
            .padding(16)
        }
        .background(FondoClaro())
        .navigationTitle(vinculo.personaNombre)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ReportarPagoFamiliarView: View {
    let vinculo: VinculoClaroFamilia
    let alGuardar: () -> Void

    @Environment(\.dismiss) private var cerrar
    @State private var monto: Double?
    @State private var fecha = Date.now
    @State private var concepto = ""
    @State private var autor: String
    @State private var guardando = false
    @State private var error: String?

    init(
        vinculo: VinculoClaroFamilia,
        nombreInicial: String,
        alGuardar: @escaping () -> Void
    ) {
        self.vinculo = vinculo
        self.alGuardar = alGuardar
        _autor = State(
            initialValue: nombreInicial.isEmpty
                ? vinculo.personaNombre
                : nombreInicial
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pago enviado") {
                    TextField("0.00", value: $monto, format: .number)
                        .keyboardType(.decimalPad)
                    DatePicker(
                        "Fecha",
                        selection: $fecha,
                        displayedComponents: .date
                    )
                    TextField("Referencia o nota", text: $concepto)
                }
                Section("Quién lo reporta") {
                    TextField("Nombre", text: $autor)
                }
                Section {
                    Label(
                        "Esto informa al propietario, pero no marca el pago como recibido hasta que él lo confirme.",
                        systemImage: "info.circle.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(Tema.textoSecundario)
                }
            }
            .navigationTitle("Reportar pago")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enviar") { guardar() }
                        .disabled((monto ?? 0) <= 0 || guardando)
                }
            }
        }
        .aparienciaDeLaApp()
        .alert(
            "No se pudo enviar",
            isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )
        ) {
            Button("Entendido", role: .cancel) { }
        } message: {
            Text(error ?? "")
        }
    }

    private func guardar() {
        guard let monto, monto > 0 else { return }
        guardando = true
        Task {
            do {
                try await AdministradorClaroFamilia.reportarPago(
                    en: vinculo,
                    monto: monto,
                    fecha: fecha,
                    concepto: concepto,
                    autor: autor
                )
                alGuardar()
                cerrar()
            } catch {
                self.error = error.localizedDescription
                guardando = false
            }
        }
    }
}

private struct PresentacionCompartirFamilia: Identifiable {
    let id = UUID()
    let share: CKShare
    let personaNombre: String
}

private struct PagoFamiliarParaRegistrar: Identifiable {
    var id: UUID { actualizacion.id }
    let vinculo: VinculoClaroFamilia
    let actualizacion: ActualizacionFamiliar
    let persona: Persona
}

private struct ControlCompartirICloud: UIViewControllerRepresentable {
    let share: CKShare
    let titulo: String
    let alCambiar: () -> Void
    let alFallar: (Error) -> Void

    func makeCoordinator() -> Coordinador {
        Coordinador(
            titulo: titulo,
            alCambiar: alCambiar,
            alFallar: alFallar
        )
    }

    func makeUIViewController(context: Context)
        -> UICloudSharingController {
        let controlador = UICloudSharingController(
            share: share,
            container: CKContainer.default()
        )
        controlador.delegate = context.coordinator
        controlador.availablePermissions = [
            .allowPrivate,
            .allowReadWrite
        ]
        return controlador
    }

    func updateUIViewController(
        _ uiViewController: UICloudSharingController,
        context: Context
    ) { }

    final class Coordinador: NSObject,
        UICloudSharingControllerDelegate {
        let titulo: String
        let alCambiar: () -> Void
        let alFallar: (Error) -> Void

        init(
            titulo: String,
            alCambiar: @escaping () -> Void,
            alFallar: @escaping (Error) -> Void
        ) {
            self.titulo = titulo
            self.alCambiar = alCambiar
            self.alFallar = alFallar
        }

        func itemTitle(
            for csc: UICloudSharingController
        ) -> String? {
            titulo
        }

        func cloudSharingController(
            _ csc: UICloudSharingController,
            failedToSaveShareWithError error: Error
        ) {
            alFallar(error)
        }

        func cloudSharingControllerDidSaveShare(
            _ csc: UICloudSharingController
        ) {
            alCambiar()
        }

        func cloudSharingControllerDidStopSharing(
            _ csc: UICloudSharingController
        ) {
            alCambiar()
        }
    }
}
