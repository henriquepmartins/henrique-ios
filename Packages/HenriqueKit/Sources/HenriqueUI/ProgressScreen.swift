import Charts
import HenriqueCore
import SwiftUI

/// Os três tipos de meta que o editor cobre. Força é a de carga; as outras duas
/// são as sequências do painel, e a ponte com `StreakKind` fica aqui.
enum GoalKind: Hashable, CaseIterable, Identifiable {
  case strength, attendance, complete

  var id: Self { self }

  init(_ streak: StreakKind) {
    switch streak {
    case .attendance: self = .attendance
    case .complete: self = .complete
    }
  }

  var streakKind: StreakKind? {
    switch self {
    case .strength: nil
    case .attendance: .attendance
    case .complete: .complete
    }
  }

  var face: (label: String, systemImage: String) {
    switch self {
    case .strength: ("força", "dumbbell.fill")
    case .attendance: ("presença", "flame.fill")
    case .complete: ("completos", "checkmark.seal.fill")
    }
  }
}

struct ProgressScreen: View {
  @Environment(AcademiaStore.self) private var store
  @State private var editing: GoalKind?
  var onWorkout: () -> Void = {}

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        PageHeading(eyebrow: "evolução", title: "força, volume e direção",
          subtitle: "O gráfico usa as séries valendo concluídas. Preparação e peso digitado sem marcar a série não entram na conta.")
        NavigationLink("detalhe da métrica") { MetricDetailScreen(onWorkout: onWorkout) }
          .frame(maxWidth: .infinity, alignment: .trailing).font(.subheadline)
        if let dashboard = store.dashboard {
          let streakGoals = dashboard.streakGoals ?? []
          let cards = (dashboard.strengthGoal == nil ? 0 : 1) + streakGoals.count
          if let goal = dashboard.strengthGoal {
            GoalCard(
              exerciseName: goal.exerciseName, targetValue: goal.targetValue,
              projection: dashboard.projection)
              .staggeredEntrance(index: 0, isReady: true)
          }
          ForEach(Array(streakGoals.enumerated()), id: \.element.kind) { index, goal in
            StreakGoalCard(
              kind: GoalKind(goal.kind), current: dashboard.streak(goal.kind), target: goal.target
            ) { editing = GoalKind(goal.kind) }
              .staggeredEntrance(index: cards - streakGoals.count + index, isReady: true)
          }

          Button(dashboard.strengthGoal == nil ? "criar meta" : "atualizar meta") {
            editing = newGoalKind(in: dashboard)
          }
            .buttonStyle(.glassProminent).controlSize(.large)
            .disabled(dashboard.exerciseCatalog.isEmpty)
            .staggeredEntrance(index: cards, isReady: true)
          if dashboard.progress.isEmpty {
            ContentUnavailableView(
              "Sem histórico ainda", systemImage: "chart.xyaxis.line",
              description: Text("O gráfico aparece depois da primeira série de trabalho gravada."))
              .padding(.vertical, 40)
              .staggeredEntrance(index: cards + 1, isReady: true)
          } else {
            OneRepMaxChart(
              points: dashboard.progress, target: dashboard.strengthGoal?.targetValue)
              .staggeredEntrance(index: cards + 1, isReady: true)
            VolumeChart(points: dashboard.progress)
              .staggeredEntrance(index: cards + 2, isReady: true)
          }
          MeasurementsLink(latest: latest(in: dashboard))
            .staggeredEntrance(index: cards + 3, isReady: true)
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 40)
    }
    .refreshable { await store.load() }
    .sheet(item: $editing) { kind in
      if let dashboard = store.dashboard {
        GoalEditor(kind: kind, dashboard: dashboard)
      }
    }
  }

  /// O botão abre o editor no primeiro tipo ainda sem meta, começando pela de
  /// força. Com as três definidas, volta para a força.
  private func newGoalKind(in dashboard: Dashboard) -> GoalKind {
    if dashboard.strengthGoal == nil { return .strength }
    return StreakKind.allCases.first { dashboard.goal($0) == nil }.map(GoalKind.init) ?? .strength
  }
}

struct StreakGoalCard: View {
  @Environment(\.accent) private var accent
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let kind: GoalKind
  let current: Int
  let target: Int
  let action: () -> Void

  private var progress: Double { min(1, Double(current) / Double(max(target, 1))) }

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 10) {
        Label(kind.face.label, systemImage: kind.face.systemImage).font(.headline)
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text("\(current)")
            .font(.largeTitle.weight(.semibold))
            .foregroundStyle(accent.base)
          Text("/\(target)")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .monospacedDigit()
        ProgressView(value: progress)
          .tint(accent.signal)
          .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: progress)
        if current >= target {
          Text("meta batida").font(.footnote).foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(20)
      .background(accent.pale, in: .rect(cornerRadius: 32))
      .contentShape(.rect(cornerRadius: 32))
    }
    .buttonStyle(StudyPressStyle())
    .foregroundStyle(Color.ink)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("meta de \(kind.face.label), \(current) de \(target)")
    .accessibilityAddTraits(.isButton)
  }
}

/// A medida mais recente do painel. O servidor devolve a lista sem ordem
/// garantida, então a data decide.
private func latest(in dashboard: Dashboard) -> BodyMeasurement? {
  dashboard.measurements.max { $0.date < $1.date }
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
    .background(accent.pale, in: .rect(cornerRadius: 32))
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
        AreaMark(x: .value("dia", point.date.date()), y: .value("volume", point.volumeKg))
          .interpolationMethod(.monotone)
          .foregroundStyle(LinearGradient(colors: [accent.mint.opacity(0.8), accent.mint.opacity(0.08)], startPoint: .top, endPoint: .bottom))
        LineMark(x: .value("dia", point.date.date()), y: .value("volume", point.volumeKg))
          .interpolationMethod(.monotone).foregroundStyle(accent.base)
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
        .frame(height: 220)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .paperCard(radius: 32)
  }
}

/// Um editor para as três metas. O segmento de cima troca o formulário e o
/// salvar manda para a rota do tipo escolhido.
struct GoalEditor: View {
  @Environment(AcademiaStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var kind: GoalKind
  @State private var exerciseId: String
  @State private var targetValue: Double
  @State private var streakTargets: [StreakKind: Int]
  @State private var isSaving = false

  private let catalog: [ExerciseCatalogItem]
  private let streaks: [StreakKind: Int]

  init(kind: GoalKind, dashboard: Dashboard) {
    self.kind = kind
    catalog = dashboard.exerciseCatalog
    exerciseId = dashboard.strengthGoal?.exerciseId ?? dashboard.exerciseCatalog.first?.id ?? ""
    targetValue = dashboard.strengthGoal?.targetValue ?? 60
    streaks = Dictionary(uniqueKeysWithValues: StreakKind.allCases.map { ($0, dashboard.streak($0)) })
    streakTargets = Dictionary(
      uniqueKeysWithValues: StreakKind.allCases.map { streak in
        (streak, dashboard.goal(streak)?.target ?? max(dashboard.streak(streak) + 5, 7))
      })
  }

  private var canSave: Bool {
    switch kind {
    case .strength: !exerciseId.isEmpty && targetValue >= 1
    case .attendance, .complete: true
    }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("tipo", selection: $kind) {
            ForEach(GoalKind.allCases) { Text($0.face.label).tag($0) }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
        }
        if let streak = kind.streakKind {
          Section {
            StreakGoalFields(
              kind: kind, current: streaks[streak] ?? 0,
              target: Binding(
                get: { streakTargets[streak] ?? 7 }, set: { streakTargets[streak] = $0 }))
          }
        } else {
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
      }
      .interactiveDismissDisabled(isSaving)
      .navigationTitle("Meta de força")
      .toolbarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancelar") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(isSaving ? "Salvando" : "Salvar") { save() }.disabled(isSaving || !canSave)
        }
      }
    }
  }

  private func save() {
    isSaving = true
    Task {
      let saved: Bool
      if let streak = kind.streakKind {
        saved = await store.setStreakGoal(
          SetStreakGoalInput(
            date: store.selectedDate, kind: streak, target: streakTargets[streak] ?? 7))
      } else {
        saved = await store.setStrengthGoal(
          SetStrengthGoalInput(
            date: store.selectedDate, exerciseId: exerciseId, targetValue: targetValue))
      }
      isSaving = false
      if saved { dismiss() }
    }
  }
}

private struct StreakGoalFields: View {
  @Environment(\.accent) private var accent
  let kind: GoalKind
  let current: Int
  @Binding var target: Int

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: kind.face.systemImage).font(.title).foregroundStyle(accent.base)
      Text("\(current)").font(.system(size: 44, weight: .medium)).monospacedDigit()
      Spacer(minLength: 0)
    }
    .frame(minHeight: 64)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(kind.face.label) atual, \(current)")
    HStack(spacing: 12) {
      Text("alvo").font(.body)
      Spacer(minLength: 8)
      Text("\(target)").font(.body.weight(.semibold)).monospacedDigit()
        .frame(minWidth: 32, alignment: .trailing)
      Stepper("alvo", value: $target, in: 2...365)
        .labelsHidden()
    }
    .frame(minHeight: 48)
  }
}

struct MetricDetailScreen: View {
  @Environment(AcademiaStore.self) private var store
  @Environment(\.accent) private var accent
  @State private var bodyTrack = false
  @State private var allHistory = false

  private var values: [(date: CalendarDate, value: Double)] {
    guard let data = store.dashboard else { return [] }
    if bodyTrack {
      return data.measurements.compactMap { item in
        item.bodyFatPercent.map { (date: item.date, value: item.weightKg * (1 - $0 / 100)) }
      }.sorted { $0.date < $1.date }
    }
    return data.progress.map { (date: $0.date, value: $0.estimatedOneRepMax) }.sorted { $0.date < $1.date }
  }
  private var window: [(date: CalendarDate, value: Double)] {
    guard !allHistory, let last = values.last else { return values }
    return values.filter { $0.date >= last.date.adding(days: -56) }
  }

  @State private var isAddingMeasurement = false
  @State private var isEditingGoal = false
  var onWorkout: () -> Void = {}

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        Picker("Métrica em foco", selection: $bodyTrack) {
          Text("força").tag(false)
          Text("corpo").tag(true)
        }.pickerStyle(.segmented)
        VStack(spacing: 18) {
          Text(bodyTrack ? "massa magra" : "força estimada").font(.caption).foregroundStyle(Color.mutedInk)
          if let latest = window.last {
            Text(latest.date.date(), format: .dateTime.day().month(.wide).year()).font(.caption)
            Text(weightLabel(latest.value)).font(.system(size: 64, weight: .medium)).tracking(-3).monospacedDigit()
              .minimumScaleFactor(0.6).lineLimit(1)
            if let first = window.first, first.date != latest.date {
              let weeks = max(1, Int((latest.date.date().timeIntervalSince(first.date.date()) / 604800).rounded()))
              Text("\((latest.value - first.value).formatted(.number.sign(strategy: .always()).precision(.fractionLength(1)))) kg em \(weeks) semanas")
                .font(.subheadline).foregroundStyle(accent.base)
            } else {
              Text("tendência a partir da segunda medida").font(.caption).foregroundStyle(Color.mutedInk)
            }
          } else {
            Text(bodyTrack ? "sem medida com gordura" : "sem série valendo registrada").font(.title2)
            Text("O número aparece assim que existir registro.").font(.subheadline).foregroundStyle(Color.mutedInk)
          }
        }.frame(maxWidth: .infinity, minHeight: 230).padding(.vertical, 24)
        HStack(alignment: .top, spacing: 8) {
          action("registrar", symbol: "square.and.pencil") {
            if bodyTrack { isAddingMeasurement = true } else { onWorkout() }
          }
          action(allHistory ? "tudo" : "8 semanas", symbol: "calendar") { allHistory.toggle() }
          action("meta", symbol: "target") { isEditingGoal = true }
        }
        if !bodyTrack, let last = store.dashboard?.strengthGoal?.lastSession {
          VStack(alignment: .leading, spacing: 20) {
            HStack {
              Text("última sessão").font(.headline)
              Spacer()
              Text(last.date.date(), format: .dateTime.day().month(.abbreviated)).font(.caption)
            }
            HStack(alignment: .top) {
              sessionValue("reps na falha", value: last.reps.map(String.init).joined(separator: ", "))
              sessionValue("melhor carga", value: weightLabel(last.weightKg))
              sessionValue("volume", value: weightLabel(last.volumeKg))
            }
          }.padding(22).paperCard(radius: 28)
            .padding(7).background(Color.surfaceMuted, in: .rect(cornerRadius: 34))
        }
      }.padding(16)
    }.background(Color.canvas.ignoresSafeArea())
      .navigationTitle(bodyTrack ? "composição" : (store.dashboard?.strengthGoal?.exerciseName.lowercased() ?? "força"))
      .toolbarTitleDisplayMode(.inline)
      .sheet(isPresented: $isAddingMeasurement) { MeasurementEditor(previous: store.dashboard?.measurements.first) }
      .sheet(isPresented: $isEditingGoal) {
        if let dashboard = store.dashboard {
          GoalEditor(kind: .strength, dashboard: dashboard)
        }
      }
  }

  private func action(_ title: String, symbol: String, perform: @escaping () -> Void) -> some View {
    VStack(spacing: 8) {
      Button(title, systemImage: symbol, action: perform)
        .labelStyle(.iconOnly).buttonStyle(.glass).controlSize(.large)
      Text(title).font(.caption2)
    }.frame(maxWidth: .infinity)
  }
  private func sessionValue(_ title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title).font(.caption2).foregroundStyle(Color.mutedInk)
      Text(value).font(.subheadline.weight(.medium)).monospacedDigit()
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
}
