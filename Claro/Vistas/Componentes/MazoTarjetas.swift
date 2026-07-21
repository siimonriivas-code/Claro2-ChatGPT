//
//  MazoTarjetas.swift
//  Claro — Carpeta: Vistas/Componentes
//
//  Las tarjetas de un banco apiladas como en tu cartera (estilo Wallet).
//  Cerrado: se asoma el borde superior de cada tarjeta.
//  Un toque las despliega en abanico (con vibración suave);
//  el botón "Apilar" las junta de nuevo.
//  Al tocar una tarjeta desplegada, "vuela" hacia su detalle (zoom).
//
//  Nota de construcción: cada tarjeta vive SIEMPRE dentro del mismo
//  NavigationLink (solo se desactiva cuando el mazo está cerrado).
//  Así la vista conserva su identidad y el resorte interpola de verdad
//  la posición: las tarjetas se deslizan, no "saltan".
//

import SwiftUI
import SwiftData

struct MazoTarjetas: View {
    let tarjetas: [TarjetaCredito]

    /// El estado vive en la pantalla padre: así el encabezado del banco
    /// también puede desplegar/apilar el mazo.
    @Binding var desplegado: Bool

    @State private var anchoDisponible: CGFloat = 350
    @Namespace private var espacioZoom

    private let asomo: CGFloat = 42        // franja visible de cada tarjeta trasera
    private let separacion: CGFloat = 12   // espacio entre tarjetas desplegadas

    private let resorte: Animation = .spring(response: 0.5, dampingFraction: 0.8)

    /// Altura real de una tarjeta al ancho actual (proporción física).
    private var alturaTarjeta: CGFloat {
        anchoDisponible / TarjetaVisual.proporcion
    }

    /// La más urgente al frente: vencidas primero, luego por días para
    /// vencer, y a igualdad, la de mayor deuda.
    private var ordenadas: [TarjetaCredito] {
        tarjetas.sorted { urgencia($0) < urgencia($1) }
    }

    private func urgencia(_ t: TarjetaCredito) -> Double {
        guard t.deudaCalculada > 0, let corte = t.estadoDeCuentaVigente else {
            return 100_000 - t.deudaCalculada / 1_000_000
        }
        switch corte.situacion {
        case .vencidoSinCubrir, .vencidoParcialmenteCubierto:
            return -1_000
        case .pendiente, .parcialmenteCubierto:
            return Double(corte.diasParaVencer)
        case .cubierto:                    return 50_000 - t.deudaCalculada / 1_000_000
        }
    }

    var body: some View {
        if ordenadas.count == 1, let unica = ordenadas.first {
            enlaceConZoom(unica) {
                TarjetaVisual(tarjeta: unica)
            }
            .buttonStyle(Presionable())
        } else {
            VStack(spacing: 10) {
                GlassEffectContainer {
                    ZStack(alignment: .top) {
                        ForEach(Array(ordenadas.enumerated().reversed()),
                                id: \.element.persistentModelID) { indice, tarjeta in
                            pieza(indice: indice, tarjeta: tarjeta)
                                .zIndex(Double(ordenadas.count - indice))
                        }
                    }
                }
                // alignment: .top es clave — el ZStack mide solo la altura
                // de una tarjeta (los offsets no cuentan para el layout),
                // así que sin esto el sistema lo centraba: hueco arriba
                // y tarjetas chocando con el siguiente banco abajo.
                .frame(height: alturaMazo, alignment: .top)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { nuevoAncho in
                    anchoDisponible = nuevoAncho
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // Cerrado, cualquier toque sobre el mazo lo despliega.
                    guard !desplegado else { return }
                    withAnimation(resorte) { desplegado = true }
                }

                if desplegado {
                    Button {
                        withAnimation(resorte) { desplegado = false }
                    } label: {
                        Label("Apilar", systemImage: "chevron.up")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Tema.textoSecundario)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Tema.panel, in: Capsule())
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: desplegado)
        }
    }

    private var alturaMazo: CGFloat {
        if desplegado {
            return alturaTarjeta * CGFloat(ordenadas.count)
                 + separacion * CGFloat(ordenadas.count - 1)
        }
        return alturaTarjeta + asomo * CGFloat(ordenadas.count - 1)
    }

    /// indice 0 = tarjeta al frente; las demás, atrás y asomadas arriba.
    private func pieza(indice: Int, tarjeta: TarjetaCredito) -> some View {
        let nivel = CGFloat(indice)

        return enlaceConZoom(tarjeta) {
            TarjetaVisual(tarjeta: tarjeta)
                .overlay(
                    // Las traseras se oscurecen un poco para dar profundidad
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.black.opacity(desplegado ? 0 : 0.16 * Double(indice)))
                )
        }
        .buttonStyle(Presionable())
        .allowsHitTesting(desplegado)
        .padding(.horizontal, desplegado ? 0 : nivel * 8)
        .offset(y: desplegado
                ? nivel * (alturaTarjeta + separacion)
                : (CGFloat(ordenadas.count - 1) - nivel) * asomo)
    }

    /// NavigationLink cuyo destino entra con zoom desde la propia tarjeta.
    private func enlaceConZoom<Etiqueta: View>(
        _ tarjeta: TarjetaCredito,
        @ViewBuilder etiqueta: () -> Etiqueta
    ) -> some View {
        NavigationLink {
            TarjetaDetalleView(tarjeta: tarjeta)
                .navigationTransition(.zoom(sourceID: tarjeta.persistentModelID,
                                            in: espacioZoom))
        } label: {
            etiqueta()
        }
        .matchedTransitionSource(id: tarjeta.persistentModelID, in: espacioZoom)
    }
}
