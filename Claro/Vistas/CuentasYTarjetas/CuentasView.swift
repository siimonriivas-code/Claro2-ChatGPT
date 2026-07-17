//
//  CuentasView.swift
//  Claro — Carpeta: Vistas/CuentasYTarjetas
//  ⚠️ REEMPLAZA al existente.
//
//  Novedad: cada banco tiene su menú ••• para editarlo o eliminarlo
//  (solo se puede eliminar si ya no tiene cuentas ni tarjetas).
//  Los bancos vacíos ahora también se muestran, para poder gestionarlos.
//

import SwiftUI
import SwiftData

struct CuentasView: View {
    @Environment(\.modelContext) private var contexto

    @Query(sort: \Banco.nombre) private var bancos: [Banco]
    @Query private var cuentas: [CuentaBancaria]
    @Query(sort: \TarjetaCredito.nombre) private var tarjetas: [TarjetaCredito]
    @Query(sort: \Deuda.acreedor) private var deudas: [Deuda]

    @State private var mostrandoNuevoBanco = false
    @State private var mostrandoNuevaCuenta = false
    @State private var mostrandoNuevaTarjeta = false
    @State private var mostrandoNuevaDeuda = false
    @State private var bancoEditando: Banco?
    @State private var bancoEliminando: Banco?
    @State private var mostrandoBancoBloqueado = false

    /// Bancos cuyo mazo de tarjetas está desplegado en abanico.
    @State private var bancosDesplegados: Set<PersistentIdentifier> = []

    /// Enlace al estado desplegado/apilado del mazo de un banco.
    private func mazoDesplegado(_ banco: Banco) -> Binding<Bool> {
        Binding(
            get: { bancosDesplegados.contains(banco.persistentModelID) },
            set: { nuevo in
                if nuevo { bancosDesplegados.insert(banco.persistentModelID) }
                else { bancosDesplegados.remove(banco.persistentModelID) }
            })
    }

    private var saldoTotal: Double {
        cuentas.reduce(0) { $0 + $1.saldoCalculado }
    }

    private var deudaTotalTarjetas: Double {
        tarjetas.reduce(0) { $0 + $1.deudaCalculada }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if bancos.isEmpty {
                        estadoVacio
                    } else {
                        panelResumen

                        ForEach(bancos) { banco in
                            seccionBanco(banco)
                                .aparicionAlDesplazar()
                        }

                        if !deudas.isEmpty {
                            TituloSeccion(texto: "Deudas propias")
                            ForEach(deudas) { deuda in
                                NavigationLink {
                                    DeudaDetalleView(deuda: deuda)
                                } label: {
                                    filaDeuda(deuda)
                                }
                                .buttonStyle(Presionable())
                                .aparicionAlDesplazar()
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Tema.fondo.ignoresSafeArea())
            .navigationTitle("Cuentas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            mostrandoNuevoBanco = true
                        } label: {
                            Label("Nuevo banco", systemImage: "building.columns")
                        }
                        Button {
                            mostrandoNuevaCuenta = true
                        } label: {
                            Label("Nueva cuenta", systemImage: "wallet.pass")
                        }
                        .disabled(bancos.isEmpty)
                        Button {
                            mostrandoNuevaTarjeta = true
                        } label: {
                            Label("Nueva tarjeta de crédito", systemImage: "creditcard")
                        }
                        .disabled(bancos.isEmpty)
                        Button {
                            mostrandoNuevaDeuda = true
                        } label: {
                            Label("Nueva deuda propia", systemImage: "banknote")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Tema.positivo)
                    }
                }
            }
            .sheet(isPresented: $mostrandoNuevoBanco) { NuevoBancoView() }
            .sheet(isPresented: $mostrandoNuevaCuenta) { NuevaCuentaView() }
            .sheet(isPresented: $mostrandoNuevaTarjeta) { NuevaTarjetaView() }
            .sheet(isPresented: $mostrandoNuevaDeuda) { NuevaDeudaView() }
            .sheet(item: $bancoEditando) { banco in
                EditarBancoView(banco: banco)
            }
            .confirmationDialog("¿Eliminar este banco?",
                                isPresented: .constant(bancoEliminando != nil),
                                titleVisibility: .visible,
                                presenting: bancoEliminando) { banco in
                Button("Sí, eliminar \(banco.nombre)", role: .destructive) {
                    contexto.delete(banco)
                    bancoEliminando = nil
                }
                Button("No", role: .cancel) { bancoEliminando = nil }
            } message: { banco in
                Text("El banco \(banco.nombre) no tiene cuentas ni tarjetas, se puede eliminar con seguridad.")
            }
            .alert("Este banco todavía tiene cuentas o tarjetas",
                   isPresented: $mostrandoBancoBloqueado) {
                Button("Entendido", role: .cancel) { }
            } message: {
                Text("Para eliminar un banco, primero elimina (o cambia de banco) sus cuentas y tarjetas, desde el detalle de cada una.")
            }
        }
    }

    // MARK: - Resumen
    private var panelResumen: some View {
        Panel {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("EN CUENTAS")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Tema.textoSecundario)
                    Text(saldoTotal.comoDinero)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(Tema.positivo)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("DEUDA TARJETAS")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Tema.textoSecundario)
                    Text(deudaTotalTarjetas.comoDinero)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(deudaTotalTarjetas > 0
                                         ? Tema.advertencia : Tema.positivo)
                }
            }
        }
    }

    // MARK: - Un banco: logo, cuentas de débito y su mazo de tarjetas
    private func seccionBanco(_ banco: Banco) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 9) {
                // Tocar el nombre del banco despliega/apila su mazo,
                // igual que tocar las tarjetas.
                Button {
                    guard banco.tarjetas.count > 1 else { return }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        mazoDesplegado(banco).wrappedValue.toggle()
                    }
                } label: {
                    HStack(spacing: 9) {
                        LogoBanco(banco: banco)
                        Text(banco.nombre)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Tema.textoPrincipal)
                        if banco.tarjetas.count > 1 {
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Tema.textoSecundario)
                                .rotationEffect(.degrees(
                                    mazoDesplegado(banco).wrappedValue ? 180 : 0))
                        }
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Text(resumenBanco(banco))
                    .font(.caption2)
                    .foregroundStyle(Tema.textoSecundario)
                Menu {
                    Button {
                        bancoEditando = banco
                    } label: {
                        Label("Editar banco", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) {
                        if banco.cuentas.isEmpty && banco.tarjetas.isEmpty {
                            bancoEliminando = banco
                        } else {
                            mostrandoBancoBloqueado = true
                        }
                    } label: {
                        Label("Eliminar banco", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.subheadline)
                        .foregroundStyle(Tema.textoSecundario)
                }
            }
            .padding(.top, 8)

            ForEach(banco.cuentas) { cuenta in
                NavigationLink {
                    CuentaDetalleView(cuenta: cuenta)
                } label: {
                    Panel {
                        HStack(spacing: 12) {
                            Image(systemName: "wallet.pass.fill")
                                .font(.subheadline)
                                .foregroundStyle(Tema.positivo)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cuenta.nombre)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Tema.textoPrincipal)
                                Text(cuenta.tipo.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(Tema.textoSecundario)
                            }
                            Spacer()
                            Text(cuenta.saldoCalculado.comoDinero)
                                .font(.system(.body, design: .rounded).weight(.bold))
                                .foregroundStyle(cuenta.saldoCalculado >= 0
                                                 ? Tema.positivo : Tema.urgente)
                                .contentTransition(.numericText())
                        }
                    }
                }
                .buttonStyle(Presionable())
            }

            if !banco.tarjetas.isEmpty {
                MazoTarjetas(tarjetas: banco.tarjetas,
                             desplegado: mazoDesplegado(banco))
            }
        }
    }

    /// "1 cuenta · 3 tarjetas", omitiendo lo que esté en cero.
    private func resumenBanco(_ banco: Banco) -> String {
        var partes: [String] = []
        let c = banco.cuentas.count
        let t = banco.tarjetas.count
        if c > 0 { partes.append(c == 1 ? "1 cuenta" : "\(c) cuentas") }
        if t > 0 { partes.append(t == 1 ? "1 tarjeta" : "\(t) tarjetas") }
        return partes.isEmpty ? "sin cuentas" : partes.joined(separator: " · ")
    }

    // MARK: - Fila de deuda propia
    private func filaDeuda(_ deuda: Deuda) -> some View {
        Panel {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(deuda.acreedor)
                        .font(.headline)
                        .foregroundStyle(Tema.textoPrincipal)
                    Text(deuda.estaLiquidada
                         ? "Liquidada ✓"
                         : "Abonado \(deuda.totalAbonado.comoDinero) de \(deuda.montoOriginal.comoDinero)")
                        .font(.caption)
                        .foregroundStyle(deuda.estaLiquidada
                                         ? Tema.positivo : Tema.textoSecundario)
                }
                Spacer()
                Text(deuda.saldoRestante.comoDinero)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(deuda.estaLiquidada
                                     ? Tema.positivo : Tema.advertencia)
            }
        }
    }

    // MARK: - Cuando aún no hay nada
    private var estadoVacio: some View {
        Panel {
            VStack(spacing: 12) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Tema.acento)
                Text("Empieza dando de alta tu primer banco")
                    .font(.headline)
                    .foregroundStyle(Tema.textoPrincipal)
                    .multilineTextAlignment(.center)
                Text("Después agrégale sus cuentas y tarjetas. Desde ahí, el motor calculará todo.")
                    .font(.footnote)
                    .foregroundStyle(Tema.textoSecundario)
                    .multilineTextAlignment(.center)
                Button {
                    mostrandoNuevoBanco = true
                } label: {
                    Text("Agregar banco")
                        .font(.headline)
                        .foregroundStyle(Tema.fondo)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Tema.positivo, in: Capsule())
                }
                .buttonStyle(Presionable())
            }
            .frame(maxWidth: .infinity)
        }
    }
}
