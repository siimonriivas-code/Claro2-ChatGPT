//
//  BloqueoView.swift
//  Claro — Carpeta: Vistas
//
//  La cortina de seguridad: cubre la app hasta verificar Face ID
//  o el código del iPhone.
//

import SwiftUI
import LocalAuthentication

struct BloqueoView: View {
    var alDesbloquear: () -> Void

    @State private var mensajeError: String?

    var body: some View {
        ZStack {
            Tema.fondo.ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    // Halo verde (diseño Claro Premium)
                    Circle()
                        .fill(RadialGradient(
                            colors: [Tema.positivo.opacity(0.20), .clear],
                            center: .center,
                            startRadius: 0, endRadius: 75))
                        .frame(width: 150, height: 150)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Tema.positivo)
                }

                Text("Claro")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Tema.textoPrincipal)

                Text("Tus finanzas están protegidas")
                    .font(.footnote)
                    .foregroundStyle(Tema.textoSecundario)

                if let mensajeError {
                    Text(mensajeError)
                        .font(.footnote)
                        .foregroundStyle(Tema.advertencia)
                }

                Button {
                    autenticar()
                } label: {
                    Label("Desbloquear", systemImage: "faceid")
                        .font(.headline)
                        .foregroundStyle(Tema.fondo)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Tema.positivo, in: Capsule())
                }
            }
        }
        .onAppear { autenticar() }
    }

    private func autenticar() {
        let contexto = LAContext()
        var error: NSError?

        // .deviceOwnerAuthentication = Face ID con respaldo de código
        if contexto.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            contexto.evaluatePolicy(.deviceOwnerAuthentication,
                                    localizedReason: "Desbloquear tus finanzas") { exito, _ in
                DispatchQueue.main.async {
                    if exito {
                        alDesbloquear()
                    } else {
                        mensajeError = "No se pudo verificar. Intenta de nuevo."
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                mensajeError = "El iPhone no tiene Face ID ni código disponible. Configúralo en Ajustes o desactiva el bloqueo de Claro desde Configuración."
            }
        }
    }
}
