import HenriqueCore
import SwiftUI

private enum SetupStep: Int, CaseIterable {
  case welcome, body, workout, exercises, goal, done

  var title: String {
    switch self {
    case .welcome: "seu treino começa aqui."
    case .body: "comece por você."
    case .workout: "um treino de cada vez."
    case .exercises: "o que vamos treinar?"
    case .goal: "algo para alcançar."
    case .done: "pronto para começar."
    }
  }
  var subtitle: String {
    switch self {
    case .welcome: "Seu plano, suas medidas e cada pequena evolução. Vamos deixar tudo pronto para o primeiro treino."
    case .body: "Uma primeira medida ajuda a acompanhar as mudanças. Registre apenas o que souber agora."
    case .workout: "Escolha um dia e dê um nome ao treino. Depois, você pode organizar o restante da semana."
    case .exercises: "Adicione os exercícios do seu plano. Você pode conferir as séries e ajustar cada um antes de salvar."
    case .goal: "Se já tiver uma meta de carga, registre aqui. Se ainda não souber, deixe para depois do primeiro treino."
    case .done: "O que você salvou já está no app. O restante pode ser preenchido quando fizer sentido para você."
    }
  }
}

struct SetupScreen: View {
  @Environment(AcademiaStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accent) private var accent
  @State private var step = SetupStep.welcome
  @State private var weight: Double?
  @State private var fat: Double?
  @State private var waist: Double?
  @State private var chest: Double?
  @State private var arm: Double?
  @State private var thigh: Double?
  @State private var weekday = CalendarDate.today.weekday()
  @State private var name = ""
  @State private var focus = ""
  @State private var minutes = 55
  @State private var exercises: [PlanExercise] = []
  @State private var goalExercise = ""
  @State private var target: Double?
  @State private var picking = false
  @State private var saving = false
  @State private var initialized = false
  @State private var workoutDrafts: [Int: SetupWorkoutDraft] = [:]
  @State private var error: String?
  @State private var savedBody: AddMeasurementInput?
  @State private var savedWorkout: SaveWorkoutInput?
  @State private var savedGoal: SetStrengthGoalInput?
  private let days = ["domingo", "segunda", "terça", "quarta", "quinta", "sexta", "sábado"]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          PageHeading(eyebrow: "primeiros passos", title: step.title, subtitle: step.subtitle)
          fields
          if let error { Text(error).font(.subheadline).foregroundStyle(.red).accessibilityAddTraits(.updatesFrequently) }
          HStack {
            if step != .welcome {
              Button("voltar") { step = SetupStep(rawValue: step.rawValue - 1) ?? .welcome; error = nil }
                .buttonStyle(.glass)
            }
            Spacer()
            Button(saving ? "salvando" : step == .done ? "abrir meu treino" : "continuar") {
              Task { await advance() }
            }.buttonStyle(.glassProminent).controlSize(.large)
          }
          if step != .welcome && step != .done {
            Button("deixar para depois") {
              step = step == .body ? .workout : step == .workout || step == .exercises ? .goal : .done
              error = nil
            }.font(.subheadline).frame(maxWidth: .infinity)
          }
          ProgressView(value: Double(step.rawValue + 1), total: 6).tint(accent.base)
            .accessibilityLabel("Etapa \(step.rawValue + 1) de 6")
        }.padding(24).disabled(saving)
      }
      .background(Color.canvas.ignoresSafeArea())
      .navigationTitle("h&")
      .toolbarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() }.disabled(saving) }
      }
      .interactiveDismissDisabled(saving)
      .sheet(isPresented: $picking) {
        ExercisePicker(catalog: store.dashboard?.exerciseCatalog ?? [], chosen: Set(exercises.map(\.exerciseId))) { item in
          exercises.append(PlanExercise(exerciseId: item.id, prepSets: 2, workSets: 2,
            repsMin: 8, repsMax: 12, workToFailure: true, startingWeightKg: 0))
        }
      }
      .onAppear {
        guard !initialized else { return }
        initialized = true
        weight = store.dashboard?.measurements.first?.weightKg
        fat = store.dashboard?.measurements.first?.bodyFatPercent
        waist = store.dashboard?.measurements.first?.waistCm
        goalExercise = store.dashboard?.strengthGoal?.exerciseId ?? store.dashboard?.exerciseCatalog.first?.id ?? ""
        target = store.dashboard?.strengthGoal?.targetValue
        loadWorkout()
      }
    }
  }

  @ViewBuilder private var fields: some View {
    switch step {
    case .welcome:
      Image(systemName: "dumbbell").font(.system(size: 56)).foregroundStyle(accent.deep)
        .frame(maxWidth: .infinity, minHeight: 180).background(accent.acid, in: .rect(cornerRadius: 36))
    case .body:
      VStack(spacing: 18) {
        measurement("peso", unit: "kg", value: $weight)
        measurement("gordura corporal", unit: "%", value: $fat)
        measurement("cintura", unit: "cm", value: $waist)
        measurement("peito", unit: "cm", value: $chest)
        measurement("braço", unit: "cm", value: $arm)
        measurement("coxa", unit: "cm", value: $thigh)
      }.padding(20).paperCard()
    case .workout:
      VStack(alignment: .leading, spacing: 18) {
        Picker("dia do treino", selection: $weekday) {
          ForEach(0..<7, id: \.self) { Text(days[$0]).tag($0) }
        }.onChange(of: weekday) { oldDay, _ in
          workoutDrafts[oldDay] = SetupWorkoutDraft(name: name, focus: focus, minutes: minutes, exercises: exercises)
          loadWorkout()
        }
        TextField("nome do treino", text: $name).textFieldStyle(.roundedBorder)
        TextField("foco do treino", text: $focus).textFieldStyle(.roundedBorder)
        HStack {
          Text("duração em minutos")
          TextField("55", value: $minutes, format: .number).decimalInput().multilineTextAlignment(.trailing)
        }
      }.padding(20).paperCard()
    case .exercises:
      VStack(spacing: 16) {
        ForEach($exercises) { $exercise in
          VStack(alignment: .leading) {
            PlanExerciseRow(exercise: $exercise,
              name: store.dashboard?.exerciseCatalog.first { $0.id == exercise.exerciseId }?.name ?? exercise.exerciseId)
            Button("remover", role: .destructive) { exercises.removeAll { $0.exerciseId == exercise.exerciseId } }
              .font(.caption)
          }.padding(18).paperCard()
        }
        Button("adicionar exercício", systemImage: "plus") { picking = true }
          .buttonStyle(.glass).disabled(exercises.count >= 12)
      }
    case .goal:
      VStack(alignment: .leading, spacing: 18) {
        Picker("exercício da meta", selection: $goalExercise) {
          ForEach(store.dashboard?.exerciseCatalog ?? []) { Text($0.name).tag($0.id) }
        }
        measurement("força estimada desejada", unit: "kg", value: $target)
      }.padding(20).paperCard()
    case .done:
      VStack(alignment: .leading, spacing: 16) {
        if savedBody != nil { Label("medidas registradas", systemImage: "checkmark.circle") }
        if savedWorkout != nil { Label("treino salvo", systemImage: "checkmark.circle") }
        if savedGoal != nil { Label("meta registrada", systemImage: "checkmark.circle") }
      }.foregroundStyle(accent.base)
    }
  }

  private func measurement(_ title: String, unit: String, value: Binding<Double?>) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.caption).foregroundStyle(Color.mutedInk)
      HStack {
        TextField("não informado", value: value, format: .number.precision(.fractionLength(0...2)))
          .decimalInput().accessibilityLabel(title)
        Text(unit).foregroundStyle(Color.mutedInk)
      }
    }
  }

  private func loadWorkout() {
    if let draft = workoutDrafts[weekday] {
      name = draft.name
      focus = draft.focus
      minutes = draft.minutes
      exercises = draft.exercises
      return
    }
    let item = store.dashboard?.weekPlan.first { $0.weekday == weekday }
    name = item?.name ?? ""
    focus = item?.focus ?? ""
    minutes = item?.estimatedMinutes ?? 55
    exercises = item?.exercises ?? []
  }

  private func advance() async {
    guard !saving else { return }
    saving = true
    error = nil
    defer { saving = false }
    switch step {
    case .welcome: step = .body
    case .body:
      guard let weight, weight > 0, weight <= 500 else { error = "Confira o peso ou deixe esta etapa para depois."; return }
      let input = AddMeasurementInput(date: .today, weightKg: weight, bodyFatPercent: fat, waistCm: waist, chestCm: chest, armCm: arm, thighCm: thigh)
      if input != savedBody {
        guard await store.addMeasurement(input) else { error = store.banner; return }
        savedBody = input
      }
      step = .workout
    case .workout:
      guard name.trimmingCharacters(in: .whitespaces).count >= 2, (15...180).contains(minutes) else {
        error = "Dê um nome ao treino e use uma duração de 15 a 180 minutos."; return
      }
      step = .exercises
    case .exercises:
      guard !exercises.isEmpty, exercises.allSatisfy({ $0.repsMin <= $0.repsMax && $0.startingWeightKg >= 0 }) else {
        error = "Adicione um exercício e confira as séries, repetições e cargas."; return
      }
      let groups = exercises.compactMap { exercise in store.dashboard?.exerciseCatalog.first { $0.id == exercise.exerciseId }?.muscleGroup }
      let input = SaveWorkoutInput(date: store.selectedDate, weekday: weekday, name: name,
        focus: focus.isEmpty ? Array(Set(groups)).sorted().joined(separator: ", ") : focus, estimatedMinutes: minutes, exercises: exercises)
      if input != savedWorkout {
        guard await store.saveWorkout(input) else { error = store.banner; return }
        savedWorkout = input
      }
      step = .goal
    case .goal:
      guard let target, target > 0, !goalExercise.isEmpty else { error = "Confira a meta ou deixe esta etapa para depois."; return }
      let input = SetStrengthGoalInput(date: store.selectedDate, exerciseId: goalExercise, targetValue: target)
      if input != savedGoal {
        guard await store.setStrengthGoal(input) else { error = store.banner; return }
        savedGoal = input
      }
      step = .done
    case .done:
      if await store.completeSetup() { dismiss() } else { error = store.banner }
    }
  }
}

private struct SetupWorkoutDraft {
  let name: String
  let focus: String
  let minutes: Int
  let exercises: [PlanExercise]
}
