import HenriqueCore
import SwiftUI

struct WeekScreen: View {
  @Environment(AcademiaStore.self) private var store
  @State private var editing: WeekPlanItem?

  private static let weekdayNames = [
    "domingo", "segunda", "terça", "quarta", "quinta", "sexta", "sábado",
  ]

  var body: some View {
    List {
      if let dashboard = store.dashboard {
        Section {
          ForEach(dashboard.weekPlan) { item in
            Button {
              editing = item
            } label: {
              WeekPlanRow(
                weekday: Self.weekdayNames[item.weekday], name: item.name, focus: item.focus,
                exerciseCount: item.exerciseCount, estimatedMinutes: item.estimatedMinutes)
            }
            .buttonStyle(.plain)
          }
        } header: {
          Text("\(dashboard.weeklyPlanned) treinos por semana")
        } footer: {
          Text("Toque num dia para ajustar os exercícios, as séries e a carga inicial.")
        }
      }
    }
    .navigationTitle("Semana")
    .refreshable { await store.load() }
    .sheet(item: $editing) { item in
      WorkoutEditor(item: item, catalog: store.dashboard?.exerciseCatalog ?? [])
    }
  }
}

struct WeekPlanRow: View {
  @Environment(\.accent) private var accent
  let weekday: String
  let name: String
  let focus: String
  let exerciseCount: Int
  let estimatedMinutes: Int

  var body: some View {
    HStack(spacing: 14) {
      Text(weekday.prefix(3))
        .font(.caption.weight(.semibold))
        .textCase(.uppercase)
        .foregroundStyle(accent.base)
        .frame(width: 40, alignment: .leading)

      VStack(alignment: .leading, spacing: 2) {
        Text(name).font(.body.weight(.medium))
        Text(focus).font(.caption).foregroundStyle(.secondary)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 2) {
        Text("\(exerciseCount) exercícios").font(.caption).monospacedDigit()
        Text("\(estimatedMinutes) min").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
      }
    }
    .padding(.vertical, 4)
    .contentShape(.rect)
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

  private let weekday: Int
  private let catalog: [ExerciseCatalogItem]

  init(item: WeekPlanItem, catalog: [ExerciseCatalogItem]) {
    weekday = item.weekday
    self.catalog = catalog
    name = item.name
    focus = item.focus
    estimatedMinutes = item.estimatedMinutes
    exercises = item.exercises
  }

  private var namesById: [String: String] {
    Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0.name) })
  }

  private var canSave: Bool {
    name.trimmingCharacters(in: .whitespaces).count >= 2
      && focus.trimmingCharacters(in: .whitespaces).count >= 2
      && !exercises.isEmpty && exercises.count <= 12
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Treino") {
          TextField("nome", text: $name)
          TextField("foco", text: $focus)
          Stepper(value: $estimatedMinutes, in: 15...180, step: 5) {
            Text("\(estimatedMinutes) min").monospacedDigit()
          }
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
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancelar") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Salvar") { save() }.disabled(!canSave)
        }
      }
      .sheet(isPresented: $isPickingExercise) {
        ExercisePicker(catalog: catalog, chosen: Set(exercises.map(\.exerciseId))) { item in
          exercises.append(
            PlanExercise(
              exerciseId: item.id, prepSets: 2, workSets: 2, repsMin: 8, repsMax: 12,
              workToFailure: true, startingWeightKg: 20))
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
    dismiss()
    Task { await store.saveWorkout(input) }
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
