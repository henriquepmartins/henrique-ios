import Charts
import HenriqueCore
import SwiftUI

struct MeasurementsScreen: View {
  @Environment(AcademiaStore.self) private var store
  @State private var isAdding = false
  @Binding var accent: Accent

  private var measurements: [BodyMeasurement] {
    (store.dashboard?.measurements ?? []).sorted { $0.date > $1.date }
  }

  var body: some View {
    List {
      if let latest = measurements.first {
        Section {
          LatestMeasurementCard(measurement: latest)
            .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
        }
      }

      if measurements.count >= 2 {
        Section("Peso") {
          WeightChart(measurements: measurements)
            .frame(height: 160)
            .listRowBackground(Color.clear)
        }
      }

      Section("Histórico") {
        ForEach(measurements) { measurement in
          MeasurementRow(measurement: measurement)
        }
        if measurements.isEmpty {
          Text("Nenhuma medida registrada.")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }

      Section("Cor do app") {
        AccentPicker(accent: $accent)
      }

      Section {
        Button("Sair da conta", role: .destructive) {
          Task { await store.signOut() }
        }
      }
    }
    .navigationTitle("Medidas")
    .refreshable { await store.load() }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Nova medida", systemImage: "plus") { isAdding = true }
      }
    }
    .sheet(isPresented: $isAdding) {
      MeasurementEditor(previous: measurements.first)
    }
  }
}

struct LatestMeasurementCard: View {
  @Environment(\.accent) private var accent
  let measurement: BodyMeasurement

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(measurement.date.date(), format: .dateTime.day().month(.wide).year())
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(weightLabel(measurement.weightKg))
        .font(.system(size: 40, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(accent.base)
      HStack(spacing: 14) {
        MeasurementChip(label: "gordura", value: measurement.bodyFatPercent, unit: "%")
        MeasurementChip(label: "cintura", value: measurement.waistCm, unit: "cm")
        MeasurementChip(label: "braço", value: measurement.armCm, unit: "cm")
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .glassEffect(.regular.tint(accent.pale.opacity(0.5)), in: .rect(cornerRadius: 28))
  }
}

struct MeasurementChip: View {
  let label: String
  let value: Double?
  let unit: String

  var body: some View {
    if let value {
      VStack(alignment: .leading, spacing: 1) {
        Text(label).font(.caption2).foregroundStyle(.secondary)
        Text("\(value, format: .number.precision(.fractionLength(0...1))) \(unit)")
          .font(.caption.weight(.medium))
          .monospacedDigit()
      }
    }
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

struct AccentPicker: View {
  @Binding var accent: Accent

  var body: some View {
    Picker("cor", selection: $accent) {
      ForEach(Accent.allCases) { option in
        HStack {
          Circle().fill(option.base).frame(width: 14, height: 14)
          Text(option.label)
        }
        .tag(option)
      }
    }
    .labelsHidden()
    .pickerStyle(.inline)
  }
}

struct MeasurementEditor: View {
  @Environment(AcademiaStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var weightKg: Double
  @State private var bodyFatPercent: Double?
  @State private var waistCm: Double?
  @State private var chestCm: Double?
  @State private var armCm: Double?
  @State private var thighCm: Double?

  /// Começar da última medida poupa digitação: o peso muda pouco entre pesagens
  /// e as circunferências costumam ficar iguais por semanas.
  init(previous: BodyMeasurement?) {
    weightKg = previous?.weightKg ?? 70
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
          Stepper(value: $weightKg, in: 20...500, step: 0.1) {
            Text(weightLabel(weightKg)).monospacedDigit()
          }
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
      .navigationTitle("Nova medida")
      .toolbarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancelar") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Salvar") { save() }
        }
      }
    }
  }

  private func save() {
    let input = AddMeasurementInput(
      date: .today, weightKg: weightKg, bodyFatPercent: bodyFatPercent, waistCm: waistCm,
      chestCm: chestCm, armCm: armCm, thighCm: thighCm)
    dismiss()
    Task { await store.addMeasurement(input) }
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
      Toggle(isOn: .init(get: { value != nil }, set: { value = $0 ? range.lowerBound : nil })) {
        Text(label)
      }
      .labelsHidden()

      Text(label)

      Spacer()

      if let current = value {
        Stepper(value: .init(get: { current }, set: { value = $0 }), in: range, step: 0.5) {
          Text("\(current, format: .number.precision(.fractionLength(0...1))) \(unit)")
            .monospacedDigit()
            .font(.callout)
        }
        .labelsHidden()
        Text("\(current, format: .number.precision(.fractionLength(0...1))) \(unit)")
          .monospacedDigit()
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    }
  }
}
