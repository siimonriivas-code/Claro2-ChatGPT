//
//  BienvenidaClaroView.swift
//  Claro
//

import SwiftUI
import SwiftData

struct BienvenidaClaroView: View {
    let terminar: () -> Void

    @Query private var bancos: [Banco]
    @Query private var cuentas: [CuentaBancaria]
    @Query private var tarjetas: [TarjetaCredito]
    @Query private var personas: [Persona]

    @State private var pagina = 0
    @State private var nuevoBanco = false
    @State private var nuevaCuenta = false
    @State private var nuevaTarjeta = false
    @State private var nuevaPersona = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TabView(selection: $pagina) {
                    paginaInformativa(
                        icono: "wallet.bifold.fill",
                        titulo: "Tu dinero, claro",
                        texto: "Organiza cuentas, tarjetas, pagos, compras compartidas y deudas desde un solo lugar.")
                        .tag(0)
                    paginaInformativa(
                        icono: "lock.shield.fill",
                        titulo: "Privado por diseño",
                        texto: "Los estados de cuenta se leen dentro de tu iPhone. Puedes proteger la app con Face ID y crear respaldos cuando quieras.")
                        .tag(1)
                    paginaConfiguracion.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                HStack {
                    if pagina > 0 {
                        Button("Atrás") { withAnimation { pagina -= 1 } }
                    }
                    Spacer()
                    if pagina < 2 {
                        Button("Continuar") { withAnimation { pagina += 1 } }
                            .buttonStyle(.borderedProminent)
                            .tint(Tema.positivo)
                    } else {
                        Button("Entrar a Claro") { terminar() }
                            .buttonStyle(.borderedProminent)
                            .tint(Tema.positivo)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
            }
            .background(FondoClaro())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Omitir") { terminar() }
                }
            }
            .sheet(isPresented: $nuevoBanco) { NuevoBancoView() }
            .sheet(isPresented: $nuevaCuenta) { NuevaCuentaView() }
            .sheet(isPresented: $nuevaTarjeta) { NuevaTarjetaView() }
            .sheet(isPresented: $nuevaPersona) { NuevaPersonaView() }
        }
        .aparienciaDeLaApp()
    }

    private func paginaInformativa(icono: String, titulo: String,
                                   texto: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Tema.gradienteMarca)
                    .frame(width: 148, height: 148)
                    .blur(radius: 22)
                    .opacity(0.24)
                Image(systemName: icono)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 116, height: 116)
                    .background(Tema.gradienteMarca,
                                in: RoundedRectangle(cornerRadius: 34,
                                                     style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 34,
                                              style: .continuous)
                        .strokeBorder(.white.opacity(0.30), lineWidth: 1))
                    .shadow(color: Tema.acento.opacity(0.25), radius: 24, y: 12)
            }
            Text(titulo)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Tema.textoPrincipal)
            Text(texto)
                .font(.body)
                .foregroundStyle(Tema.textoSecundario)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
            Spacer()
        }
    }

    private var paginaConfiguracion: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Prepara tu espacio")
                    .font(.largeTitle.bold())
                Text("Puedes completar esto ahora o continuar y hacerlo después.")
                    .foregroundStyle(Tema.textoSecundario)

                paso("Agregar un banco", completo: !bancos.isEmpty,
                     habilitado: true) { nuevoBanco = true }
                paso("Agregar una cuenta", completo: !cuentas.isEmpty,
                     habilitado: !bancos.isEmpty) { nuevaCuenta = true }
                paso("Agregar una tarjeta", completo: !tarjetas.isEmpty,
                     habilitado: !bancos.isEmpty) { nuevaTarjeta = true }
                paso("Agregar personas para compartir",
                     completo: !personas.isEmpty, habilitado: true) {
                    nuevaPersona = true
                }
            }
            .padding(24)
        }
    }

    private func paso(_ titulo: String, completo: Bool, habilitado: Bool,
                      accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: 14) {
                Image(systemName: completo ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(completo ? Tema.positivo : Tema.textoSecundario)
                Text(titulo).foregroundStyle(Tema.textoPrincipal)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Tema.textoSecundario)
            }
            .padding(16)
            .background(Tema.panel,
                        in: RoundedRectangle(cornerRadius: 20,
                                             style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Tema.gradienteBorde, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
        .disabled(!habilitado)
        .opacity(habilitado ? 1 : 0.5)
    }
}
