import Charts
import HenriqueCore
import SwiftUI

struct ProgressScreen: View {
  @Environment(AcademiaStore.self) private var store
  @State private var isEditingGoal = false

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        if let dashboard = store.dashboard {
          if let goal = dashboard.strengthGoal {
            GoalCard(
              exerciseName: goal.exerciseName, targetValue: goal.targetValue,
              projection: dashboard.projection)
          }

          if dashboard.progress.isEmpty {
            ContentUnavailableView(
              "Sem histórico ainda", systemImage: "chart.xyaxis.line",
              description: Text("O gráfico aparece depois da primeira série de trabalho gravada."))
              .padding(.vertical, 40)
          } else {
            OneRepMaxChart(
              points: dashboard.progress, target: dashboard.strengthGoal?.targetValue)
            VolumeChart(points: dashboard.progress)
          }

          Button(dashboard.strengthGoal == nil ? "Definir meta de força" : "Trocar a meta") {
            isEditingGoal = true
          }
          .buttonStyle(.glass)
          .disabled(dashboard.exerciseCatalog.isEmpty)
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 40)
    }
    .navigationTitle("Progresso")
    .refreshable { await store.load() }
    .sheet(isPresented: $isEditingGoal) {
      GoalEditor(
        catalog: store.dashboard?.exerciseCatalog ?? [],
        current: store.dashboard?.strengthGoal)
    }
  }
}

struct GoalCard: View {
  @Environment(\.accent) private var accent
  let exerciseName: String
  let targetValue: Double
  let projection: Projection?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Meta em \(exerciseName)").font(.headline)
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(weightLabel(projection?.current ?? 0))
          .font(.largeTitle.weight(.semibold))
          .monospacedDigit()
          .foregroundStyle(accent.base)
        Text("de \(weightLabel(targetValue))")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      if let projection {
        ProgressView(value: min(projection.current / max(projection.target, 1), 1))
          .tint(accent.signal)
        Text(projectionSentence(projection))
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .glassEffect(.regular.tint(accent.pale.opacity(0.5)), in: .rect(cornerRadius: 28))
  }

  private func projectionSentence(_ projection: Projection) -> String {
    guard let weeks = projection.weeksRemaining else {
      return "Ainda não dá para projetar quando você chega lá, \(projection.confidence.label)."
    }
    if weeks == 0 { return "Meta batida." }
    let plural = weeks == 1 ? "semana" : "semanas"
    return "Nesse ritmo você chega em \(weeks) \(plural), \(projection.confidence.label)."
  }
}

struct OneRepMaxChart: View {
  @Environment(\.accent) private var accent
  let points: [ProgressPoint]
  let target: Double?

  var body: some View {
    ChartCard(title: "Força estimada", caption: "1RM calculado pela fórmula de Epley") {
      Chart {
        ForEach(points) { point in
          LineMark(
            x: .value("dia", point.date.date()), y: .value("1RM", point.estimatedOneRepMax)
          )
          .interpolationMethod(.monotone)
          .foregroundStyle(accent.base)

          PointMark(
            x: .value("dia", point.date.date()), y: .value("1RM", point.estimatedOneRepMax)
          )
          .foregroundStyle(accent.base)
        }
        if let target {
          RuleMark(y: .value("meta", target))
            .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
            .foregroundStyle(accent.signal)
            .annotation(position: .top, alignment: .leading) {
              Text("meta").font(.caption2).foregroundStyle(.secondary)
            }
        }
      }
      .chartYAxisLabel("kg")
    }
  }
}

struct VolumeChart: View {
  @Environment(\.accent) private var accent
  let points: [ProgressPoint]

  var body: some View {
    ChartCard(title: "Volume por treino", caption: "carga vezes repetições, somando as séries") {
      Chart(points) { point in
        BarMark(x: .value("dia", point.date.date(), unit: .day), y: .value("volume", point.volumeKg))
          .foregroundStyle(accent.pale)
          .cornerRadius(4)
      }
      .chartYAxisLabel("kg")
    }
  }
}

struct ChartCard<Content: View>: View {
  let title: String
  let caption: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.headline)
        Text(caption).font(.caption).foregroundStyle(.secondary)
      }
      content
        .frame(height: 180)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .glassEffect(.regular, in: .rect(cornerRadius: 26))
  }
}

struct GoalEditor: View {
  @Environment(AcademiaStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var exerciseId: String
  @State private var targetValue: Double

  private let catalog: [ExerciseCatalogItem]

  init(catalog: [ExerciseCatalogItem], current: StrengthGoal?) {
    self.catalog = catalog
    exerciseId = current?.exerciseId ?? catalog.first?.id ?? ""
    targetValue = current?.targetValue ?? 60
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Exercício") {
          Picker("exercício", selection: $exerciseId) {
            ForEach(catalog) { item in
              Text(item.name).tag(item.id)
            }
          }
          .labelsHidden()
          .pickerStyle(.inline)
        }
        Section("Alvo") {
          WeightStepper(weightKg: $targetValue)
        }
      }
      .navigationTitle("Meta de força")
      .toolbarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancelar") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Salvar") { save() }.disabled(exerciseId.isEmpty || targetValue < 1)
        }
      }
    }
  }

  private func save() {
    let input = SetStrengthGoalInput(
      date: store.selectedDate, exerciseId: exerciseId, targetValue: targetValue)
    dismiss()
    Task { await store.setStrengthGoal(input) }
  }
}
