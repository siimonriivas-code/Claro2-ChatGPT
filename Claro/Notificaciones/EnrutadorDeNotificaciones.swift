//
//  EnrutadorDeNotificaciones.swift
//  Claro
//
//  Traduce el toque de una notificación en una pantalla concreta de Claro.
//  El identificador guardado en la notificación es estable y no contiene
//  importes ni información bancaria sensible.
//

import Combine
import CloudKit
import Foundation
import UIKit
import UserNotifications

enum TipoDestinoNotificacion: String {
    case importarEstado
    case pagarTarjeta
    case verTarjeta
    case verPersona
    case verPersonas
}

struct DestinoNotificacionClaro: Identifiable, Equatable {
    let id = UUID()
    let tipo: TipoDestinoNotificacion
    let identificador: String?
}

@MainActor
final class EnrutadorDeNotificaciones: ObservableObject {
    static let compartido = EnrutadorDeNotificaciones()

    @Published var destino: DestinoNotificacionClaro?

    private init() { }

    func abrir(datos: [AnyHashable: Any]) {
        guard let valor = datos[ProgramadorDeNotificaciones.claveDestino]
                as? String,
              let tipo = TipoDestinoNotificacion(rawValue: valor) else { return }
        destino = DestinoNotificacionClaro(
            tipo: tipo,
            identificador: datos[ProgramadorDeNotificaciones.claveIdentificador]
                as? String
        )
    }
}

/// El delegado vive desde el arranque de la app, incluso cuando Claro se abre
/// desde una notificación con la pantalla bloqueada.
final class DelegadoAplicacionClaro: NSObject,
    UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let centro = UNUserNotificationCenter.current()
        centro.delegate = self
        ProgramadorDeNotificaciones.configurarCategorias()
        return true
    }

    /// SwiftUI no crea un delegado de escena por sí solo. CloudKit entrega
    /// aquí las invitaciones aceptadas, por lo que configuramos uno sin
    /// sustituir ni administrar la ventana que SwiftUI crea.
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuracion = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        if connectingSceneSession.role == .windowApplication {
            configuracion.delegateClass = DelegadoEscenaClaro.self
        }
        return configuracion
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier != UNNotificationDismissActionIdentifier
        else { return }
        let datos = response.notification.request.content.userInfo
        await MainActor.run {
            EnrutadorDeNotificaciones.compartido.abrir(datos: datos)
        }
    }
}

/// Recibe una invitación tanto si Claro estaba abierto como si iOS lo lanzó
/// desde el enlace de CloudKit.
final class DelegadoEscenaClaro: UIResponder, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            aceptar(metadata)
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        aceptar(cloudKitShareMetadata)
    }

    private func aceptar(_ metadata: CKShare.Metadata) {
        Task { @MainActor in
            await AdministradorClaroFamilia.aceptar(metadata)
        }
    }
}
