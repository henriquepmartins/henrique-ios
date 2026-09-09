import HenriqueCore
import SwiftUI

struct WeekScreen: View {
  @Environment(AcademiaStore.self) private var store
  @Environment(\.dynamicTypeSize) private var textSize
  @State private var editor: PlanEditorDestination?
  var onStart: (Int) -> Void = { _ in }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        PageHeading(eyebrow: "sua semana", title: "plano de treino",
                    subtitle: "Distribua o esforço e deixe espaço para recuperar.")
        Button("novo treino", systemImage: "plus") { editor = .new }
          .buttonStyle(.glassProminent)
          .controlSize(.large)
        if let dashboard = store.dashboard {
          LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                   count: textSize.isAccessibilitySize ? 1 : 2), spacing: 6) {
            ForEach(Array(dashboard.weekPlan.enumerated()), id: \.element.id) { index, item in
              WorkoutTile(item: item, index: index,
                          onEdit: { editor = .existing(item) }, onStart: { onStart(item.weekday) })
                .staggeredEntrance(index: index, isReady: true)
            }
          }
        }
      }
      .padding(16)
      .padding(.bottom, 32)
    }
    .background(Color.canvas)
    .refreshable { await store.load() }
    .sheet(item: $editor) { destination in
      WorkoutEditor(item: destination.item, catalog: store.dashboard?.exerciseCatalog ?? [])
    }
  }
}

private enum PlanEditorDestination: Identifiable {
  case new
  case existing(WeekPlanItem)
  var id: String { item?.id ?? "new" }
  var item: WeekPlanItem? {
    if case .existing(let item) = self { return item }
    return nil
  }
}

private let planWeekdays = ["domingo", "segunda", "terça", "quarta", "quinta", "sexta", "sábado"]

private struct WorkoutTile: View {
  let item: WeekPlanItem
  let index: Int
  let onEdit: () -> Void
  let onStart: () -> Void

  private var tone: WorkoutTone { .at(index) }
  private var nameFont: Font { .system(.headline, weight: .semibold) }
  /// O recuo do bloco colorido. Os três pontos leem o mesmo valor para cair na
  /// linha do nome.
  private let blockPad: CGFloat = 12
  /// A folga que leva a área de toque dos três pontos aos 44 pontos. Sai de
  /// novo do recuo de baixo, senão o glifo desce e desalinha do nome.
  private let menuTapPad: CGFloat = 10

  var body: some View {
    Button(action: onStart) { face }
      .buttonStyle(StudyPressStyle())
      .accessibilityLabel("iniciar \(item.name), \(planWeekdays[item.weekday])")
      // Menu dentro do label de um Button nunca chega a receber o dedo. Por isso
      // ele vem numa camada por cima, com área de toque só nos três pontos.
      .overlay(alignment: .bottomTrailing) { menuLayer }
  }

  private var face: some View {
    VStack(spacing: 0) {
      ZStack(alignment: .top) {
        sheet(inset: 24, opacity: 0.3)
        sheet(inset: 12, opacity: 0.52).padding(.top, 6)
        block.padding(.top, 13)
      }
      // Sem achatar antes, a sombra é aplicada em cada vinco e cai sobre o
      // bloco como uma faixa escura.
      .compositingGroup()
      .shadow(color: Color.ink.opacity(0.12), radius: 12, y: 6)
      footer
    }
  }

  private var footer: some View {
    Image(systemName: "play.fill")
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(Color.mutedInk)
      .padding(.vertical, 11)
  }

  private func sheet(inset: CGFloat, opacity: Double) -> some View {
    RoundedRectangle(cornerRadius: 8)
      .fill(tone.top.opacity(opacity))
      .frame(height: 26)
      .padding(.horizontal, inset)
  }

  private var block: some View {
    Text(item.name)
      .font(nameFont)
      .tracking(-0.3)
      .foregroundStyle(tone.ink)
      .lineLimit(2)
      .padding(.trailing, 30)
      .frame(maxWidth: .infinity, minHeight: 88, alignment: .bottomLeading)
      .padding(blockPad)
      .background {
        ZStack {
          LinearGradient(colors: [tone.top, tone.bottom], startPoint: .top, endPoint: .bottom)
          WorkoutWave(closed: true).fill(.white.opacity(0.12))
          WorkoutWave().stroke(.white.opacity(0.45), lineWidth: 1.5)
        }
      }
      .clipShape(.rect(cornerRadius: 18))
  }

  private var menuLayer: some View {
    VStack(alignment: .trailing, spacing: 0) {
      Menu {
        Button("editar treino", systemImage: "pencil", action: onEdit)
      } label: {
        // O espaço invisível no corpo do nome dá a altura da linha, então os
        // três pontos caem no meio dela em qualquer tamanho de texto.
        Text(verbatim: " ")
          .font(nameFont)
          .hidden()
          .frame(width: 44)
          .overlay {
            Image(systemName: "ellipsis")
              .font(.system(.body, weight: .semibold))
              .rotationEffect(.degrees(90))
              .foregroundStyle(tone.ink)
          }
          .padding(.vertical, menuTapPad)
          .contentShape(.rect)
      }
      .accessibilityLabel("editar \(item.name)")
      .padding(.bottom, blockPad - menuTapPad)
      footer.hidden()
    }
    .padding(.trailing, 2)
  }
}

private struct WorkoutWave: Shape {
  /// Fechada vira a faixa clara da metade de baixo, aberta vira só o traço.
  var closed = false

  func path(in rect: CGRect) -> Path {
    let base = rect.minY + rect.height * 0.52
    let amp = rect.height * 0.085
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: base))
    path.addQuadCurve(to: CGPoint(x: rect.midX, y: base),
                      control: CGPoint(x: rect.minX + rect.width * 0.25, y: base - amp))
    path.addQuadCurve(to: CGPoint(x: rect.maxX, y: base),
                      control: CGPoint(x: rect.midX + rect.width * 0.25, y: base + amp))
    if closed {
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
      path.closeSubpath()
    }
    return path
  }
}

struct WorkoutEditor: View {
  @Environment(AcademiaStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var name: String
  @State private var focus: String
  @State private var estimatedMinutes: Int
  @State private var exercises: [PlanExercise]
  @State private var isPickingExercise = false
  @State private var isSaving = false
  @State private var weekday: Int

  private let catalog: [ExerciseCatalogItem]

  init(item: WeekPlanItem?, catalog: [ExerciseCatalogItem]) {
    weekday = item?.weekday ?? 2
    self.catalog = catalog
    name = item?.name ?? ""
    focus = item?.focus ?? ""
    estimatedMinutes = item?.estimatedMinutes ?? 55
    exercises = item?.exercises ?? []
  }

  private var namesById: [String: String] {
    Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0.name) })
  }

  private var canSave: Bool {
    name.trimmingCharacters(in: .whitespaces).count >= 2
      && focus.trimmingCharacters(in: .whitespaces).count >= 2
      && !exercises.isEmpty && exercises.count <= 12 && (15...180).contains(estimatedMinutes)
      && exercises.allSatisfy { $0.repsMin <= $0.repsMax && $0.startingWeightKg >= 0 }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Treino") {
          Picker("dia", selection: $weekday) {
            ForEach(0..<7, id: \.self) { day in Text(planWeekdays[day]).tag(day) }
          }
          TextField("nome", text: $name)
          TextField("foco", text: $focus)
          TextField("duração em minutos", value: $estimatedMinutes, format: .number)
            .decimalInput()
        }

        Section {
          ForEach($exercises) { $exercise in
            PlanExerciseRow(exercise: $exercise, name: namesById[exercise.exerciseId] ?? exercise.exerciseId)
          }
          .onDelete { exercises.remove(atOffsets: $0) }
          .onMove { exercises.move(fromOffsets: $0, toOffset: $1) }

          Button("Adicionar exercício", systemImage: "plus") {
            isPickingExercise = true
          }
          .disabled(exercises.count >= 12)
        } header: {
          Text("Exercícios")
        } footer: {
          Text("Arraste para trocar a ordem. Deslize para remover.")
        }
      }
      .navigationTitle(name.isEmpty ? "Treino" : name)
      .toolbarTitleDisplayMode(.inline)
      .interactiveDismissDisabled(isSaving)
      .toolbar {
        #if os(iOS)
        ToolbarItem(placement: .automatic) { EditButton() }
        #endif
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancelar") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(isSaving ? "Salvando" : "Salvar") { save() }.disabled(!canSave || isSaving)
        }
      }
      .sheet(isPresented: $isPickingExercise) {
        ExercisePicker(catalog: catalog, chosen: Set(exercises.map(\.exerciseId))) { item in
          exercises.append(
            PlanExercise(
              exerciseId: item.id, prepSets: 2, workSets: 2, repsMin: 8, repsMax: 12,
              workToFailure: true, startingWeightKg: 0))
        }
      }
    }
  }

  private func save() {
    let input = SaveWorkoutInput(
      date: store.selectedDate, weekday: weekday,
      name: name.trimmingCharacters(in: .whitespaces),
      focus: focus.trimmingCharacters(in: .whitespaces), estimatedMinutes: estimatedMinutes,
      exercises: exercises)
    isSaving = true
    Task {
      let saved = await store.saveWorkout(input)
      isSaving = false
      if saved { dismiss() }
    }
  }
}

struct PlanExerciseRow: View {
  @Binding var exercise: PlanExercise
  let name: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(name).font(.body.weight(.medium))
      HStack(spacing: 16) {
        CompactStepper(label: "aquec.", value: $exercise.prepSets, range: 0...6)
        CompactStepper(label: "trabalho", value: $exercise.workSets, range: 1...10)
      }
      HStack(spacing: 16) {
        CompactStepper(label: "reps mín.", value: $exercise.repsMin, range: 1...50)
        CompactStepper(label: "reps máx.", value: $exercise.repsMax, range: 1...50)
      }
      WeightStepper(weightKg: $exercise.startingWeightKg)
      Toggle("até a falha", isOn: $exercise.workToFailure)
        .font(.caption)
    }
    .padding(.vertical, 6)
  }
}

struct CompactStepper: View {
  let label: String
  @Binding var value: Int
  let range: ClosedRange<Int>

  var body: some View {
    Stepper(value: $value, in: range) {
      HStack(spacing: 4) {
        Text(label).font(.caption).foregroundStyle(.secondary)
        Text("\(value)").font(.caption.weight(.medium)).monospacedDigit()
      }
    }
  }
}

struct ExercisePicker: View {
  @Environment(\.dismiss) private var dismiss
  @State private var search = ""

  let catalog: [ExerciseCatalogItem]
  let chosen: Set<String>
  let onPick: (ExerciseCatalogItem) -> Void

  private var results: [ExerciseCatalogItem] {
    let available = catalog.filter { !chosen.contains($0.id) }
    guard !search.isEmpty else { return available }
    return available.filter {
      $0.name.localizedStandardContains(search) || $0.muscleGroup.localizedStandardContains(search)
    }
  }

  var body: some View {
    NavigationStack {
      List(results) { item in
        Button {
          onPick(item)
          dismiss()
        } label: {
          VStack(alignment: .leading, spacing: 2) {
            Text(item.name)
            Text("\(item.muscleGroup) · \(item.equipment)")
              .font(.caption).foregroundStyle(.secondary)
          }
        }
        .buttonStyle(.plain)
      }
      .searchable(text: $search, prompt: "buscar exercício")
      .navigationTitle("Exercícios")
      .toolbarTitleDisplayMode(.inline)
      .overlay {
        if results.isEmpty {
          ContentUnavailableView.search(text: search)
        }
      }
    }
  }
}
