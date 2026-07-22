//
//  EnrutadorDeNotificaciones.swift
//  Claro
//
//  Traduce el toque de una notificación en una pantalla concreta de Claro.
//  El identificador guardado en la notificación es estable y no contiene
//  importes ni información bancaria sensible.
//

import Combine
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
