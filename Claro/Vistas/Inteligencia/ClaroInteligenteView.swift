//
//  ClaroInteligenteView.swift
//  Claro
//
//  Conversación privada con las finanzas que ya viven en la app.
//

import SwiftData
import SwiftUI

struct ClaroInteligenteView: View {
    @Environment(\.dismiss) private var cerrar
    @Environment(\.modelContext) private var contexto

    @Query private var cuentas: [CuentaBancaria]
    @Query private var tarjetas: [TarjetaCredito]
    @Query private var personas: [Persona]
    @Query private var planes: [PlanMSI]
    @Query private var deudas: [Deuda]
    @Query(sort: \Movimiento.fecha, order: .reverse) private var movimientos: [Movimiento]
    @Query private var ingresosRecurrentes: [IngresoRecurrente]
    @Query private var ocurrenciasIngreso: [OcurrenciaIngresoRecurrente]
    @Query(sort: \ConversacionFinanciera.actualizadaEl, order: .reverse)
    private var conversaciones: [ConversacionFinanciera]

    @AppStorage("montosOcultos") private var montosOcultos = false
    @StateObject private var qwen = AdministradorQwen.shared
    @StateObject private var voz = ReconocedorVozLocal()
    @State private var mensajes: [MensajeClaro] = []
    @State private var pregunta = ""
    @State private var pensando = false
    @State private var tareaRespuesta: Task<Void, Never>?
    @State private var solicitudActiva: UUID?
    @State private var confirmarEliminacionQwen = false
    @State private var conversacionActual: ConversacionFinanciera?
    @State private var mostrandoHistorial = false
    @FocusState private var escribiendo: Bool

    private let sugerencias = [
        "¿Cómo ves mis finanzas?",
        "¿Cómo cierro este mes?",
        "¿Es buen momento para un préstamo?",
        "¿Qué riesgo financiero tengo?"
    ]

    private var resumen: ResumenFinancieroClaro {
        MotorClaroInteligente.resumir(
            cuentas: cuentas, tarjetas: tarjetas, personas: personas,
            planes: planes, deudas: deudas, movimientos: movimientos,
            ingresosRecurrentes: ingresosRecurrentes,
            ocurrenciasIngreso: ocurrenciasIngreso,
            ahora: FechaAnalisisClaro.actual)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                conversacion
                compositor
            }
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Claro Inteligente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") {
                        voz.detener()
                        cancelarRespuestaActiva()
                        cerrar()
                    }
                    .foregroundStyle(Tema.positivo)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    menuInformacion
                }
            }
        }
        .aparienciaDeLaApp()
        .task {
            await qwen.prepararAlAbrir()
            if conversacionActual == nil, let reciente = conversaciones.first {
                cargar(reciente: reciente)
            }
        }
        .onDisappear {
            voz.detener()
            cancelarRespuestaActiva()
        }
        .onChange(of: voz.texto) { _, texto in
            guard voz.estaEscuchando || !texto.isEmpty else { return }
            pregunta = texto
        }
        .alert("Dictado local", isPresented: Binding(
            get: { voz.aviso != nil },
            set: { if !$0 { voz.aviso = nil } })) {
                Button("Entendido", role: .cancel) { voz.aviso = nil }
            } message: {
                Text(voz.aviso ?? "")
            }
        .confirmationDialog(
            "¿Eliminar \(qwen.nombreVisible) del iPhone?",
            isPresented: $confirmarEliminacionQwen,
            titleVisibility: .visible) {
                Button("Eliminar modelo", role: .destructive) {
                    try? qwen.eliminarModelo()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Se liberarán aproximadamente \(qwen.tamanoAproximado). Tus datos financieros y estados de cuenta no se tocarán.")
            }
        .sheet(isPresented: $mostrandoHistorial) {
            HistorialConversacionesClaroView(
                conversaciones: conversaciones,
                seleccionar: { conversacion in
                    cargar(reciente: conversacion)
                    mostrandoHistorial = false
                })
        }
    }

    @ViewBuilder
    private var menuInformacion: some View {
        Menu {
            Section("Conversaciones") {
                Button { nuevaConversacion() } label: {
                    Label("Nuevo chat", systemImage: "square.and.pencil")
                }
                Button { mostrandoHistorial = true } label: {
                    Label("Historial", systemImage: "clock.arrow.circlepath")
                }
            }
            Section("Panorama") {
                Label("Riesgo: \(resumen.nivelRiesgo.rawValue)",
                      systemImage: "shield.lefthalf.filled")
                Label("Cierre estimado: \(resumen.proyeccionFinDeMes.comoDinero)",
                      systemImage: "calendar")
                Label("Confianza: \(resumen.confianza.capitalized)",
                      systemImage: "checkmark.seal")
            }

            Section("Inteligencia local") {
                switch qwen.estado {
                case .noDescargado:
                    Button {
                        qwen.iniciarDescarga()
                    } label: {
                        Label("Descargar Qwen 4B", systemImage: "arrow.down.circle")
                    }

                case .descargando:
                    Button {
                        qwen.cancelarDescarga()
                    } label: {
                        Label("Cancelar descarga", systemImage: "xmark.circle")
                    }

                case .descargado, .listo:
                    Label("Apple + Qwen disponibles",
                          systemImage: "checkmark.circle.fill")
                    Button(role: .destructive) {
                        confirmarEliminacionQwen = true
                    } label: {
                        Label("Eliminar Qwen del iPhone", systemImage: "trash")
                    }

                case .cargando:
                    Label("Preparando respuesta…", systemImage: "hourglass")

                case .error:
                    Button {
                        Task {
                            if qwen.estaDescargado {
                                await qwen.prepararAlAbrir()
                            } else {
                                qwen.iniciarDescarga()
                            }
                        }
                    } label: {
                        Label("Reintentar IA local", systemImage: "arrow.clockwise")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
        }
        .accessibilityLabel("Información y opciones")
    }

    private var conversacion: some View {
        ScrollViewReader { lector in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if mensajes.isEmpty {
                        bienvenida
                    }
                    ForEach(mensajes) { mensaje in
                        burbuja(mensaje)
                            .id(mensaje.id)
                    }
                    if pensando {
                        HStack(spacing: 8) {
                            ProgressView().tint(Tema.acento)
                            Text("Pensando…")
                                .font(.footnote)
                                .foregroundStyle(Tema.textoSecundario)
                            Spacer()
                        }
                        .padding(14)
                        .background(Tema.panel, in: RoundedRectangle(cornerRadius: 18))
                        .id("pensando")
                    }
                }
                .padding(16)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: mensajes.count) { _, _ in
                withAnimation {
                    lector.scrollTo(mensajes.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: pensando) { _, activo in
                if activo {
                    withAnimation { lector.scrollTo("pensando", anchor: .bottom) }
                }
            }
        }
    }

    private var bienvenida: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("¿Qué quieres saber?")
                    .font(.title2.bold())
                    .foregroundStyle(Tema.textoPrincipal)
                Text("Pregunta sobre tus finanzas o conversa conmigo.")
                    .font(.subheadline)
                    .foregroundStyle(Tema.textoSecundario)
            }

            VStack(spacing: 8) {
                ForEach(sugerencias, id: \.self) { sugerencia in
                    Button {
                        enviar(sugerencia)
                    } label: {
                        HStack {
                            Text(sugerencia)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Tema.textoPrincipal)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(Tema.acento)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Tema.panel, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(Presionable())
                    .disabled(pensando)
                }
            }
        }
    }

    private func burbuja(_ mensaje: MensajeClaro) -> some View {
        HStack(alignment: .bottom) {
            if mensaje.esUsuario { Spacer(minLength: 44) }
            VStack(alignment: mensaje.esUsuario ? .trailing : .leading, spacing: 6) {
                if mensaje.esUsuario {
                    Text(textoVisible(mensaje.texto))
                        .font(.body)
                        .foregroundStyle(Color.white)
                        .textSelection(.enabled)
                } else {
                    RespuestaFinancieraFormateada(
                        texto: textoVisible(mensaje.texto),
                        estructurarParrafoLargo: mensaje.ambito.usaFormatoAnalitico)
                        .foregroundStyle(Tema.textoPrincipal)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                mensaje.esUsuario ? Tema.acento : Tema.panel,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            if !mensaje.esUsuario { Spacer(minLength: 26) }
        }
    }

    private var compositor: some View {
        VStack(spacing: 8) {
            if voz.estaEscuchando {
                HStack(spacing: 7) {
                    Circle().fill(Tema.urgente).frame(width: 7, height: 7)
                    Text("Escuchando en el iPhone… toca el micrófono para terminar")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                    Spacer()
                }
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Pregúntame lo que quieras", text: $pregunta, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($escribiendo)
                    .submitLabel(.send)
                    .onSubmit { enviarPreguntaActual() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Tema.panelElevado,
                                in: RoundedRectangle(cornerRadius: 18))

                Button {
                    Task { await voz.alternar() }
                } label: {
                    Image(systemName: voz.estaEscuchando ? "stop.fill" : "mic.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(voz.estaEscuchando ? Color.white : Tema.acento)
                        .frame(width: 44, height: 44)
                        .background(voz.estaEscuchando ? Tema.urgente : Tema.panelElevado,
                                    in: Circle())
                }
                .accessibilityLabel(voz.estaEscuchando ? "Detener dictado" : "Dictar pregunta")

                Button(action: enviarPreguntaActual) {
                    Image(systemName: "arrow.up")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(puedeEnviar ? Tema.positivo : Tema.textoSecundario,
                                    in: Circle())
                }
                .disabled(!puedeEnviar)
                .accessibilityLabel("Enviar pregunta")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().overlay(Tema.panelElevado) }
    }

    private var puedeEnviar: Bool {
        !pensando && !pregunta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func enviarPreguntaActual() {
        enviar(pregunta)
    }

    private func enviar(_ texto: String) {
        let limpia = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpia.isEmpty, !pensando else { return }
        voz.detener()
        pregunta = ""
        escribiendo = false

        var historial = mensajes.suffix(12).map {
            TurnoConversacionClaro(esUsuario: $0.esUsuario, texto: $0.texto,
                                   ambito: $0.ambito)
        }
        if let memoria = conversacionActual?.resumen, !memoria.isEmpty {
            historial.insert(TurnoConversacionClaro(esUsuario: false,
                texto: "Memoria resumida de mensajes anteriores: \(memoria)",
                ambito: .general), at: 0)
        }
        let ambito = ClaroInteligenciaLocal.ambitoDeLaConsulta(limpia)
        let mensajeUsuario = MensajeClaro(esUsuario: true, texto: limpia,
                                          fuente: nil, ambito: ambito)
        mensajes.append(mensajeUsuario)
        let conversacion = obtenerConversacion(primeraPregunta: limpia)
        guardar(mensajeUsuario, en: conversacion)
        pensando = true
        let fotoFinanciera = resumen

        let idSolicitud = UUID()
        solicitudActiva = idSolicitud
        tareaRespuesta?.cancel()
        tareaRespuesta = Task {
            let respuesta = await ClaroInteligenciaLocal.responder(
                pregunta: limpia, resumen: fotoFinanciera, historial: historial)
            guard !Task.isCancelled, solicitudActiva == idSolicitud else { return }
            // El clasificador semántico puede comprender una referencia que
            // el filtro rápido no vio. Guardamos el ámbito definitivo para
            // que el siguiente turno reciba el historial correcto.
            if let indice = mensajes.firstIndex(where: {
                $0.id == mensajeUsuario.id
            }) {
                mensajes[indice].ambito = respuesta.ambito
            }
            let mensajeRespuesta = MensajeClaro(esUsuario: false,
                                         texto: respuesta.texto,
                                         fuente: respuesta.fuente,
                                          ambito: respuesta.ambito)
            mensajes.append(mensajeRespuesta)
            guardar(mensajeRespuesta, en: conversacion)
            actualizarMemoria(conversacion)
            pensando = false
            solicitudActiva = nil
            tareaRespuesta = nil
        }
    }

    private func cancelarRespuestaActiva() {
        solicitudActiva = nil
        tareaRespuesta?.cancel()
        tareaRespuesta = nil
        pensando = false
    }

    private func obtenerConversacion(primeraPregunta: String) -> ConversacionFinanciera {
        if let conversacionActual { return conversacionActual }
        let titulo = String(primeraPregunta.prefix(48))
        let nueva = ConversacionFinanciera(titulo: titulo)
        contexto.insert(nueva)
        conversacionActual = nueva
        return nueva
    }

    private func guardar(_ mensaje: MensajeClaro, en conversacion: ConversacionFinanciera) {
        let guardado = MensajeFinanciero(
            esUsuario: mensaje.esUsuario,
            texto: mensaje.texto,
            fuenteRaw: mensaje.fuente?.rawValue,
            ambitoRaw: mensaje.ambito.valorPersistente,
            conversacion: conversacion)
        contexto.insert(guardado)
        conversacion.actualizadaEl = .now
        try? contexto.save()
    }

    private func cargar(reciente conversacion: ConversacionFinanciera) {
        cancelarRespuestaActiva()
        conversacionActual = conversacion
        mensajes = conversacion.mensajes.sorted { $0.creadoEl < $1.creadoEl }.map {
            MensajeClaro(esUsuario: $0.esUsuario, texto: $0.texto,
                         fuente: $0.fuenteRaw.flatMap(FuenteRespuestaClaro.init(rawValue:)),
                         ambito: AmbitoConsultaClaro(valorPersistente: $0.ambitoRaw))
        }
    }

    private func nuevaConversacion() {
        cancelarRespuestaActiva()
        conversacionActual = nil
        mensajes = []
        pregunta = ""
    }

    private func actualizarMemoria(_ conversacion: ConversacionFinanciera) {
        let ordenados = conversacion.mensajes.sorted { $0.creadoEl < $1.creadoEl }
        guard ordenados.count > 16 else { return }
        conversacion.resumen = ordenados.dropLast(12).suffix(12).map {
            ($0.esUsuario ? "Usuario: " : "Claro: ") + String($0.texto.prefix(180))
        }.joined(separator: " | ")
    }

    private func textoVisible(_ texto: String) -> String {
        guard montosOcultos else { return texto }
        guard let expresion = try? NSRegularExpression(
            pattern: #"\$\s*-?[\d,.]+"#) else { return texto }
        let rango = NSRange(texto.startIndex..., in: texto)
        return expresion.stringByReplacingMatches(in: texto, range: rango,
                                                   withTemplate: "$ ••••")
    }

}

private struct HistorialConversacionesClaroView: View {
    let conversaciones: [ConversacionFinanciera]
    let seleccionar: (ConversacionFinanciera) -> Void
    @Environment(\.dismiss) private var cerrar
    @Environment(\.modelContext) private var contexto
    @State private var renombrando: ConversacionFinanciera?
    @State private var nuevoTitulo = ""

    var body: some View {
        NavigationStack {
            List {
                if conversaciones.isEmpty {
                    ContentUnavailableView("Sin conversaciones", systemImage: "bubble.left.and.bubble.right")
                }
                ForEach(conversaciones) { conversacion in
                    Button { seleccionar(conversacion) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conversacion.titulo).foregroundStyle(Tema.textoPrincipal)
                            Text("\(conversacion.mensajes.count) mensajes · \(conversacion.actualizadaEl.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(Tema.textoSecundario)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) { contexto.delete(conversacion) } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                        Button { renombrando = conversacion; nuevoTitulo = conversacion.titulo } label: {
                            Label("Renombrar", systemImage: "pencil")
                        }.tint(Tema.acento)
                    }
                }
            }
            .navigationTitle("Conversaciones")
            .toolbar { Button("Cerrar") { cerrar() } }
            .alert("Renombrar conversación", isPresented: Binding(
                get: { renombrando != nil }, set: { if !$0 { renombrando = nil } })) {
                TextField("Título", text: $nuevoTitulo)
                Button("Guardar") { renombrando?.titulo = nuevoTitulo; renombrando = nil }
                Button("Cancelar", role: .cancel) { renombrando = nil }
            }
        }
        .aparienciaDeLaApp()
    }
}

private struct MensajeClaro: Identifiable {
    let id = UUID()
    let esUsuario: Bool
    let texto: String
    let fuente: FuenteRespuestaClaro?
    var ambito: AmbitoConsultaClaro
}

private struct RespuestaFinancieraFormateada: View {
    let texto: String
    let estructurarParrafoLargo: Bool

    private var bloques: [BloqueRespuestaFinanciera] {
        BloqueRespuestaFinanciera.interpretar(
            texto, estructurarParrafoLargo: estructurarParrafoLargo)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(bloques) { bloque in
                switch bloque.estilo {
                case .titulo:
                    textoConMarkdown(bloque.texto)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Tema.acento)
                        .padding(.top, bloque.esPrimero ? 0 : 3)

                case .destacado:
                    textoConMarkdown(bloque.texto)
                        .font(.body.weight(.semibold))

                case .parrafo:
                    textoConMarkdown(bloque.texto)
                        .font(.body)

                case .vineta:
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle()
                            .fill(Tema.acento)
                            .frame(width: 5, height: 5)
                        textoConMarkdown(bloque.texto)
                            .font(.body)
                    }

                case .numerado:
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(bloque.numero ?? 1).")
                            .font(.body.weight(.bold))
                            .foregroundStyle(Tema.acento)
                        textoConMarkdown(bloque.texto)
                            .font(.body)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func textoConMarkdown(_ contenido: String) -> Text {
        let opciones = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let enriquecido = try? AttributedString(
            markdown: contenido, options: opciones) {
            return Text(enriquecido)
        }
        return Text(contenido)
    }
}

private struct BloqueRespuestaFinanciera: Identifiable {
    enum Estilo {
        case titulo
        case destacado
        case parrafo
        case vineta
        case numerado
    }

    let id = UUID()
    let estilo: Estilo
    let texto: String
    var numero: Int? = nil
    var esPrimero = false

    static func interpretar(
        _ respuesta: String,
        estructurarParrafoLargo: Bool) -> [Self] {
        let lineas = respuesta
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        var bloques: [Self] = []
        var parrafo: [String] = []

        func agregarParrafo() {
            let unido = parrafo.joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !unido.isEmpty {
                bloques.append(Self(estilo: .parrafo, texto: unido))
            }
            parrafo.removeAll(keepingCapacity: true)
        }

        for lineaOriginal in lineas {
            let linea = lineaOriginal.trimmingCharacters(in: .whitespaces)
            guard !linea.isEmpty else {
                agregarParrafo()
                continue
            }

            if linea.hasPrefix("#") {
                agregarParrafo()
                let titulo = linea.drop(while: { $0 == "#" || $0 == " " })
                bloques.append(Self(estilo: .titulo, texto: String(titulo)))
                continue
            }

            if let contenido = contenidoDeVineta(linea) {
                agregarParrafo()
                bloques.append(Self(estilo: .vineta, texto: contenido))
                continue
            }

            if let (numero, contenido) = contenidoNumerado(linea) {
                agregarParrafo()
                bloques.append(Self(estilo: .numerado, texto: contenido,
                                    numero: numero))
                continue
            }

            parrafo.append(linea)
        }
        agregarParrafo()

        if estructurarParrafoLargo,
           bloques.count == 1,
           bloques[0].estilo == .parrafo,
           bloques[0].texto.count > 280 {
            bloques = acomodarParrafoLargo(bloques[0].texto)
        }

        if bloques.isEmpty {
            bloques = [Self(estilo: .parrafo, texto: respuesta)]
        }
        bloques[0].esPrimero = true
        return bloques
    }

    private static func contenidoDeVineta(_ linea: String) -> String? {
        for prefijo in ["- ", "* ", "• "] where linea.hasPrefix(prefijo) {
            return String(linea.dropFirst(prefijo.count))
        }
        return nil
    }

    private static func contenidoNumerado(_ linea: String) -> (Int, String)? {
        guard let expresion = try? NSRegularExpression(
            pattern: #"^(\d+)[.)]\s+(.+)$"#),
              let coincidencia = expresion.firstMatch(
                in: linea, range: NSRange(linea.startIndex..., in: linea)),
              let rangoNumero = Range(coincidencia.range(at: 1), in: linea),
              let rangoTexto = Range(coincidencia.range(at: 2), in: linea),
              let numero = Int(linea[rangoNumero]) else { return nil }
        return (numero, String(linea[rangoTexto]))
    }

    private static func acomodarParrafoLargo(_ texto: String) -> [Self] {
        var frases: [String] = []
        texto.enumerateSubstrings(
            in: texto.startIndex..<texto.endIndex,
            options: [.bySentences, .substringNotRequired]) { _, rango, _, _ in
                let frase = String(texto[rango])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !frase.isEmpty { frases.append(frase) }
            }
        guard frases.count > 1 else {
            return [Self(estilo: .parrafo, texto: texto)]
        }

        var resultado = [
            Self(estilo: .titulo, texto: "Veredicto"),
            Self(estilo: .destacado, texto: frases.removeFirst()),
            Self(estilo: .titulo, texto: "Análisis")
        ]
        while !frases.isEmpty {
            let grupo = frases.prefix(2).joined(separator: " ")
            resultado.append(Self(estilo: .parrafo, texto: grupo))
            frases.removeFirst(min(2, frases.count))
        }
        return resultado
    }
}

#Preview {
    ClaroInteligenteView()
}
