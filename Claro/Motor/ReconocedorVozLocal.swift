//
//  ReconocedorVozLocal.swift
//  Claro
//
//  Dictado con Speech de Apple forzado a ejecutarse en el dispositivo.
//

import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class ReconocedorVozLocal: NSObject, ObservableObject {
    @Published var texto = ""
    @Published var estaEscuchando = false
    @Published var aviso: String?

    private let audio = AVAudioEngine()
    private let reconocedor = SFSpeechRecognizer(locale: Locale(identifier: "es-MX"))
    private var solicitud: SFSpeechAudioBufferRecognitionRequest?
    private var tarea: SFSpeechRecognitionTask?
    private var tieneTap = false

    var disponibleEnDispositivo: Bool {
        reconocedor?.supportsOnDeviceRecognition == true
    }

    func alternar() async {
        if estaEscuchando {
            detener()
        } else {
            await comenzar()
        }
    }

    func detener() {
        if audio.isRunning { audio.stop() }
        solicitud?.endAudio()
        if tieneTap {
            audio.inputNode.removeTap(onBus: 0)
            tieneTap = false
        }
        tarea?.cancel()
        tarea = nil
        solicitud = nil
        estaEscuchando = false
        try? AVAudioSession.sharedInstance().setActive(false,
                                                       options: .notifyOthersOnDeactivation)
    }

    private func comenzar() async {
        aviso = nil
        guard disponibleEnDispositivo else {
            aviso = "El dictado local no está disponible en este iPhone. Puedes escribir la pregunta."
            return
        }
        guard await permisoDeVoz() else {
            aviso = "Activa Reconocimiento de voz para Claro en Ajustes."
            return
        }
        guard await permisoDeMicrofono() else {
            aviso = "Activa el micrófono para Claro en Ajustes."
            return
        }

        detener()
        texto = ""
        let nuevaSolicitud = SFSpeechAudioBufferRecognitionRequest()
        nuevaSolicitud.shouldReportPartialResults = true
        nuevaSolicitud.requiresOnDeviceRecognition = true
        solicitud = nuevaSolicitud

        do {
            let sesion = AVAudioSession.sharedInstance()
            try sesion.setCategory(.record, mode: .measurement,
                                   options: [.duckOthers])
            try sesion.setActive(true, options: .notifyOthersOnDeactivation)

            let entrada = audio.inputNode
            let formato = entrada.outputFormat(forBus: 0)
            guard formato.sampleRate > 0 else {
                aviso = "No pude iniciar el micrófono."
                detener()
                return
            }
            entrada.installTap(onBus: 0, bufferSize: 1_024, format: formato) {
                [weak nuevaSolicitud] buffer, _ in
                nuevaSolicitud?.append(buffer)
            }
            tieneTap = true
            audio.prepare()
            try audio.start()
            estaEscuchando = true

            tarea = reconocedor?.recognitionTask(with: nuevaSolicitud) { [weak self] resultado, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let resultado {
                        self.texto = resultado.bestTranscription.formattedString
                    }
                    if resultado?.isFinal == true || error != nil {
                        self.detener()
                    }
                }
            }
        } catch {
            aviso = "No pude iniciar el dictado local. Puedes escribir la pregunta."
            detener()
        }
    }

    private func permisoDeVoz() async -> Bool {
        await withCheckedContinuation { continuacion in
            SFSpeechRecognizer.requestAuthorization { estado in
                continuacion.resume(returning: estado == .authorized)
            }
        }
    }

    private func permisoDeMicrofono() async -> Bool {
        await withCheckedContinuation { continuacion in
            AVAudioApplication.requestRecordPermission { permitido in
                continuacion.resume(returning: permitido)
            }
        }
    }
}
