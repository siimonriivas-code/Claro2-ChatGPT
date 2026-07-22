import SwiftUI
import SwiftData

struct GastosCompartidosView: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \GrupoGastosCompartidos.fecha, order: .reverse)
    private var grupos: [GrupoGastosCompartidos]
    @State private var mostrandoNuevoGrupo = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Panel {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.title2)
                            .foregroundStyle(Tema.acento)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Un espacio independiente")
                                .font(.headline)
                                .foregroundStyle(Tema.textoPrincipal)
                            Text("Aquí nada modifica tus tarjetas, cuentas ni análisis financieros.")
                                .font(.caption)
                                .foregroundStyle(Tema.textoSecundario)
                        }
                    }
                }

                if grupos.isEmpty {
                    Panel {
                        VStack(spacing: 10) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Tema.acento)
                            Text("Crea tu primer grupo o salida")
                                .font(.headline)
                            Text("Ejemplo: Cine con amigos, viaje o cena. Usarás las personas que ya existen en Claro.")
                                .font(.footnote)
                                .foregroundStyle(Tema.textoSecundario)
                                .multilineTextAlignment(.center)
                            Button("Crear salida") { mostrandoNuevoGrupo = true }
                                .buttonStyle(.borderedProminent)
                                .tint(Tema.acento)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    TituloSeccion(texto: "Salidas y grupos")
                    ForEach(grupos) { grupo in
                        NavigationLink {
                            GrupoGastosDetalleView(grupo: grupo)
                        } label: {
                            fila(grupo)
                        }
                        .buttonStyle(Presionable())
                    }
                }
            }
            .padding(16)
        }
        .background(Tema.fondo.ignoresSafeArea())
        .navigationTitle("Gastos entre amigos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { mostrandoNuevoGrupo = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $mostrandoNuevoGrupo) {
            NuevoGrupoGastosView()
        }
    }

    private func fila(_ grupo: GrupoGastosCompartidos) -> some View {
        let deudas = MotorGastosCompartidos.deudasSimplificadas(de: grupo)
        return Panel {
            HStack(spacing: 12) {
                Image(systemName: "person.3.sequence.fill")
                    .font(.title2)
                    .foregroundStyle(Tema.acento)
                    .frame(width: 42, height: 42)
                    .background(Tema.acento.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(grupo.nombre)
                        .font(.headline)
                        .foregroundStyle(Tema.textoPrincipal)
                    Text("\(grupo.gastos.count) gasto\(grupo.gastos.count == 1 ? "" : "s") · \(deudas.isEmpty ? "todo saldado" : "\(deudas.count) pago(s) para saldar")")
                        .font(.caption)
                        .foregroundStyle(deudas.isEmpty ? Tema.positivo : Tema.textoSecundario)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
            }
        }
    }
}

private struct NuevoGrupoGastosView: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @State private var nombre = ""
    @State private var fecha = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section("Nueva salida o grupo") {
                    TextField("Ej. Cine con amigos", text: $nombre)
                    DatePicker("Fecha", selection: $fecha,
                               displayedComponents: .date)
                }
            }
            .navigationTitle("Crear grupo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        contexto.insert(GrupoGastosCompartidos(
                            nombre: nombre.trimmingCharacters(in: .whitespacesAndNewlines),
                            fecha: fecha))
                        try? contexto.save()
                        cerrar()
                    }
                    .disabled(nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .aparienciaDeLaApp()
    }
}

private struct GrupoGastosDetalleView: View {
    let grupo: GrupoGastosCompartidos
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @State private var mostrandoGasto = false
    @State private var mostrandoLiquidacion = false
    @State private var confirmandoEliminar = false

    private var deudas: [DeudaGastoSimplificada] {
        MotorGastosCompartidos.deudasSimplificadas(de: grupo)
    }

    private var gastosOrdenados: [GastoCompartidoIndependiente] {
        grupo.gastos.sorted { $0.fecha > $1.fecha }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("RESUMEN NETO")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Tema.textoSecundario)
                        if deudas.isEmpty {
                            Label("Todos están al corriente", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(Tema.positivo)
                        } else {
                            ForEach(deudas) { deuda in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(deuda.deudor)
                                        .fontWeight(.semibold)
                                    Text("debe")
                                        .foregroundStyle(Tema.textoSecundario)
                                    Text(deuda.monto.comoDinero)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Tema.advertencia)
                                    Text("a \(deuda.acreedor)")
                                    Spacer(minLength: 0)
                                }
                                .font(.subheadline)
                                .foregroundStyle(Tema.textoPrincipal)
                            }
                        }
                    }
                }

                Button {
                    mostrandoGasto = true
                } label: {
                    Label("Agregar gasto", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(Tema.fondo)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Tema.acento, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(Presionable())

                Button {
                    mostrandoLiquidacion = true
                } label: {
                    Label("Registrar pago entre participantes",
                          systemImage: "arrow.left.arrow.right.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.bordered)
                .tint(Tema.positivo)

                TituloSeccion(texto: "Gastos")
                if gastosOrdenados.isEmpty {
                    Panel {
                        Text("Todavía no hay gastos en esta salida.")
                            .font(.footnote)
                            .foregroundStyle(Tema.textoSecundario)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    ForEach(gastosOrdenados) { gasto in
                        Panel {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(gasto.concepto)
                                        .font(.headline)
                                    Spacer()
                                    Text(gasto.monto.comoDinero)
                                        .font(.headline)
                                }
                                Text("Pagó \(gasto.nombrePagador) · \(gasto.fecha.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(Tema.textoSecundario)
                                Text("Dividido entre: \(gasto.partes.map(\.nombreParticipante).joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(Tema.textoSecundario)
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                contexto.delete(gasto)
                                try? contexto.save()
                            } label: {
                                Label("Eliminar gasto", systemImage: "trash")
                            }
                        }
                    }
                }

                if !grupo.liquidaciones.isEmpty {
                    TituloSeccion(texto: "Pagos entre participantes")
                    ForEach(grupo.liquidaciones.sorted { $0.fecha > $1.fecha }) { pago in
                        Panel {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(pago.nombrePagador) pagó a \(pago.nombreReceptor)")
                                        .font(.subheadline.weight(.semibold))
                                    Text(pago.fecha.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption).foregroundStyle(Tema.textoSecundario)
                                }
                                Spacer()
                                Text(pago.monto.comoDinero).fontWeight(.bold)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Tema.fondo.ignoresSafeArea())
        .navigationTitle(grupo.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) { confirmandoEliminar = true } label: {
                        Label("Eliminar grupo", systemImage: "trash")
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $mostrandoGasto) {
            NuevoGastoCompartidoView(grupo: grupo)
        }
        .sheet(isPresented: $mostrandoLiquidacion) {
            NuevaLiquidacionGastoView(grupo: grupo)
        }
        .confirmationDialog("¿Eliminar \(grupo.nombre)?",
                            isPresented: $confirmandoEliminar) {
            Button("Eliminar grupo y sus gastos", role: .destructive) {
                contexto.delete(grupo)
                try? contexto.save()
                cerrar()
            }
            Button("Cancelar", role: .cancel) { }
        }
    }
}

private struct NuevaLiquidacionGastoView: View {
    let grupo: GrupoGastosCompartidos
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @Query(filter: #Predicate<Persona> { !$0.archivada }, sort: \Persona.nombre)
    private var personas: [Persona]
    @State private var monto: Double?
    @State private var fecha = Date.now
    @State private var pagadorEsUsuario = true
    @State private var receptorEsUsuario = false
    @State private var pagador: Persona?
    @State private var receptor: Persona?

    private var valido: Bool {
        guard (monto ?? 0) > 0 else { return false }
        if !pagadorEsUsuario && pagador == nil { return false }
        if !receptorEsUsuario && receptor == nil { return false }
        if pagadorEsUsuario && receptorEsUsuario { return false }
        if !pagadorEsUsuario && !receptorEsUsuario && pagador === receptor { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pago realizado") {
                    TextField("Monto", value: $monto, format: .number)
                        .keyboardType(.decimalPad)
                    DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
                }
                Section("Quién pagó") {
                    Toggle("Fui yo", isOn: $pagadorEsUsuario)
                    if !pagadorEsUsuario {
                        Picker("Persona", selection: $pagador) {
                            Text("Selecciona…").tag(nil as Persona?)
                            ForEach(personas) { Text($0.nombre).tag($0 as Persona?) }
                        }
                    }
                }
                Section("Quién recibió") {
                    Toggle("Fui yo", isOn: $receptorEsUsuario)
                    if !receptorEsUsuario {
                        Picker("Persona", selection: $receptor) {
                            Text("Selecciona…").tag(nil as Persona?)
                            ForEach(personas) { Text($0.nombre).tag($0 as Persona?) }
                        }
                    }
                }
            }
            .navigationTitle("Registrar pago")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }.disabled(!valido)
                }
            }
        }.aparienciaDeLaApp()
    }

    private func guardar() {
        contexto.insert(LiquidacionGastoIndependiente(
            monto: monto ?? 0, fecha: fecha,
            pagadorEsUsuario: pagadorEsUsuario,
            pagador: pagadorEsUsuario ? nil : pagador,
            pagadorNombreGuardado: pagadorEsUsuario ? "Tú" : (pagador?.nombre ?? "Persona"),
            receptorEsUsuario: receptorEsUsuario,
            receptor: receptorEsUsuario ? nil : receptor,
            receptorNombreGuardado: receptorEsUsuario ? "Tú" : (receptor?.nombre ?? "Persona"),
            grupo: grupo))
        try? contexto.save(); cerrar()
    }
}

private struct NuevoGastoCompartidoView: View {
    let grupo: GrupoGastosCompartidos
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @Query(filter: #Predicate<Persona> { !$0.archivada }, sort: \Persona.nombre) private var personas: [Persona]

    @State private var concepto = ""
    @State private var monto: Double?
    @State private var fecha = Date.now
    @State private var pagador: Persona?
    @State private var pagueYo = true
    @State private var participaUsuario = true
    @State private var participantes: Set<PersistentIdentifier> = []
    @State private var modoDivision: ModoDivisionGasto = .iguales
    @State private var parteUsuario: Double?
    @State private var partesPersonalizadas: [PersistentIdentifier: Double] = [:]

    private var cantidadParticipantes: Int {
        (participaUsuario ? 1 : 0) + participantes.count
    }

    private var puedeGuardar: Bool {
        !concepto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (monto ?? 0) > 0
            && cantidadParticipantes > 0
            && (pagueYo || pagador != nil)
            && divisionValida
    }

    private var totalCapturado: Double {
        let usuario = participaUsuario ? (parteUsuario ?? 0) : 0
        return participantes.reduce(usuario) {
            $0 + (partesPersonalizadas[$1] ?? 0)
        }
    }

    private var divisionValida: Bool {
        guard let monto, cantidadParticipantes > 0 else { return false }
        switch modoDivision {
        case .iguales: return true
        case .montos: return abs(totalCapturado - monto) < 0.01
        case .porcentajes: return abs(totalCapturado - 100) < 0.01
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Gasto") {
                    TextField("Concepto", text: $concepto)
                    TextField("0.00", value: $monto, format: .number)
                        .keyboardType(.decimalPad)
                    DatePicker("Fecha", selection: $fecha,
                               displayedComponents: .date)
                }

                Section("Quién pagó") {
                    Toggle("Pagué yo", isOn: $pagueYo)
                    if !pagueYo {
                        Picker("Pagó", selection: $pagador) {
                            Text("Selecciona…").tag(nil as Persona?)
                            ForEach(personas) { persona in
                                Text(persona.nombre).tag(persona as Persona?)
                            }
                        }
                    }
                }

                Section("Entre quiénes se divide") {
                    Picker("Forma", selection: $modoDivision) {
                        ForEach(ModoDivisionGasto.allCases) { modo in
                            Text(modo.rawValue).tag(modo)
                        }
                    }
                    Toggle("Yo", isOn: $participaUsuario)
                    ForEach(personas) { persona in
                        Toggle(persona.nombre, isOn: Binding(
                            get: { participantes.contains(persona.id) },
                            set: { activo in
                                if activo { participantes.insert(persona.id) }
                                else { participantes.remove(persona.id) }
                            }))
                    }
                }


                if modoDivision != .iguales && cantidadParticipantes > 0 {
                    Section(modoDivision == .montos
                            ? "Monto de cada persona" : "Porcentaje de cada persona") {
                        if participaUsuario {
                            TextField(modoDivision == .montos ? "Mi monto" : "Mi porcentaje",
                                      value: $parteUsuario, format: .number)
                                .keyboardType(.decimalPad)
                        }
                        ForEach(personas.filter { participantes.contains($0.id) }) { persona in
                            TextField(modoDivision == .montos
                                      ? "Monto de \(persona.nombre)"
                                      : "Porcentaje de \(persona.nombre)",
                                      value: Binding(
                                        get: { partesPersonalizadas[persona.id] },
                                        set: { partesPersonalizadas[persona.id] = $0 }),
                                      format: .number)
                                .keyboardType(.decimalPad)
                        }
                        LabeledContent(modoDivision == .montos ? "Asignado" : "Asignado") {
                            Text(modoDivision == .montos
                                 ? totalCapturado.comoDinero
                                 : "\(totalCapturado.formatted(.number.precision(.fractionLength(0...2))))%")
                                .foregroundStyle(divisionValida ? Tema.positivo : Tema.advertencia)
                        }
                    }
                }

                if let monto, cantidadParticipantes > 0, modoDivision == .iguales {
                    Section("Vista previa") {
                        LabeledContent("Por persona") {
                            Text((monto / Double(cantidadParticipantes)).redondeadoAMoneda.comoDinero)
                        }
                    }
                }
            }
            .navigationTitle("Agregar gasto")
            .navigationBarTitleDisplayMode(.inline)
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

    private func guardar() {
        guard let total = monto, total > 0 else { return }
        let pagadorReal = pagueYo ? nil : pagador
        let gasto = GastoCompartidoIndependiente(
            concepto: concepto.trimmingCharacters(in: .whitespacesAndNewlines),
            monto: total,
            fecha: fecha,
            pagadorEsUsuario: pagueYo,
            pagador: pagadorReal,
            pagadorNombreGuardado: pagueYo ? "Tú" : (pagadorReal?.nombre ?? "Persona"),
            grupo: grupo)
        contexto.insert(gasto)

        var destinos: [(esUsuario: Bool, persona: Persona?, nombre: String)] = []
        if participaUsuario {
            destinos.append((true, nil, "Tú"))
        }
        for persona in personas where participantes.contains(persona.id) {
            destinos.append((false, persona, persona.nombre))
        }

        let base = (total / Double(destinos.count)).redondeadoAMoneda
        var asignado = 0.0
        for (indice, destino) in destinos.enumerated() {
            let capturado: Double
            if destino.esUsuario {
                capturado = parteUsuario ?? 0
            } else if let persona = destino.persona {
                capturado = partesPersonalizadas[persona.id] ?? 0
            } else {
                capturado = 0
            }
            let calculado: Double
            switch modoDivision {
            case .iguales: calculado = base
            case .montos: calculado = capturado
            case .porcentajes: calculado = total * capturado / 100
            }
            let parteMonto = indice == destinos.count - 1
                ? (total - asignado).redondeadoAMoneda
                : calculado.redondeadoAMoneda
            asignado += parteMonto
            contexto.insert(ParteGastoIndependiente(
                monto: parteMonto,
                esUsuario: destino.esUsuario,
                persona: destino.persona,
                personaNombreGuardado: destino.nombre,
                gasto: gasto))
        }
        try? contexto.save()
        cerrar()
    }
}

private enum ModoDivisionGasto: String, CaseIterable, Identifiable {
    case iguales = "Partes iguales"
    case montos = "Montos exactos"
    case porcentajes = "Porcentajes"
    var id: String { rawValue }
}
