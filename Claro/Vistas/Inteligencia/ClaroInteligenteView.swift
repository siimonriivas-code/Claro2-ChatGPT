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

    @Query private var cuentas: [CuentaBancaria]
    @Query private var tarjetas: [TarjetaCredito]
    @Query private var personas: [Persona]
    @Query private var planes: [PlanMSI]
    @Query private var deudas: [Deuda]
    @Query(sort: \Movimiento.fecha, order: .reverse) private var movimientos: [Movimiento]

    @AppStorage("montosOcultos") private var montosOcultos = false
    @StateObject private var voz = ReconocedorVozLocal()
    @State private var mensajes: [MensajeClaro] = []
    @State private var pregunta = ""
    @State private var pensando = false
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
            planes: planes, deudas: deudas, movimientos: movimientos)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                encabezado
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
                        cerrar()
                    }
                    .foregroundStyle(Tema.positivo)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Pildora(texto: ClaroInteligenciaLocal.nombreMotorDisponible,
                            color: Tema.acento)
                }
            }
        }
        .aparienciaDeLaApp()
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
    }

    private var encabezado: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Tema.acento)
                    .frame(width: 42, height: 42)
                    .background(Tema.acento.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pregúntame sin llenar formularios")
                        .font(.headline)
                        .foregroundStyle(Tema.textoPrincipal)
                    Text("Tus datos y el análisis permanecen en este iPhone")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                miniIndicador(titulo: "Riesgo", valor: resumen.nivelRiesgo.rawValue,
                              color: colorRiesgo)
                miniIndicador(titulo: "Cierre", valor: resumen.proyeccionFinDeMes.comoDinero,
                              color: resumen.proyeccionFinDeMes >= 0 ? Tema.positivo : Tema.urgente)
                miniIndicador(titulo: "Confianza", valor: resumen.confianza.capitalized,
                              color: Tema.acento)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Tema.panel)
    }

    private func miniIndicador(titulo: String, valor: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(titulo.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Tema.textoSecundario)
            Text(valor)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Tema.panelElevado, in: RoundedRectangle(cornerRadius: 12))
    }

    private var colorRiesgo: Color {
        switch resumen.nivelRiesgo {
        case .bajo: return Tema.positivo
        case .moderado: return Tema.advertencia
        case .alto, .critico: return Tema.urgente
        }
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
                            Text("Analizando todos tus datos…")
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
        VStack(alignment: .leading, spacing: 16) {
            Panel {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dime lo que quieres saber")
                        .font(.title3.bold())
                        .foregroundStyle(Tema.textoPrincipal)
                    Text("Puedo evaluar tu panorama, proyectar el mes, revisar deudas y opinar si un préstamo parece viable. Contesto primero y explico después.")
                        .font(.subheadline)
                        .foregroundStyle(Tema.textoSecundario)
                }
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
                        .padding(14)
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
                Text(textoVisible(mensaje.texto))
                    .font(.body)
                    .foregroundStyle(mensaje.esUsuario ? Color.white : Tema.textoPrincipal)
                    .textSelection(.enabled)
                if let fuente = mensaje.fuente {
                    Label(fuente.rawValue,
                          systemImage: fuente == .appleIntelligence ? "apple.intelligence" : "function")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Tema.textoSecundario)
                }
            }
            .padding(14)
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
                TextField("Pregunta sobre tus finanzas", text: $pregunta, axis: .vertical)
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
        .padding(.vertical, 10)
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

        let historial = mensajes.map {
            TurnoConversacionClaro(esUsuario: $0.esUsuario, texto: $0.texto)
        }
        mensajes.append(MensajeClaro(esUsuario: true, texto: limpia, fuente: nil))
        pensando = true
        let fotoFinanciera = resumen

        Task {
            let respuesta = await ClaroInteligenciaLocal.responder(
                pregunta: limpia, resumen: fotoFinanciera, historial: historial)
            mensajes.append(MensajeClaro(esUsuario: false,
                                          texto: respuesta.texto,
                                          fuente: respuesta.fuente))
            pensando = false
        }
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

private struct MensajeClaro: Identifiable {
    let id = UUID()
    let esUsuario: Bool
    let texto: String
    let fuente: FuenteRespuestaClaro?
}

#Preview {
    ClaroInteligenteView()
}
