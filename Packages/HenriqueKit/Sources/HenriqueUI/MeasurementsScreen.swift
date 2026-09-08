import Charts
import HenriqueCore
import SwiftUI

struct MeasurementsScreen: View {
  @Environment(AcademiaStore.self) private var store
  @State private var isAdding = false
  @Environment(\.dynamicTypeSize) private var textSize

  private var measurements: [BodyMeasurement] {
    (store.dashboard?.measurements ?? []).sorted { $0.date > $1.date }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        PageHeading(eyebrow: "seu corpo", title: "medidas",
          subtitle: "Registre nas mesmas condições para enxergar a tendência, não o ruído do dia.")
        Button("nova medida", systemImage: "plus") { isAdding = true }
          .buttonStyle(.glassProminent).controlSize(.large)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: textSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
          MeasurementMetric(title: "peso", value: measurements.first?.weightKg, unit: "kg", symbol: "scalemass")
            .staggeredEntrance(index: 0, isReady: true)
          MeasurementMetric(title: "gordura corporal", value: measurements.first?.bodyFatPercent, unit: "%", symbol: "figure")
            .staggeredEntrance(index: 1, isReady: true)
          MeasurementMetric(title: "cintura", value: measurements.first?.waistCm, unit: "cm", symbol: "ruler")
            .staggeredEntrance(index: 2, isReady: true)
          MeasurementMetric(title: "massa magra", value: leanMass, unit: "kg", symbol: "figure.strengthtraining.traditional")
            .staggeredEntrance(index: 3, isReady: true)
        }
        VStack(alignment: .leading, spacing: 16) {
          Text("peso corporal").font(.title2.weight(.medium))
          if measurements.isEmpty {
            Text("Nenhuma medida registrada.").foregroundStyle(Color.mutedInk).frame(height: 220)
          } else {
            WeightChart(measurements: measurements.sorted { $0.date < $1.date }).frame(height: 220)
          }
        }.padding(22).paperCard(radius: 32)
          .staggeredEntrance(index: 4, isReady: true)
        VStack(alignment: .leading, spacing: 16) {
          Text("histórico").font(.title2.weight(.medium))
          ForEach(measurements) { measurement in
            MeasurementRow(measurement: measurement)
            Divider()
          }
        }.padding(22).paperCard(radius: 32)
          .staggeredEntrance(index: 5, isReady: true)
      }.padding(16).padding(.bottom, 32)
    }
    .refreshable { await store.load() }
    .sheet(isPresented: $isAdding) { MeasurementEditor(previous: measurements.first) }
  }
  private var leanMass: Double? {
    guard let item = measurements.first, let fat = item.bodyFatPercent else { return nil }
    return item.weightKg * (1 - fat / 100)
  }
}

/// A porta das medidas dentro de progresso. Medidas deixou de ser aba, então o
/// resumo mostra o número mais recente e o toque abre a tela inteira.
struct MeasurementsLink: View {
  @Environment(\.accent) private var accent
  let latest: BodyMeasurement?

  var body: some View {
    NavigationLink {
      MeasurementsScreen()
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
    } label: {
      HStack(alignment: .top, spacing: 16) {
        VStack(alignment: .leading, spacing: 10) {
          Text("suas medidas").font(.caption).foregroundStyle(accent.base)
          if let latest {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
              value(weightLabel(latest.weightKg), caption: "peso")
              if let fat = latest.bodyFatPercent {
                value("\(fat.formatted(.number.precision(.fractionLength(0...1))))%",
                  caption: "gordura")
              }
            }
          } else {
            Text("nenhuma medida registrada").font(.title3.weight(.medium))
          }
          Text(latest.map { "última em \($0.date.date().formatted(.dateTime.day().month(.wide)))" }
            ?? "Registre a primeira para o gráfico começar.")
            .font(.subheadline).foregroundStyle(Color.mutedInk)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
        Image(systemName: "arrow.right")
          .font(.headline)
          .foregroundStyle(accent.base)
          .padding(.top, 4)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(22)
      .paperCard(radius: 32)
      .contentShape(.rect(cornerRadius: 32))
    }
    .buttonStyle(StudyPressStyle())
    .foregroundStyle(Color.ink)
  }

  private func value(_ text: String, caption: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(text).font(.system(size: 30, weight: .medium)).monospacedDigit()
        .contentTransition(.numericText())
        .animation(.smooth(duration: 0.3), value: text)
      Text(caption).font(.caption).foregroundStyle(Color.mutedInk)
    }
  }
}

struct MeasurementMetric: View {
  @Environment(\.accent) private var accent
  let title: String
  let value: Double?
  let unit: String
  let symbol: String
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Image(systemName: symbol).foregroundStyle(accent.base)
      Text(title).font(.caption).foregroundStyle(Color.mutedInk)
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text(value.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "sem registro")
          .font(.title2.weight(.medium)).monospacedDigit()
        if value != nil { Text(unit).font(.caption).foregroundStyle(Color.mutedInk) }
      }
    }.frame(maxWidth: .infinity, minHeight: 110, alignment: .leading).padding(16).paperCard(radius: 26)
      .accessibilityElement(children: .combine)
  }
}

struct WeightChart: View {
  @Environment(\.accent) private var accent
  let measurements: [BodyMeasurement]

  var body: some View {
    Chart(measurements) { measurement in
      LineMark(
        x: .value("dia", measurement.date.date()), y: .value("peso", measurement.weightKg)
      )
      .interpolationMethod(.monotone)
      .foregroundStyle(accent.base)

      AreaMark(
        x: .value("dia", measurement.date.date()), y: .value("peso", measurement.weightKg)
      )
      .interpolationMethod(.monotone)
      .foregroundStyle(accent.pale.opacity(0.4))
    }
    .chartYScale(domain: .automatic(includesZero: false))
    .chartYAxisLabel("kg")
  }
}

struct MeasurementRow: View {
  let measurement: BodyMeasurement

  var body: some View {
    HStack {
      Text(measurement.date.date(), format: .dateTime.day().month(.abbreviated))
        .font(.callout)
      Spacer()
      Text(weightLabel(measurement.weightKg))
        .font(.callout.weight(.medium))
        .monospacedDigit()
    }
  }
}

struct MeasurementEditor: View {
  @Environment(AcademiaStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var weightKg: Double?
  @State private var isSaving = false
  @State private var bodyFatPercent: Double?
  @State private var waistCm: Double?
  @State private var chestCm: Double?
  @State private var armCm: Double?
  @State private var thighCm: Double?

  /// Começar da última medida poupa digitação: o peso muda pouco entre pesagens
  /// e as circunferências costumam ficar iguais por semanas.
  init(previous: BodyMeasurement?) {
    weightKg = previous?.weightKg
    bodyFatPercent = previous?.bodyFatPercent
    waistCm = previous?.waistCm
    chestCm = previous?.chestCm
    armCm = previous?.armCm
    thighCm = previous?.thighCm
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Peso") {
          TextField("peso em kg", value: $weightKg, format: .number.precision(.fractionLength(0...2)))
            .decimalInput()
        }
        Section {
          OptionalField(label: "gordura corporal", unit: "%", range: 1...70, value: $bodyFatPercent)
          OptionalField(label: "cintura", unit: "cm", range: 30...300, value: $waistCm)
          OptionalField(label: "peito", unit: "cm", range: 30...300, value: $chestCm)
          OptionalField(label: "braço", unit: "cm", range: 10...100, value: $armCm)
          OptionalField(label: "coxa", unit: "cm", range: 20...150, value: $thighCm)
        } header: {
          Text("Opcionais")
        } footer: {
          Text("Deixe de fora o que você não mediu. Só o peso é obrigatório.")
        }
      }
      .interactiveDismissDisabled(isSaving)
      .navigationTitle("Nova medida")
      .toolbarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancelar") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(isSaving ? "Salvando" : "Salvar") { save() }.disabled(isSaving || weightKg == nil || (weightKg ?? 0) <= 0)
        }
      }
    }
  }

  private func save() {
    guard let weightKg else { return }
    let input = AddMeasurementInput(
      date: .today, weightKg: weightKg, bodyFatPercent: bodyFatPercent, waistCm: waistCm,
      chestCm: chestCm, armCm: armCm, thighCm: thighCm)
    isSaving = true
    Task {
      let saved = await store.addMeasurement(input)
      isSaving = false
      if saved { dismiss() }
    }
  }
}

/// Um campo que a pessoa pode simplesmente não preencher. O botão liga e desliga
/// o campo em vez de exigir apagar um número para dizer "não medi".
struct OptionalField: View {
  let label: String
  let unit: String
  let range: ClosedRange<Double>
  @Binding var value: Double?

  var body: some View {
    HStack {
      Text(label)
      Spacer()
      TextField("não medido", value: $value, format: .number.precision(.fractionLength(0...2)))
        .decimalInput().multilineTextAlignment(.trailing)
        .accessibilityLabel(label)
      Text(unit).font(.caption).foregroundStyle(Color.mutedInk)
    }
  }
}
