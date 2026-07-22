//
//  ImportarEstadoView.swift
//  Claro — Carpeta: Vistas/Importar
//
//  El importador de estados de cuenta:
//  1. Eliges el PDF descargado de tu banco.
//  2. Se analiza EN tu iPhone (Apple Intelligence o lector de reglas).
//  3. Pantalla de revisión: corriges lo que quieras, asignas dueños a
//     los MSI compartidos (con memoria: solo se pregunta la 1a vez).
//  4. Al importar, todo entra como movimientos normales (Ley 1).
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportarEstadoView: View {
    let tarjeta: TarjetaCredito

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @Query(sort: \Categoria.nombre) private var categorias: [Categoria]
    @Query(filter: #Predicate<Persona> { !$0.archivada }, sort: \Persona.nombre) private var personas: [Persona]
    @Query(filter: #Predicate<TarjetaCredito> { !$0.archivada }, sort: \TarjetaCredito.nombre) private var tarjetas: [TarjetaCredito]
    @AppStorage("notificacionesActivadas") private var notificacionesActivadas = false

    enum Paso { case inicio, analizando, revision }
    @State private var paso: Paso = .inicio
    @State private var mensajeError: String?
    @State private var mostrandoSelector = false

    // Resumen del corte (editable en la revisión)
    @State private var fechaCorte: Date = .now
    @State private var fechaLimite: Date =
        Calendar.current.date(byAdding: .day, value: 20, to: .now) ?? .now
    @State private var pagoNoIntereses: Double?
    @State private var pagoMinimo: Double?
    @State private var saldoAlCorte: Double?
    @State private var adeudoPeriodoAnterior: Double?
    @State private var cargosYCostosPeriodo: Double?
    @State private var pagosYAbonosPeriodo: Double?
    @State private var usoIA = false
    @State private var bancoDetectado: String?
    @State private var ultimosDigitosDetectados: String?
    @State private var huellaPDF: String?
    @State private var archivoOrigen: String?
    @State private var confirmandoDiscrepancia = false
    @State private var confirmandoDuplicado = false

    // Movimientos en revisión
    struct MovRevision: Identifiable {
        let id = UUID()
        var incluir: Bool
        var fecha: Date
        var comercio: String
        var monto: Double
        var categoria: Categoria?
        var esMSI: Bool
        var msiNumero: Int
        var msiTotal: Int
        var planExistente: PlanMSI?
        var esDuplicado: Bool
        var partes: [PersistentIdentifier: Double] = [:]
        var montoOriginal: Double = 0
    }
    @State private var revisiones: [MovRevision] = []

    struct IndiceAsignacion: Identifiable { let id: Int }
    @State private var asignando: IndiceAsignacion?
    struct IndiceEdicion: Identifiable { let id: Int }
    @State private var editando: IndiceEdicion?

    var body: some View {
        NavigationStack {
            Group {
                switch paso {
                case .inicio:     vistaInicio
                case .analizando: vistaAnalizando
                case .revision:   vistaRevision
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Importar estado")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
            }
            .fileImporter(isPresented: $mostrandoSelector,
                          allowedContentTypes: [.pdf]) { resultado in
                if case .success(let url) = resultado { procesar(url) }
            }
            .sheet(item: $asignando) { indice in
                if revisiones.indices.contains(indice.id) {
                    AsignacionCompartidaView(
                        titulo: revisiones[indice.id].comercio,
                        montoBase: montoParaDividir(revisiones[indice.id]),
                        esMensual: revisiones[indice.id].esMSI,
                        personas: personas,
                        partes: $revisiones[indice.id].partes)
                }
            }
            .sheet(item: $editando) { indice in
                if revisiones.indices.contains(indice.id) {
                    EditarMovimientoImportadoView(
                        movimiento: $revisiones[indice.id])
                }
            }
        }
        .aparienciaDeLaApp()
    }

    // MARK: - Paso 1: elegir PDF

    private var vistaInicio: some View {
        ScrollView {
            VStack(spacing: 16) {
                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("100% en tu iPhone", systemImage: "lock.shield.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Tema.positivo)
                        Text("El PDF se analiza dentro de tu teléfono con tecnología de Apple. Nada sale a internet y no cuesta nada (Ley 5).")
                            .font(.footnote)
                            .foregroundStyle(Tema.textoSecundario)
                        Text("Descarga el estado de cuenta de \(tarjeta.nombre) desde la app de tu banco (normalmente en formato PDF) y elígelo aquí.")
                            .font(.footnote)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                }

                if let mensajeError {
                    Panel {
                        Label(mensajeError, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Tema.advertencia)
                    }
                }

                Button {
                    mostrandoSelector = true
                } label: {
                    Label("Elegir PDF del estado de cuenta",
                          systemImage: "doc.viewfinder")
                        .font(.headline)
                        .foregroundStyle(Tema.fondo)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Tema.positivo, in: Capsule())
                }
            }
            .padding(16)
        }
    }

    // MARK: - Paso 2: analizando

    private var vistaAnalizando: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(Tema.positivo)
            Text("Analizando el estado de cuenta\nen tu iPhone…")
                .font(.subheadline)
                .foregroundStyle(Tema.textoSecundario)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Paso 3: revisión

    private var vistaRevision: some View {
        Form {
            Section {
                Label(usoIA ? "Analizado con Apple Intelligence en tu iPhone"
                            : "Analizado con lector de reglas (revisa con más cuidado)",
                      systemImage: usoIA ? "sparkles" : "text.magnifyingglass")
                    .font(.footnote)
                    .foregroundStyle(usoIA ? Tema.positivo : Tema.advertencia)
            }

            Section("Documento detectado") {
                LabeledContent("Banco") {
                    Text(bancoDetectado ?? "No identificado")
                        .foregroundStyle(hayDiscrepanciaBanco
                                         ? Tema.urgente : Tema.textoSecundario)
                }
                LabeledContent("Tarjeta") {
                    Text(ultimosDigitosDetectados.map { "•••• \($0)" }
                         ?? "Sin terminación visible")
                        .foregroundStyle(hayDiscrepanciaTarjeta
                                         ? Tema.urgente : Tema.textoSecundario)
                }
                if let archivoOrigen {
                    LabeledContent("Archivo") {
                        Text(archivoOrigen)
                            .foregroundStyle(Tema.textoSecundario)
                            .lineLimit(1)
                    }
                }

                if hayDiscrepanciaBanco || hayDiscrepanciaTarjeta {
                    Label("El documento no parece corresponder con la tarjeta seleccionada.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Tema.urgente)
                    Toggle("Confirmo que elegí la tarjeta correcta",
                           isOn: $confirmandoDiscrepancia)
                }

                if estadoPosiblementeDuplicado != nil {
                    Label("Ya existe un estado de esta tarjeta con el mismo archivo o fecha de corte.",
                          systemImage: "doc.on.doc.fill")
                        .font(.footnote)
                        .foregroundStyle(Tema.advertencia)
                    Toggle("Importar nuevamente de todos modos",
                           isOn: $confirmandoDuplicado)
                }
            }

            Section {
                DatePicker("Fecha de corte", selection: $fechaCorte,
                           displayedComponents: .date)
                DatePicker("Fecha límite de pago", selection: $fechaLimite,
                           displayedComponents: .date)
                filaImporte("Pago para no generar intereses",
                             valor: $pagoNoIntereses)
                filaImporte("Pago mínimo", valor: $pagoMinimo)
                filaImporte("Saldo al corte", valor: $saldoAlCorte)
            } header: {
                Text("Datos del corte (revisa y corrige)")
            } footer: {
                Text("⚠️ Ley 2: esto solo informa. Nada quedará pagado hasta que registres pagos reales.")
            }

            Section("Verificación automática") {
                if let verificacion = verificacionContable {
                    Label(verificacion.esCoherente
                          ? "El resumen bancario cuadra"
                          : "El resumen bancario no cuadra",
                          systemImage: verificacion.esCoherente
                          ? "checkmark.shield.fill"
                          : "exclamationmark.octagon.fill")
                        .foregroundStyle(verificacion.esCoherente
                                         ? Tema.positivo : Tema.urgente)
                    LabeledContent("Adeudo anterior",
                                   value: (adeudoPeriodoAnterior ?? 0).comoDinero)
                    LabeledContent("Cargos y costos del periodo",
                                   value: (cargosYCostosPeriodo ?? 0).comoDinero)
                    LabeledContent("Pagos y abonos del banco",
                                   value: (pagosYAbonosPeriodo ?? 0).comoDinero)
                    LabeledContent("Saldo comprobado",
                                   value: verificacion.saldoEsperado.comoDinero)
                } else {
                    Label("Este banco no expone toda la ecuación del periodo; se aplicarán las validaciones normales.",
                          systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(Tema.textoSecundario)
                }

                if let continuidad = verificacionContinuidad {
                    Label(continuidad <= 1
                          ? "Coincide con el corte anterior guardado"
                          : "No coincide con el corte anterior guardado",
                          systemImage: continuidad <= 1
                          ? "link.circle.fill"
                          : "link.badge.plus")
                        .foregroundStyle(continuidad <= 1
                                         ? Tema.positivo : Tema.urgente)
                }

                if conciliacionCritica {
                    Text("Claro detendrá la importación para evitar guardar un panorama incorrecto. Revisa que el PDF corresponda a esta tarjeta y que el corte anterior esté completo.")
                        .font(.footnote)
                        .foregroundStyle(Tema.urgente)
                }
            }

            Section {
                if revisiones.isEmpty {
                    Text("No se detectaron movimientos. Puedes importar solo los datos del corte.")
                        .font(.footnote)
                        .foregroundStyle(Tema.textoSecundario)
                } else {
                    ForEach($revisiones) { $rev in
                        filaRevision($rev)
                    }
                }
            } header: {
                Text("Movimientos detectados (\(revisiones.count))")
            } footer: {
                Text("Los MSI reconocidos de cortes anteriores avanzan solos sin preguntarte de quién son. Los posibles duplicados vienen desmarcados.")
            }

            Section {
                Button {
                    importarTodo()
                } label: {
                    Label("Importar todo", systemImage: "square.and.arrow.down.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(Tema.positivo)
                .disabled(!puedeImportar)
                if !datosObligatoriosCompletos {
                    Label("Completa los tres importes del corte antes de importar.",
                          systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(Tema.urgente)
                }
            }
        }
    }

    private func filaImporte(_ titulo: String,
                             valor: Binding<Double?>) -> some View {
        LabeledContent {
            TextField("Sin detectar", value: valor,
                      format: .currency(code: "MXN"))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 150)
        } label: {
            Text(titulo)
        }
    }

    private func filaRevision(_ rev: Binding<MovRevision>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: rev.incluir) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rev.wrappedValue.comercio)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                    Text("\(rev.wrappedValue.fecha.formatted(date: .abbreviated, time: .omitted)) · \(rev.wrappedValue.monto.comoDinero)")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                }
            }

            if rev.wrappedValue.esDuplicado {
                Label("Posible duplicado: ya existe un cargo igual en esta tarjeta.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Tema.advertencia)
            }

            if rev.wrappedValue.incluir {
                Button {
                    if let indice = revisiones.firstIndex(where: {
                        $0.id == rev.wrappedValue.id
                    }) {
                        editando = IndiceEdicion(id: indice)
                    }
                } label: {
                    Label("Editar datos detectados", systemImage: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.borderless)

                Picker("Categoría", selection: rev.categoria) {
                    Text("Sin categoría").tag(nil as Categoria?)
                    ForEach(categorias) { cat in
                        Label(cat.nombre, systemImage: cat.icono)
                            .tag(cat as Categoria?)
                    }
                }
                .font(.caption)

                if rev.wrappedValue.esMSI {
                    HStack(spacing: 8) {
                        Pildora(texto: rev.wrappedValue.msiNumero == 0
                                ? "Diferida · 0 de \(rev.wrappedValue.msiTotal)"
                                : "MSI \(rev.wrappedValue.msiNumero) de \(rev.wrappedValue.msiTotal)",
                                color: Tema.acento)

                        if rev.wrappedValue.planExistente != nil {
                            Label("Plan reconocido: avanza solo",
                                  systemImage: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(Tema.positivo)
                        } else {
                            Button {
                                if let indice = revisiones.firstIndex(where: { $0.id == rev.wrappedValue.id }) {
                                    asignando = IndiceAsignacion(id: indice)
                                }
                            } label: {
                                Label(resumenPartes(rev.wrappedValue),
                                      systemImage: "person.2.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } else if !personas.isEmpty {
                    Button {
                        if let indice = revisiones.firstIndex(where: { $0.id == rev.wrappedValue.id }) {
                            asignando = IndiceAsignacion(id: indice)
                        }
                    } label: {
                        Label(resumenPartes(rev.wrappedValue),
                              systemImage: "person.2.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, 2)
    }

    /// Base para dividir: en compras diferidas (pago del mes $0) se
    /// divide sobre la mensualidad real del plan.
    private func montoParaDividir(_ rev: MovRevision) -> Double {
        if rev.esMSI && rev.monto <= 0 && rev.montoOriginal > 0 {
            return rev.montoOriginal / Double(max(1, rev.msiTotal))
        }
        return rev.monto
    }

    private func resumenPartes(_ rev: MovRevision) -> String {
        if rev.partes.isEmpty { return "100% mía · toca para compartir" }
        let nombres = personas
            .filter { rev.partes[$0.id] ?? 0 > 0 }
            .map(\.nombre)
            .joined(separator: ", ")
        return "Compartida con \(nombres)"
    }

    private var datosObligatoriosCompletos: Bool {
        (pagoNoIntereses ?? -1) >= 0
            && (pagoMinimo ?? -1) >= 0
            && (saldoAlCorte ?? -1) >= 0
            && fechaLimite >= fechaCorte
    }

    private var estadoPosiblementeDuplicado: EstadoDeCuenta? {
        tarjeta.estadosDeCuenta.first { estado in
            if let huellaPDF, let previa = estado.huellaPDF,
               previa == huellaPDF { return true }
            return Calendar.current.isDate(estado.fechaCorte,
                                           inSameDayAs: fechaCorte)
        }
    }

    private var hayDiscrepanciaBanco: Bool {
        guard let detectado = bancoDetectado,
              let seleccionado = tarjeta.banco?.nombre else { return false }
        let a = normalizarComparacion(detectado)
        let b = normalizarComparacion(seleccionado)
        return !a.contains(b) && !b.contains(a)
    }

    private var hayDiscrepanciaTarjeta: Bool {
        guard let detectados = ultimosDigitosDetectados,
              !tarjeta.ultimosDigitos.isEmpty else { return false }
        return detectados != tarjeta.ultimosDigitos.suffix(4)
    }

    private var puedeImportar: Bool {
        datosObligatoriosCompletos
            && (!(hayDiscrepanciaBanco || hayDiscrepanciaTarjeta)
                || confirmandoDiscrepancia)
            && (estadoPosiblementeDuplicado == nil || confirmandoDuplicado)
            && !conciliacionCritica
    }

    private var corteAnterior: EstadoDeCuenta? {
        tarjeta.estadosDeCuenta
            .filter { $0.fechaCorte < fechaCorte }
            .max { $0.fechaCorte < $1.fechaCorte }
    }

    private var esBanamexDetectado: Bool {
        normalizarComparacion(bancoDetectado ?? "").contains("BANAMEX")
    }

    private var verificacionContable: VerificacionContableEstado? {
        guard let anterior = adeudoPeriodoAnterior,
              let cargos = cargosYCostosPeriodo,
              let pagos = pagosYAbonosPeriodo,
              let nuevo = pagoNoIntereses else { return nil }
        return ConciliadorEstadoCuenta.verificar(
            adeudoAnterior: anterior, cargosYCostos: cargos,
            pagosYAbonos: pagos,
            nuevoPagoParaNoGenerarIntereses: nuevo)
    }

    private var verificacionContinuidad: Double? {
        guard esBanamexDetectado,
              let reportado = adeudoPeriodoAnterior,
              let anterior = corteAnterior else { return nil }
        return abs(ConciliadorEstadoCuenta.diferenciaConCorteAnterior(
            adeudoAnteriorReportado: reportado,
            corteAnterior: anterior))
    }

    private var conciliacionCritica: Bool {
        if let contable = verificacionContable, !contable.esCoherente {
            return true
        }
        if let continuidad = verificacionContinuidad, continuidad > 1 {
            return true
        }
        return false
    }

    private func normalizarComparacion(_ texto: String) -> String {
        texto.folding(options: [.diacriticInsensitive, .caseInsensitive],
                      locale: Locale(identifier: "es_MX"))
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    // MARK: - Procesar el PDF

    private func procesar(_ url: URL) {
        paso = .analizando
        mensajeError = nil

        Task {
            async let lecturaPaginas = ExtractorPDF.paginas(de: url)
            async let lecturaHuella = ExtractorPDF.huellaSHA256(de: url)
            let (paginas, huella) = await (lecturaPaginas, lecturaHuella)
            guard !paginas.isEmpty else {
                await MainActor.run {
                    mensajeError = "No pude leer ese PDF, ni como texto ni como imagen. Comprueba que el archivo abra correctamente y vuelve a intentarlo."
                    paso = .inicio
                }
                return
            }

            let datos = await AnalizadorEstadoDeCuenta.analizar(paginas: paginas)
            let tieneDatosFinancieros = datos.pagoParaNoGenerarIntereses != nil
                || datos.pagoMinimo != nil
                || datos.saldoAlCorte != nil
                || !datos.movimientos.isEmpty
            guard tieneDatosFinancieros else {
                await MainActor.run {
                    mensajeError = "Pude abrir el PDF, pero no encontré importes o movimientos confiables. No se guardó ningún dato."
                    paso = .inicio
                }
                return
            }

            await MainActor.run {
                huellaPDF = huella
                archivoOrigen = url.lastPathComponent
                prepararRevision(con: datos)
                paso = .revision
            }
        }
    }

    private func prepararRevision(con datos: ResumenDetectado) {
        usoIA = datos.usoIA
        bancoDetectado = datos.bancoDetectado
        ultimosDigitosDetectados = datos.ultimosDigitosDetectados
        confirmandoDiscrepancia = false
        confirmandoDuplicado = false
        if let f = datos.fechaCorte { fechaCorte = f }
        if let f = datos.fechaLimitePago { fechaLimite = f }
        pagoNoIntereses = datos.pagoParaNoGenerarIntereses
        pagoMinimo = datos.pagoMinimo
        saldoAlCorte = datos.saldoAlCorte
        adeudoPeriodoAnterior = datos.adeudoPeriodoAnterior
        cargosYCostosPeriodo = datos.cargosYCostosPeriodo
        pagosYAbonosPeriodo = datos.pagosYAbonosPeriodo

        let comprasExistentes = tarjeta.movimientos.filter {
            $0.cuentaParaCalculos && $0.tipo == .compraCredito
        }

        revisiones = datos.movimientos.map { det in
            var duplicado = false
            var planExistente: PlanMSI?

            if det.esMSI {
                // ¿Ya conocemos este plan de cortes anteriores?
                planExistente = tarjeta.planesMSI.first { plan in
                    guard plan.numeroMeses == det.msiTotal,
                          sonParecidos(plan.detalle, det.comercio) else { return false }
                    // Dos planes del mismo comercio (ej. dos compras en ISHOP)
                    // se distinguen por la mensualidad o por el monto original
                    let mensualidadCoincide = det.monto > 0
                        && abs(plan.mensualidadTipica - det.monto) <= 1.0
                    let originalCoincide = det.montoOriginal > 0
                        && abs(plan.montoTotal - det.montoOriginal) <= 1.0
                    let sinDatosParaDistinguir = det.monto <= 0 && det.montoOriginal <= 0
                    return mensualidadCoincide || originalCoincide || sinDatosParaDistinguir
                }
                // Si el plan ya generó esta mensualidad, es re-importación
                if let plan = planExistente, plan.generadas >= det.msiNumero {
                    duplicado = true
                }
            } else {
                duplicado = comprasExistentes.contains {
                    abs($0.monto - det.monto) < 0.01
                    && abs($0.fecha.timeIntervalSince(det.fecha)) < 3 * 86_400
                }
            }

            // ❄️ ¿Este cargo "normal" es en realidad la siguiente
            // mensualidad de un plan a meses? (El pago congelado de
            // Banamex llega así: como un cargo más, sin "X de Y".)
            var planPorMonto: PlanMSI?
            var numeroDetectado = det.msiNumero
            var totalDetectado = det.msiTotal
            if !det.esMSI && !duplicado {
                for plan in tarjeta.planesMSI {
                    guard let mens = plan.siguientePendienteDeGenerar else { continue }
                    let montoCoincide = abs(mens.monto - det.monto) <= 1.0
                    let comercioCoincide = sonParecidos(plan.detalle, det.comercio)
                    let esElCongelado = plan.pagoCongelado != nil
                        && abs(mens.monto - (plan.pagoCongelado ?? -1)) < 0.01
                    if montoCoincide && (comercioCoincide || esElCongelado) {
                        planPorMonto = plan
                        numeroDetectado = mens.numero
                        totalDetectado = plan.numeroMeses
                        break
                    }
                }
            }

            // 🧠 Memoria de servicios recurrentes: si un cargo parecido
            // (ej. "CFE") ya se dividió antes, pre-llenar la misma
            // división en proporción al nuevo monto.
            var partesPrevias: [PersistentIdentifier: Double] = [:]
            if !det.esMSI && planPorMonto == nil {
                if let previo = tarjeta.movimientos
                    .filter({ $0.compraCompartida != nil
                              && $0.monto > 0
                              && sonParecidos($0.detalle, det.comercio) })
                    .max(by: { $0.fecha < $1.fecha }),
                   let compartida = previo.compraCompartida {
                    for parte in compartida.participaciones {
                        if let persona = parte.persona,
                           partesPrevias[persona.id] == nil {
                            let fraccion = parte.monto / previo.monto
                            partesPrevias[persona.id] =
                                ((det.monto * fraccion) * 100).rounded() / 100
                        }
                    }
                }
            }

            return MovRevision(
                incluir: !duplicado,
                fecha: det.fecha,
                comercio: det.comercio,
                monto: det.monto,
                categoria: CategorizadorAutomatico.sugerir(para: det.comercio,
                                                           entre: categorias),
                esMSI: det.esMSI || planPorMonto != nil,
                msiNumero: numeroDetectado,
                msiTotal: totalDetectado,
                planExistente: planExistente ?? planPorMonto,
                esDuplicado: duplicado,
                partes: partesPrevias,
                montoOriginal: det.montoOriginal)
        }

        // Red de seguridad: en BBVA una misma mensualidad puede venir DOS
        // veces (tabla de diferidos + lista regular "14 DE 20 ..."). Se
        // conserva una sola, con preferencia por la fila de la tabla de
        // diferidos (la que trae el Monto Original).
        var clavesConOriginal: Set<String> = []
        for rev in revisiones where rev.esMSI && rev.montoOriginal > 0 {
            clavesConOriginal.insert(claveMensualidad(rev))
        }
        var clavesVistas: Set<String> = []
        revisiones = revisiones.filter { rev in
            guard rev.esMSI else { return true }
            let clave = claveMensualidad(rev)
            if rev.montoOriginal > 0 {
                // fila de la tabla de diferidos: siempre se queda
                if clavesVistas.contains(clave) { return false }
                clavesVistas.insert(clave)
                return true
            }
            // fila de la lista regular: fuera si ya existe su gemela
            if clavesConOriginal.contains(clave) || clavesVistas.contains(clave) {
                return false
            }
            clavesVistas.insert(clave)
            return true
        }
    }

    /// Identifica una mensualidad dentro del lote por total, número y monto
    /// (el monto distingue planes gemelos del mismo comercio).
    private func claveMensualidad(_ rev: MovRevision) -> String {
        let montoClave = rev.monto > 0 ? rev.monto : rev.montoOriginal
        return "\(rev.msiTotal)-\(rev.msiNumero)-\(Int((montoClave * 100).rounded()))"
    }

    private func sonParecidos(_ a: String, _ b: String) -> Bool {
        func limpiar(_ s: String) -> String {
            var texto = s.uppercased()
            // Quitar contador inicial tipo "14 DE 20 " (nombres de planes
            // creados por importaciones antiguas o formatos raros)
            if let regex = try? NSRegularExpression(
                pattern: "^\\s*\\d{1,2}\\s+DE\\s+\\d{1,2}\\s+"),
               let m = regex.firstMatch(in: texto,
                                        range: NSRange(texto.startIndex..., in: texto)),
               let r = Range(m.range, in: texto) {
                texto.removeSubrange(r)
            }
            return String(texto.filter { $0.isLetter || $0.isNumber })
        }
        let la = limpiar(a), lb = limpiar(b)
        guard !la.isEmpty && !lb.isEmpty else { return false }
        return la.hasPrefix(String(lb.prefix(10))) || lb.hasPrefix(String(la.prefix(10)))
    }

    // MARK: - Importar (todo entra como movimientos: Ley 1)

    private func importarTodo() {
        guard puedeImportar else { return }
        let loteID = UUID()

        // Regla de continuidad: antes de introducir el corte nuevo, todos
        // los pagos que ya existían quedan sellados al estado que estaba
        // disponible cuando fueron registrados. El corte nuevo no puede
        // apropiarse de pagos que el banco ya reflejó en su saldo.
        tarjeta.sellarAsignacionUnicaDePagos()

        // 1. El estado de cuenta (la "cuenta del restaurante")
        let calendario = Calendar.current
        let inicioPeriodo: Date
        if let corteAnterior = tarjeta.estadosDeCuenta
            .map(\.fechaCorte).filter({ $0 < fechaCorte }).max() {
            inicioPeriodo = calendario.date(byAdding: .day, value: 1,
                                            to: corteAnterior) ?? corteAnterior
        } else {
            inicioPeriodo = calendario.date(byAdding: .day, value: -30,
                                            to: fechaCorte) ?? fechaCorte
        }

        let estado = EstadoDeCuenta(
            fechaCorte: fechaCorte,
            fechaLimitePago: fechaLimite,
            inicioPeriodo: inicioPeriodo,
            finPeriodo: fechaCorte,
            pagoParaNoGenerarIntereses: pagoNoIntereses ?? 0,
            pagoMinimo: pagoMinimo ?? 0,
            saldoAlCorte: saldoAlCorte ?? 0,
            tarjeta: tarjeta)
        estado.importacionID = loteID
        estado.huellaPDF = huellaPDF
        estado.archivoOrigen = archivoOrigen
        estado.bancoDetectado = bancoDetectado
        estado.adeudoPeriodoAnteriorReportado = adeudoPeriodoAnterior
        estado.cargosYCostosPeriodoReportados = cargosYCostosPeriodo
        estado.pagosYAbonosPeriodoReportados = pagosYAbonosPeriodo
        contexto.insert(estado)

        // 2. Cada movimiento aprobado
        for rev in revisiones where rev.incluir {
            if rev.esMSI {
                if let plan = rev.planExistente {
                    avanzarPlan(plan, con: estado, loteID: loteID)
                } else {
                    crearPlanImportado(rev, estado: estado, loteID: loteID)
                }
            } else {
                let mov = Movimiento(tipo: .compraCredito,
                                     monto: rev.monto,
                                     fecha: rev.fecha,
                                     detalle: rev.comercio,
                                     tarjeta: tarjeta,
                                     categoria: rev.categoria)
                mov.importacionID = loteID
                contexto.insert(mov)
                crearCompartidaSiAplica(para: mov, partes: rev.partes,
                                        loteID: loteID)
            }
        }

        do {
            try contexto.save()
            if notificacionesActivadas {
                ProgramadorDeNotificaciones.reprogramar(
                    tarjetas: tarjetas, personas: personas)
            }
            cerrar()
        } catch {
            contexto.rollback()
            mensajeError = "No se pudo guardar la importación. No se modificó tu información."
        }
    }

    /// Plan reconocido: la mensualidad avanza sola y a cada persona
    /// se le carga su parte del mes (con la división ya recordada).
    private func avanzarPlan(_ plan: PlanMSI,
                             con estado: EstadoDeCuenta,
                             loteID: UUID) {
        guard let mensualidad = plan.siguientePendienteDeGenerar else { return }
        mensualidad.fechaGeneracion = fechaCorte
        mensualidad.estadoDeCuenta = estado
        mensualidad.importacionID = loteID

        // Replicar la división del mes anterior (memoria de dueños)
        if let compartida = plan.movimientos
            .compactMap(\.compraCompartida).first {
            var plantilla: [Persona: Double] = [:]
            for parte in compartida.participaciones {
                if let persona = parte.persona, plantilla[persona] == nil {
                    plantilla[persona] = parte.monto
                }
            }
            for (persona, monto) in plantilla {
                let parte = Participacion(monto: monto,
                                          persona: persona,
                                          compra: compartida)
                parte.importacionID = loteID
                contexto.insert(parte)
            }
        }
    }

    /// Plan nuevo detectado: "4 de 13" a media vida, o una compra
    /// DIFERIDA "0 de N" que aún no empieza a cobrarse (Banamex).
    private func crearPlanImportado(_ rev: MovRevision,
                                    estado: EstadoDeCuenta,
                                    loteID: UUID) {
        let calendario = Calendar.current

        // Fecha de compra: para diferidos usamos la fecha real de la
        // operación (viene en la tabla); para planes a media vida, se estima.
        let fechaCompra: Date
        if rev.msiNumero <= 0 {
            fechaCompra = rev.fecha
        } else {
            fechaCompra = calendario.date(byAdding: .month,
                                          value: -(rev.msiNumero - 1),
                                          to: fechaCorte) ?? fechaCorte
        }

        // Total del plan: la columna "Monto Original" cuando existe.
        let totalPlan = rev.montoOriginal > 0
            ? rev.montoOriginal
            : rev.monto * Double(rev.msiTotal)
        let montoMensualidad = rev.msiNumero > 0
            ? rev.monto
            : totalPlan / Double(max(1, rev.msiTotal))

        let plan = PlanMSI(detalle: rev.comercio,
                           montoTotal: totalPlan,
                           numeroMeses: rev.msiTotal,
                           fechaCompra: fechaCompra,
                           tarjeta: tarjeta)
        plan.importacionID = loteID
        contexto.insert(plan)

        for numero in 1...rev.msiTotal {
            let mensualidad = MensualidadMSI(numero: numero,
                                             monto: montoMensualidad,
                                             plan: plan)
            mensualidad.importacionID = loteID
            contexto.insert(mensualidad)

            if numero < rev.msiNumero {
                // Mensualidades anteriores a este corte: se asumen ya
                // generadas y cubiertas en la vida real antes de la app.
                mensualidad.fechaGeneracion = calendario.date(
                    byAdding: .month, value: numero - 1, to: fechaCompra)
                mensualidad.cubierta = true
            } else if numero == rev.msiNumero {
                mensualidad.fechaGeneracion = fechaCorte
                mensualidad.estadoDeCuenta = estado
            }
            // Si rev.msiNumero == 0 (diferida): NADA se genera todavía.
            // El plan queda esperando el corte donde el banco lo cobre.
        }

        // Movimiento ancla del plan. Carga deuda completa solo si la compra
        // es de ESTE periodo; si viene del pasado, su deuda ya vive en el
        // saldo inicial de la tarjeta y el ancla va en $0 (guarda la
        // división de dueños de todas formas).
        let limitePeriodo = calendario.date(byAdding: .day, value: -31,
                                            to: fechaCorte) ?? fechaCorte
        let esCompraDeEstePeriodo = fechaCompra > limitePeriodo
        let cargaDeuda = rev.msiNumero <= 1 && esCompraDeEstePeriodo
        let mov = Movimiento(
            tipo: .compraCredito,
            monto: cargaDeuda ? plan.montoTotal : 0,
            fecha: fechaCompra,
            detalle: rev.comercio + (cargaDeuda ? "" : " (plan importado)"),
            tarjeta: tarjeta,
            categoria: rev.categoria)
        mov.planMSI = plan
        mov.importacionID = loteID
        contexto.insert(mov)

        crearCompartidaSiAplica(para: mov, partes: rev.partes,
                                loteID: loteID)
    }

    private func crearCompartidaSiAplica(para movimiento: Movimiento,
                                         partes: [PersistentIdentifier: Double],
                                         loteID: UUID) {
        let conMonto = partes.filter { $0.value > 0 }
        guard !conMonto.isEmpty else { return }

        let compartida = CompraCompartida()
        contexto.insert(compartida)
        movimiento.compraCompartida = compartida

        for persona in personas {
            if let monto = conMonto[persona.id], monto > 0 {
                let parte = Participacion(monto: monto,
                                          persona: persona,
                                          compra: compartida)
                parte.importacionID = loteID
                contexto.insert(parte)
            }
        }
    }
}

// MARK: - Corrección de un movimiento antes de importarlo

struct EditarMovimientoImportadoView: View {
    @Binding var movimiento: ImportarEstadoView.MovRevision
    @Environment(\.dismiss) private var cerrar

    @State private var comercio: String
    @State private var monto: Double?
    @State private var fecha: Date
    @State private var esMSI: Bool
    @State private var numero: Int
    @State private var total: Int

    init(movimiento: Binding<ImportarEstadoView.MovRevision>) {
        _movimiento = movimiento
        let valor = movimiento.wrappedValue
        _comercio = State(initialValue: valor.comercio)
        _monto = State(initialValue: valor.monto)
        _fecha = State(initialValue: valor.fecha)
        _esMSI = State(initialValue: valor.esMSI)
        _numero = State(initialValue: valor.msiNumero)
        _total = State(initialValue: valor.msiTotal)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos detectados") {
                    TextField("Comercio o descripción", text: $comercio,
                              axis: .vertical)
                        .lineLimit(2...4)
                    LabeledContent("Monto") {
                        TextField("$0.00", value: $monto,
                                  format: .currency(code: "MXN"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    DatePicker("Fecha", selection: $fecha,
                               displayedComponents: .date)
                }

                Section("Compra a meses") {
                    Toggle("Es una mensualidad", isOn: $esMSI)
                    if esMSI {
                        Stepper("Mensualidad actual: \(numero)",
                                value: $numero, in: 0...max(1, total))
                        Stepper("Total de mensualidades: \(total)",
                                value: $total, in: max(1, numero)...60)
                    }
                }
            }
            .navigationTitle("Corregir movimiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        movimiento.comercio = comercio
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        movimiento.monto = (monto ?? 0).redondeadoAMoneda
                        movimiento.fecha = fecha
                        movimiento.esMSI = esMSI
                        movimiento.msiNumero = esMSI ? numero : 0
                        movimiento.msiTotal = esMSI ? total : 0
                        cerrar()
                    }
                    .disabled(comercio.trimmingCharacters(
                        in: .whitespacesAndNewlines).isEmpty
                        || (monto ?? 0) < 0
                        || (esMSI && total < 1))
                }
            }
        }
        .aparienciaDeLaApp()
    }
}

// MARK: - Hoja de división de dueños

struct AsignacionCompartidaView: View {
    let titulo: String
    let montoBase: Double
    let esMensual: Bool
    let personas: [Persona]

    @Binding var partes: [PersistentIdentifier: Double]
    @Environment(\.dismiss) private var cerrar

    private var sumaAjena: Double { partes.values.reduce(0, +) }
    private var tuParte: Double { max(0, montoBase - sumaAjena) }

    private var participantes: Set<PersistentIdentifier> {
        Set(partes.filter { $0.value > 0 }.keys)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(titulo)
                        .font(.subheadline.weight(.semibold))
                    Text(esMensual
                         ? "División de CADA mensualidad de \(montoBase.comoDinero). Se recordará para los siguientes cortes."
                         : "División de la compra de \(montoBase.comoDinero).")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                }

                Section("¿Quiénes participan? (partes iguales contigo)") {
                    Button("100% mía") { partes = [:] }

                    ForEach(personas) { persona in
                        HStack(spacing: 10) {
                            Toggle(persona.nombre, isOn: bindingParticipa(persona))
                            Button("100% suya") {
                                // Toda la compra/mensualidad es de esta persona
                                partes = [persona.id: montoBase]
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)
                            .tint(Tema.acento)
                        }
                    }
                }

                Section {
                    ForEach(personas) { persona in
                        if participantes.contains(persona.id) {
                            HStack {
                                Text(persona.nombre)
                                Spacer()
                                TextField("0", value: bindingMonto(persona),
                                          format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 110)
                            }
                        }
                    }
                    HStack {
                        Text("Tu parte")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(tuParte.comoDinero)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(sumaAjena <= montoBase
                                             ? Tema.positivo : Tema.urgente)
                    }
                } header: {
                    Text("Ajuste fino (opcional)")
                } footer: {
                    if sumaAjena > montoBase {
                        Text("⚠️ Las partes ajenas superan el monto.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("¿De quién es?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { cerrar() }
                        .disabled(sumaAjena > montoBase)
                }
            }
        }
        .aparienciaDeLaApp()
    }

    private func bindingParticipa(_ persona: Persona) -> Binding<Bool> {
        Binding(
            get: { participantes.contains(persona.id) },
            set: { activo in
                var nuevos = participantes
                if activo { nuevos.insert(persona.id) }
                else { nuevos.remove(persona.id) }
                // Repartir en partes iguales entre tú + los participantes
                partes = [:]
                let total = Double(nuevos.count + 1)
                for id in nuevos { partes[id] = montoBase / total }
            }
        )
    }

    private func bindingMonto(_ persona: Persona) -> Binding<Double?> {
        Binding(
            get: { partes[persona.id] },
            set: { partes[persona.id] = $0 ?? 0 }
        )
    }
}
