import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ImportarEstadoDebitoView: View {
    let cuenta: CuentaBancaria
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @State private var seleccionando = false
    @State private var procesando = false
    @State private var archivo = ""
    @State private var resultado: ResultadoEstadoDebito?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { seleccionando = true } label: {
                        Label(archivo.isEmpty ? "Seleccionar PDF" : archivo, systemImage: "doc.text.viewfinder")
                    }
                    if procesando { ProgressView("Leyendo en el iPhone…") }
                }
                if let resultado {
                    Section("Conciliación") {
                        LabeledContent("Banco", value: resultado.banco)
                        if let saldoFinal = resultado.saldoFinal {
                            LabeledContent("Saldo final del PDF", value: saldoFinal.comoDinero)
                            LabeledContent("Saldo actual en Claro", value: cuenta.saldoCalculado.comoDinero)
                            let diferencia = (saldoFinal - cuenta.saldoCalculado).redondeadoAMoneda
                            LabeledContent("Diferencia", value: diferencia.comoDinero)
                                .foregroundStyle(abs(diferencia) < 0.01 ? Tema.positivo : Tema.advertencia)
                        }
                    }
                    Section("Movimientos detectados (\(resultado.movimientos.count))") {
                        ForEach(Array(resultado.movimientos.enumerated()), id: \.element.id) { indice, movimiento in
                            Toggle(isOn: Binding(
                                get: { self.resultado?.movimientos[indice].seleccionado ?? false },
                                set: { self.resultado?.movimientos[indice].seleccionado = $0 })) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(movimiento.detalle).lineLimit(2)
                                    Text("\(movimiento.fecha.formatted(date: .abbreviated, time: .omitted)) · \(movimiento.esIngreso ? "+" : "−")\(movimiento.monto.comoDinero)")
                                        .font(.caption).foregroundStyle(movimiento.esIngreso ? Tema.positivo : Tema.textoSecundario)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Importar cuenta")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importar") { importar() }
                        .disabled(resultado?.movimientos.contains(where: \.seleccionado) != true)
                }
            }
            .fileImporter(isPresented: $seleccionando, allowedContentTypes: [.pdf]) { respuesta in
                guard case .success(let url) = respuesta else { return }
                archivo = url.lastPathComponent; procesando = true
                Task {
                    let paginas = await ExtractorPDF.paginas(de: url)
                    let analisis = AnalizadorEstadoDebito.analizar(texto: paginas.joined(separator: "\n"))
                    await MainActor.run {
                        resultado = desmarcarDuplicados(analisis); procesando = false
                        if analisis.movimientos.isEmpty { error = "No encontré filas bancarias confiables. No se guardó nada." }
                    }
                }
            }
            .alert("No se pudo importar", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("Entendido", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        }.aparienciaDeLaApp()
    }

    private func desmarcarDuplicados(_ analisis: ResultadoEstadoDebito) -> ResultadoEstadoDebito {
        var copia = analisis
        for indice in copia.movimientos.indices {
            let candidato = copia.movimientos[indice]
            copia.movimientos[indice].seleccionado = !cuenta.movimientos.contains {
                $0.cuentaParaCalculos && Calendar.current.isDate($0.fecha, inSameDayAs: candidato.fecha)
                    && abs($0.monto - candidato.monto) < 0.01
                    && MotorClaroInteligente.normalizarParaBusqueda($0.detalle)
                        == MotorClaroInteligente.normalizarParaBusqueda(candidato.detalle)
            }
        }
        return copia
    }

    private func importar() {
        guard let resultado else { return }
        let id = UUID()
        let elegidos = resultado.movimientos.filter(\.seleccionado)
        let saldoAntes = cuenta.saldoCalculado
        for fila in elegidos {
            let movimiento = Movimiento(tipo: fila.esIngreso ? .ingreso : .gasto,
                                        monto: fila.monto, fecha: fila.fecha,
                                        detalle: fila.detalle, cuenta: cuenta)
            movimiento.importacionID = id
            contexto.insert(movimiento)
        }
        let saldoTrasImportar = saldoAntes
            + elegidos.reduce(0) { $0 + ($1.esIngreso ? $1.monto : -$1.monto) }
        contexto.insert(ConciliacionCuentaBancaria(
            bancoDetectado: resultado.banco, archivoOrigen: archivo, cuenta: cuenta,
            fechaInicial: resultado.fechaInicial, fechaFinal: resultado.fechaFinal,
            saldoInicialReportado: resultado.saldoInicial, saldoFinalReportado: resultado.saldoFinal,
            saldoCalculadoAlImportar: saldoTrasImportar,
            movimientosImportados: elegidos.count, importacionID: id))
        try? contexto.save(); cerrar()
    }
}
