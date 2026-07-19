import Foundation

enum FechaAnalisisClaro {
    static let claveActiva = "modoHistoricoActivo"
    static let claveFecha = "fechaAnalisisReferencia"

    static var actual: Date {
        guard UserDefaults.standard.bool(forKey: claveActiva) else { return .now }
        let valor = UserDefaults.standard.double(forKey: claveFecha)
        return valor > 0 ? Date(timeIntervalSince1970: valor) : .now
    }
}
