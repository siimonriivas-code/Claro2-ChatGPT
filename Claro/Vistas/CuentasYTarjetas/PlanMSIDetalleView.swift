//
//  PlanMSIDetalleView.swift
//  Claro — Carpeta: Vistas/CuentasYTarjetas
//  ⚠️ REEMPLAZA al existente.
//
//  Novedad: botón "División de dueños" para asignar (o corregir) de
//  quién es un plan MSI YA EXISTENTE, aunque se haya importado sin
//  personas. La división queda como plantilla: los siguientes cortes
//  cargarán a cada persona su parte automáticamente.
//

import SwiftUI
import SwiftData

struct PlanMSIDetalleView: View {
    let plan: PlanMSI

    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    @Query(filter: #Predicate<Persona> { !$0.archivada }, sort: \Persona.nombre) private var personas: [Persona]

    @State private var mostrandoDivision = false
    @State private var partesEdicion: [PersistentIdentifier: Double] = [:]
    @State private var mostrandoCongelado = false
    @State private var confirmandoEliminacion = false
    @State private var congeladoTexto = ""

    /// La división actual del plan (vive en su movimiento ancla).
    private var compartidaExistente: CompraCompartida? {
        plan.movimientos.compactMap(\.compraCompartida).first
    }

    private var resumenDivision: String {
        guard let compartida = compartidaExistente,
              !compartida.participaciones.isEmpty else {
            return "100% mía · toca para compartir"
        }
        var nombres: [String] = []
        for parte in compartida.participaciones {
            if let nombre = parte.persona?.nombre, !nombres.contains(nombre) {
                nombres.append(nombre)
            }
        }
        return "Compartida con \(nombres.joined(separator: ", "))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Resumen del plan
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
                        if let congelado = plan.pagoCongelado {
                            Text("\(plan.montoTotal.comoDinero) · \(plan.numeroMeses - 1) × \(plan.mensualidadTipica.comoDinero) + pago congelado de \(congelado.comoDinero)")
                                .font(.footnote)
                                .foregroundStyle(Tema.textoSecundario)
                        } else {
                            Text("\(plan.montoTotal.comoDinero) a \(plan.numeroMeses) meses · \(plan.mensualidadTipica.comoDinero)/mes")
                                .font(.footnote)
                                .foregroundStyle(Tema.textoSecundario)
                        }
                        Text("Tarjeta: \(plan.tarjeta?.nombre ?? "—") · Compra: \(plan.fechaCompra.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                }

                // ── División de dueños (con memoria para próximos cortes) ──
                Button {
                    cargarPartesActuales()
                    mostrandoDivision = true
                } label: {
                    Panel {
                        HStack(spacing: 12) {
                            Image(systemName: "person.2.fill")
                                .font(.title3)
                                .foregroundStyle(Tema.acento)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("División de dueños")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Tema.textoPrincipal)
                                Text(personas.isEmpty
                                     ? "Primero agrega personas en la pestaña Personas"
                                     : resumenDivision)
                                    .font(.caption)
                                    .foregroundStyle(Tema.textoSecundario)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Tema.textoSecundario)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(personas.isEmpty)

                // ── Pago final congelado (esquema Banamex) ──
                if plan.pagoCongelado == nil && !plan.estaConcluidoReal {
                    Button {
                        congeladoTexto = ""
                        mostrandoCongelado = true
                    } label: {
                        Panel {
                            HStack(spacing: 12) {
                                Image(systemName: "snowflake")
                                    .font(.title3)
                                    .foregroundStyle(Tema.acento)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Agregar pago final congelado")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Tema.textoPrincipal)
                                    Text("Si este plan tiene un pago diferido al final (esquema Banamex)")
                                        .font(.caption)
                                        .foregroundStyle(Tema.textoSecundario)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Tema.textoSecundario)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                // ⭐ Doble progreso: la Ley 3 visualizada
                Panel {
                    VStack(alignment: .leading, spacing: 14) {
                        barraProgreso(titulo: "GENERADAS POR EL BANCO",
                                      valor: plan.generadas,
                                      total: plan.numeroMeses,
                                      color: Tema.acento)
                        barraProgreso(titulo: "CUBIERTAS CON PAGOS REALES",
                                      valor: plan.cubiertasReal,
                                      total: plan.numeroMeses,
                                      color: Tema.positivo)

                        if plan.generadas == plan.numeroMeses && !plan.estaConcluidoReal {
                            Label("Ya se generaron todas las mensualidades, pero AÚN NO está liquidada: faltan \(plan.montoPendienteDeCubrir.comoDinero) por cubrir con pagos reales.",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(Tema.advertencia)
                        }
                    }
                }

                TituloSeccion(texto: "Mensualidades")

                Panel {
                    VStack(spacing: 0) {
                        ForEach(plan.mensualidadesOrdenadas) { mens in
                            filaMensualidad(mens)
                            if mens.id != plan.mensualidadesOrdenadas.last?.id {
                                Divider().overlay(Tema.panelElevado)
                            }
                        }
                    }
                }

                // ── Eliminar plan (para duplicados de importación) ──
                Button(role: .destructive) {
                    confirmandoEliminacion = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Eliminar este plan")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Tema.urgente)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Tema.urgente.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(16)
        }
        .background(Tema.fondo.ignoresSafeArea())
        .navigationTitle("Plan MSI")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Pago final congelado", isPresented: $mostrandoCongelado) {
            TextField("Monto (ej. 8000)", text: $congeladoTexto)
                .keyboardType(.decimalPad)
            Button("Agregar") { agregarPagoCongelado() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Se agregará como la mensualidad \(plan.numeroMeses + 1) del plan: se generará y cubrirá como cualquier otra cuando llegue su corte.")
        }
        .confirmationDialog("¿Eliminar este plan a meses?",
                            isPresented: $confirmandoEliminacion,
                            titleVisibility: .visible) {
            Button("Sí, eliminar plan", role: .destructive) { eliminarPlan() }
            Button("No", role: .cancel) { }
        } message: {
            Text("Se eliminarán el plan, sus mensualidades y su división de dueños. Úsalo para limpiar planes duplicados de importaciones de prueba.")
        }
        .sheet(isPresented: $mostrandoDivision, onDismiss: aplicarDivision) {
            AsignacionCompartidaView(
                titulo: plan.detalle.isEmpty ? "Compra a MSI" : plan.detalle,
                montoBase: plan.montoMensualidad,
                esMensual: true,
                personas: personas,
                partes: $partesEdicion)
        }
    }

    // MARK: - Eliminar plan

    /// Elimina el plan completo: mensualidades (en cascada), su división
    /// de dueños, y sus movimientos ancla ($0 se borran; con monto real
    /// se cancelan para no alterar la deuda sin dejar rastro, Ley 4).
    private func eliminarPlan() {
        for movimiento in plan.movimientos {
            if let compartida = movimiento.compraCompartida {
                for parte in compartida.participaciones { contexto.delete(parte) }
                movimiento.compraCompartida = nil
                contexto.delete(compartida)
            }
            if movimiento.monto == 0 {
                contexto.delete(movimiento)
            } else {
                movimiento.estado = .cancelado
            }
        }
        contexto.delete(plan)   // las mensualidades se van en cascada
        cerrar()
    }

    // MARK: - Pago final congelado

    /// Agrega el pago diferido como última mensualidad del plan
    /// (para planes importados que lo traían, como los de Banamex).
    private func agregarPagoCongelado() {
        let limpio = congeladoTexto.replacingOccurrences(of: ",", with: "")
        guard let monto = Double(limpio), monto > 0 else { return }

        let mensualidad = MensualidadMSI(numero: plan.numeroMeses + 1,
                                         monto: monto,
                                         plan: plan)
        contexto.insert(mensualidad)
        plan.numeroMeses += 1
        plan.montoTotal += monto
    }

    // MARK: - División de dueños

    /// Carga la plantilla actual (si el plan ya estaba compartido).
    private func cargarPartesActuales() {
        partesEdicion = [:]
        guard let compartida = compartidaExistente else { return }
        for parte in compartida.participaciones {
            if let persona = parte.persona, partesEdicion[persona.id] == nil {
                partesEdicion[persona.id] = parte.monto
            }
        }
    }

    /// Aplica la división: queda como plantilla del plan y carga a cada
    /// persona su parte de la mensualidad vigente.
    private func aplicarDivision() {
        let conMonto = partesEdicion.filter { $0.value > 0 }

        // Asegurar el movimiento ancla del plan (guarda la división)
        let ancla: Movimiento
        if let existente = plan.movimientos.first {
            ancla = existente
        } else {
            let nuevo = Movimiento(tipo: .compraCredito,
                                   monto: 0,
                                   fecha: plan.fechaCompra,
                                   detalle: plan.detalle + " (registro del plan)",
                                   tarjeta: plan.tarjeta)
            nuevo.planMSI = plan
            contexto.insert(nuevo)
            ancla = nuevo
        }

        // 100% mía: retirar la división si existía
        if conMonto.isEmpty {
            if let compartida = ancla.compraCompartida {
                for parte in compartida.participaciones { contexto.delete(parte) }
                ancla.compraCompartida = nil
                contexto.delete(compartida)
            }
            return
        }

        // Crear o REINICIAR la división con una mensualidad de cada persona
        let compartida: CompraCompartida
        if let existente = ancla.compraCompartida {
            compartida = existente
            for parte in compartida.participaciones { contexto.delete(parte) }
        } else {
            compartida = CompraCompartida()
            contexto.insert(compartida)
            ancla.compraCompartida = compartida
        }

        for persona in personas {
            if let monto = conMonto[persona.id], monto > 0 {
                contexto.insert(Participacion(monto: monto,
                                              persona: persona,
                                              compra: compartida))
            }
        }
    }

    // MARK: - Componentes visuales

    private func barraProgreso(titulo: String, valor: Int, total: Int,
                               color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(titulo)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Tema.textoSecundario)
                Spacer()
                Text("\(valor) de \(total)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
            }
            ProgressView(value: Double(valor), total: Double(max(total, 1)))
                .tint(color)
        }
    }

    private func filaMensualidad(_ mens: MensualidadMSI) -> some View {
        HStack(spacing: 12) {
            Text("\(mens.numero) de \(plan.numeroMeses)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Tema.textoPrincipal)
                .frame(width: 64, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                if let generadaEl = mens.fechaGeneracion {
                    Text("Generada · corte del \(generadaEl.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(Tema.acento)
                } else {
                    Text("Por generar en un corte futuro")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                }

                if mens.estaCubiertaReal {
                    Label("Cubierta con pagos reales", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Tema.positivo)
                } else if mens.fueGenerada {
                    Label("Sin cubrir", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(Tema.advertencia)
                }
            }

            Spacer()

            if plan.pagoCongelado != nil,
               abs(mens.monto - plan.mensualidadTipica) > 0.01 {
                Pildora(texto: "Congelado", color: Tema.acento)
            }

            Text(mens.monto.comoDinero)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Tema.textoPrincipal)
        }
        .padding(.vertical, 8)
    }
}
