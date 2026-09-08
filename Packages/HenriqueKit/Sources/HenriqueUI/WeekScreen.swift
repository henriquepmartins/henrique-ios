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
                                   count: textSize.isAccessibilitySize ? 1 : 2), spacing: 18) {
            ForEach(Array(dashboard.weekPlan.enumerated()), id: \.element.id) { index, item in
              WorkoutFolder(item: item, tone: index % 4,
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

private struct WorkoutFolder: View {
  let item: WeekPlanItem
  let tone: Int
  let onEdit: () -> Void
  let onStart: () -> Void

  private var face: Color {
    [Color(red: 11/255, green: 103/255, blue: 84/255),
     Color(red: 88/255, green: 102/255, blue: 46/255),
     Color(red: 117/255, green: 68/255, blue: 93/255),
     Color(red: 86/255, green: 86/255, blue: 83/255)][tone]
  }
  private var paper: Color {
    [Color(red: 159/255, green: 234/255, blue: 217/255),
     Color(red: 225/255, green: 249/255, blue: 108/255),
     Color(red: 255/255, green: 160/255, blue: 223/255),
     Color(red: 219/255, green: 218/255, blue: 217/255)][tone]
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: 23).fill(face.opacity(0.8)).padding(.top, 22)
      UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12)
        .fill(face.opacity(0.8)).frame(width: 78, height: 36).offset(y: 10)
      RoundedRectangle(cornerRadius: 15).fill(paper.opacity(0.75))
        .padding(.horizontal, 15).padding(.top, 20).padding(.bottom, 35).rotationEffect(.degrees(-4))
      RoundedRectangle(cornerRadius: 15).fill(paper)
        .padding(.horizontal, 10).padding(.top, 28).padding(.bottom, 25).rotationEffect(.degrees(3))
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top, spacing: 2) {
          VStack(alignment: .leading, spacing: 5) {
            Text(planWeekdays[item.weekday]).font(.caption)
            Text(item.name).font(.system(.title3, weight: .medium)).tracking(-0.6)
          }
          Spacer(minLength: 0)
          Button(action: onEdit) { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
            .buttonStyle(.plain)
            .accessibilityLabel("Editar \(item.name)")
        }
        Spacer(minLength: 0)
        Text(item.focus).font(.caption)
        Text("\(item.exerciseCount) exercícios · \(item.estimatedMinutes) min")
          .font(.caption2).monospacedDigit()
        Button(action: onStart) {
          Label("iniciar treino", systemImage: "play.fill")
            .font(.caption.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.glass)
      }
      .padding(14)
      .foregroundStyle(.white)
      .background(face.gradient, in: .rect(cornerRadius: 22))
      .padding(.top, 48)
    }
    .frame(minHeight: 246)
    .shadow(color: face.opacity(0.13), radius: 16, y: 10)
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
