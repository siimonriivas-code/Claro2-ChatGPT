//
//  TarjetaDetalleView.swift
//  Claro — Carpeta: Vistas/CuentasYTarjetas
//  ⚠️ REEMPLAZA al existente.
//
//  Novedad: botón para IMPORTAR el estado de cuenta en PDF.
//

import SwiftUI
import SwiftData

struct TarjetaDetalleView: View {
    let tarjeta: TarjetaCredito

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    @State private var mostrandoNuevoCorte = false
    @State private var mostrandoPago = false
    @State private var mostrandoImportador = false
    @State private var mostrandoEdicion = false
    @State private var confirmandoEliminacion = false
    @State private var animarBarraDeUso = false
    @State private var inclinacion: CGSize = .zero

    /// Qué fracción del límite está usada (0 a 1).
    private var usoDeLimite: Double {
        guard tarjeta.limiteCredito > 0 else { return 0 }
        return min(1, max(0, tarjeta.deudaCalculada / tarjeta.limiteCredito))
    }

    /// Verde hasta 50%, ámbar hasta 80%, rojo de ahí en adelante.
    private var colorDeUso: Color {
        usoDeLimite < 0.5 ? Tema.positivo
        : usoDeLimite < 0.8 ? Tema.advertencia
        : Tema.urgente
    }

    /// Convierte el arrastre en grados, con tope de ±10°.
    private func gradosDeInclinacion(_ desplazamiento: CGFloat) -> Double {
        max(-10, min(10, Double(desplazamiento) / 15))
    }

    private var estadosOrdenados: [EstadoDeCuenta] {
        tarjeta.estadosDeCuenta.sorted { $0.fechaCorte > $1.fechaCorte }
    }

    private var movimientosOrdenados: [Movimiento] {
        tarjeta.movimientos.sorted { $0.fecha > $1.fecha }
    }

    private var movimientosRecientes: [Movimiento] {
        Array(movimientosOrdenados.prefix(5))
    }

    private var planesOrdenados: [PlanMSI] {
        tarjeta.planesMSI.sorted {
            if $0.estaConcluidoReal != $1.estaConcluidoReal {
                return !$0.estaConcluidoReal   // activos primero
            }
            return $0.fechaCompra > $1.fechaCompra
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // La tarjeta se inclina en 3D al arrastrar el dedo sobre
                // ella, como si la giraras en la mano; al soltar, regresa.
                TarjetaVisual(tarjeta: tarjeta)
                    .rotation3DEffect(.degrees(gradosDeInclinacion(-inclinacion.height)),
                                      axis: (x: 1, y: 0, z: 0))
                    .rotation3DEffect(.degrees(gradosDeInclinacion(inclinacion.width)),
                                      axis: (x: 0, y: 1, z: 0))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { valor in
                                inclinacion = valor.translation
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.4,
                                                      dampingFraction: 0.5)) {
                                    inclinacion = .zero
                                }
                            }
                    )

                HStack(spacing: 16) {
                    Panel {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DEUDA TOTAL")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Tema.textoSecundario)
                            Text(tarjeta.deudaCalculada.comoDinero)
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(Tema.textoPrincipal)
                        }
                    }
                    Panel {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DISPONIBLE")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Tema.textoSecundario)
                            Text(tarjeta.creditoDisponible.comoDinero)
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(Tema.positivo)
                        }
                    }
                }

                // ── Barra de uso del límite (se llena al abrir) ──
                Panel {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("USO DEL LÍMITE")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Tema.textoSecundario)
                            Spacer()
                            Text("\(Int(usoDeLimite * 100))%")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(colorDeUso)
                                .contentTransition(.numericText())
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Tema.panelElevado)
                                if usoDeLimite > 0 {
                                    Capsule()
                                        .fill(colorDeUso)
                                        .frame(width: max(8, geo.size.width
                                               * (animarBarraDeUso ? usoDeLimite : 0)))
                                }
                            }
                        }
                        .frame(height: 8)
                        Text("De un límite de \(tarjeta.limiteCredito.comoDinero)")
                            .font(.caption2)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                }
                .onAppear {
                    withAnimation(.spring(response: 0.9, dampingFraction: 0.85)
                                    .delay(0.15)) {
                        animarBarraDeUso = true
                    }
                }

                HStack(spacing: 12) {
                    botonAccion(titulo: "Registrar pago",
                                icono: "checkmark.circle.fill",
                                color: Tema.positivo) { mostrandoPago = true }
                    botonAccion(titulo: "Registrar corte",
                                icono: "scissors",
                                color: Tema.acento) { mostrandoNuevoCorte = true }
                }

                Button {
                    mostrandoImportador = true
                } label: {
                    HStack {
                        Image(systemName: "doc.viewfinder")
                        Text("Importar estado de cuenta (PDF)")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Tema.advertencia)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Tema.advertencia.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if let vigente = tarjeta.estadoDeCuentaVigente {
                    TituloSeccion(texto: "Corte vigente")
                    panelEstadoDeCuenta(vigente, destacado: true)
                } else {
                    Panel {
                        Text("Aún no registras ningún corte de esta tarjeta. Cuando tu banco genere el estado de cuenta, captúralo con \"Registrar corte\".")
                            .font(.footnote)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                }

                // ── Meses sin intereses ──
                if !planesOrdenados.isEmpty {
                    TituloSeccion(texto: "Compras a meses")
                    ForEach(planesOrdenados) { plan in
                        NavigationLink {
                            PlanMSIDetalleView(plan: plan)
                        } label: {
                            panelPlanMSI(plan)
                        }
                        .buttonStyle(.plain)
                    }
                }

                TituloSeccion(texto: "Periodo actual (aún sin cortar)")
                let compras = tarjeta.comprasDelPeriodoActual
                if compras.isEmpty {
                    Panel {
                        Text("Sin compras nuevas desde el último corte.")
                            .font(.footnote)
                            .foregroundStyle(Tema.textoSecundario)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Panel {
                        VStack(spacing: 0) {
                            ForEach(compras) { compra in
                                FilaMovimiento(movimiento: compra)
                                if compra.id != compras.last?.id {
                                    Divider().overlay(Tema.panelElevado)
                                }
                            }
                        }
                    }
                }

                // ── Todos los movimientos (compras regulares incluidas) ──
                if !movimientosRecientes.isEmpty {
                    TituloSeccion(texto: "Movimientos de la tarjeta")
                    Panel {
                        VStack(spacing: 0) {
                            ForEach(movimientosRecientes) { movimiento in
                                FilaMovimiento(movimiento: movimiento)
                                if movimiento.id != movimientosRecientes.last?.id {
                                    Divider().overlay(Tema.panelElevado)
                                }
                            }
                        }
                    }
                    NavigationLink {
                        MovimientosTarjetaView(tarjeta: tarjeta)
                    } label: {
                        Panel {
                            HStack {
                                Text("Ver todos los movimientos (\(movimientosOrdenados.count))")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Tema.acento)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Tema.textoSecundario)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                if estadosOrdenados.count > 1 {
                    TituloSeccion(texto: "Cortes anteriores")
                    ForEach(estadosOrdenados.dropFirst()) { estado in
                        panelEstadoDeCuenta(estado, destacado: false)
                    }
                }
            }
            .padding(16)
        }
        .background(Tema.fondo.ignoresSafeArea())
        .navigationTitle(tarjeta.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        mostrandoEdicion = true
                    } label: {
                        Label("Editar tarjeta", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) {
                        confirmandoEliminacion = true
                    } label: {
                        Label("Eliminar tarjeta", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Tema.textoSecundario)
                }
            }
        }
        .sheet(isPresented: $mostrandoEdicion) {
            EditarTarjetaView(tarjeta: tarjeta)
        }
        .confirmationDialog("¿Eliminar esta tarjeta?",
                            isPresented: $confirmandoEliminacion,
                            titleVisibility: .visible) {
            Button("Sí, eliminar tarjeta con todo su historial",
                   role: .destructive) { eliminarTarjeta() }
            Button("No", role: .cancel) { }
        } message: {
            Text("Se eliminarán la tarjeta, sus \(tarjeta.movimientos.count) movimientos, sus estados de cuenta y sus planes a meses. Esta acción no se puede deshacer.")
        }
        .sheet(isPresented: $mostrandoNuevoCorte) {
            NuevoEstadoDeCuentaView(tarjeta: tarjeta)
        }
        .sheet(isPresented: $mostrandoPago) {
            PagoTarjetaView(tarjetaInicial: tarjeta)
        }
        .sheet(isPresented: $mostrandoImportador) {
            ImportarEstadoView(tarjeta: tarjeta)
        }
    }

    // MARK: - Eliminar tarjeta

    private func eliminarTarjeta() {
        for movimiento in tarjeta.movimientos {
            if let compartida = movimiento.compraCompartida {
                for parte in compartida.participaciones { contexto.delete(parte) }
                movimiento.compraCompartida = nil
                contexto.delete(compartida)
            }
            contexto.delete(movimiento)
        }
        // Estados de cuenta y planes (con sus mensualidades) se van en cascada
        contexto.delete(tarjeta)
        cerrar()
    }

    // MARK: - Panel de un plan MSI (Ley 3 a la vista)
    private func panelPlanMSI(_ plan: PlanMSI) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(plan.detalle.isEmpty ? "Compra a MSI" : plan.detalle)
                        .font(.headline)
                        .foregroundStyle(Tema.textoPrincipal)
                    Spacer()
                    Pildora(texto: plan.estaConcluidoReal ? "Liquidada" : "Activa",
                            color: plan.estaConcluidoReal ? Tema.positivo : Tema.advertencia)
                }
                HStack(spacing: 12) {
                    Label("Generadas \(plan.generadas)/\(plan.numeroMeses)",
                          systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(Tema.acento)
                    Label("Cubiertas \(plan.cubiertasReal)/\(plan.numeroMeses)",
                          systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(Tema.positivo)
                    Spacer()
                    Text("\(plan.mensualidadTipica.comoDinero)/mes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Tema.textoSecundario)
                }
            }
        }
    }

    private func panelEstadoDeCuenta(_ estado: EstadoDeCuenta,
                                     destacado: Bool) -> some View {
        let (color, icono) = semaforo(estado.situacion)

        return Panel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(estado.situacion.titulo, systemImage: icono)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                    Spacer()
                    if estado.situacion != .cubierto {
                        Pildora(texto: estado.diasParaVencer >= 0
                                ? "\(estado.diasParaVencer) días"
                                : "Vencido",
                                color: color)
                    }
                }

                Divider().overlay(Tema.panelElevado)

                filaDato("Corte", estado.fechaCorte.formatted(date: .abbreviated, time: .omitted))
                filaDato("Fecha límite", estado.fechaLimitePago.formatted(date: .abbreviated, time: .omitted))
                filaDato("Saldo al corte", estado.saldoAlCorte.comoDinero)
                filaDato("Para no generar intereses", estado.pagoParaNoGenerarIntereses.comoDinero)
                filaDato("Pagado (pagos reales)", estado.pagadoDelPeriodo.comoDinero)

                if !estado.mensualidadesIncluidas.isEmpty {
                    filaDato("Mensualidades MSI incluidas",
                             "\(estado.mensualidadesIncluidas.count)")
                }

                if destacado {
                    HStack {
                        Text("FALTA POR CUBRIR")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Tema.textoSecundario)
                        Spacer()
                        Text(estado.faltaPorCubrir.comoDinero)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(estado.faltaPorCubrir > 0 ? color : Tema.positivo)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private func filaDato(_ titulo: String, _ valor: String) -> some View {
        HStack {
            Text(titulo)
                .font(.footnote)
                .foregroundStyle(Tema.textoSecundario)
            Spacer()
            Text(valor)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Tema.textoPrincipal)
        }
    }

    private func semaforo(_ situacion: SituacionEstadoDeCuenta) -> (Color, String) {
        switch situacion {
        case .cubierto:             return (Tema.positivo, "checkmark.circle.fill")
        case .pendiente:            return (Tema.advertencia, "clock.fill")
        case .parcialmenteCubierto: return (Tema.advertencia, "circle.lefthalf.filled")
        case .vencidoSinCubrir:     return (Tema.urgente, "exclamationmark.triangle.fill")
        }
    }

    private func botonAccion(titulo: String, icono: String, color: Color,
                             accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack {
                Image(systemName: icono)
                Text(titulo)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(Presionable())
    }
}
