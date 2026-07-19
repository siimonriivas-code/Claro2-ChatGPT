import Foundation
import SwiftData

enum MigradorDatosClaro {
    private static let clave = "versionModeloDatosClaro"
    static let versionActual = 2

    /// Las etapas son idempotentes: interrumpir la app no deja una migración
    /// a medias y volver a abrirla es seguro.
    @MainActor static func ejecutarSiHaceFalta(contexto: ModelContext) {
        var version = UserDefaults.standard.integer(forKey: clave)
        if version < 1 {
            // La versión original no almacenaba número de esquema.
            version = 1
            UserDefaults.standard.set(version, forKey: clave)
        }
        if version < 2 {
            // Los nuevos campos financieros son opcionales y los modelos
            // avanzados nacen vacíos; SwiftData realiza la migración ligera.
            // Esta etapa deja el punto explícito para futuras normalizaciones.
            try? contexto.save()
            version = 2
            UserDefaults.standard.set(version, forKey: clave)
        }
    }
}
