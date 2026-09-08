import HenriqueCore
import SwiftUI

/// O que a folha edita. A identidade é a própria série, então abrir a folha de
/// outra linha troca o conteúdo em vez de empilhar.
struct SetDraft: Identifiable, Equatable {
  let exerciseId: String
  let kind: SetKey.Kind
  let index: Int
  var weightKg: Double
  var reps: Int
  var toFailure: Bool

  var id: SetKey { SetKey(exerciseId: exerciseId, kind: kind, index: index) }
}

struct SetEditorSheet: View {
  @Environment(AcademiaStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var weightKg: Double
  @State private var reps: Int
  @State private var toFailure: Bool

  private let draft: SetDraft
  private let exercise: DashboardExercise

  init(draft: SetDraft, exercise: DashboardExercise) {
    self.draft = draft
    self.exercise = exercise
    weightKg = draft.weightKg
    reps = draft.reps
    toFailure = draft.toFailure
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Carga") {
          WeightStepper(weightKg: $weightKg)
        }
        Section("Repetições") {
          Stepper(value: $reps, in: 1...100) {
            Text("\(reps)").monospacedDigit()
          }
          Text("A prescrição pede \(exercise.prescription.repsLabel).")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        if draft.kind == .work {
          Section {
            Toggle("Levei até a falha", isOn: $toFailure)
          } footer: {
            Text("Falha é parar quando não sai mais nenhuma repetição com a técnica certa.")
          }
        }
      }
      .navigationTitle("Série \(draft.index)")
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
    .presentationDetents([.medium])
  }

  private func save() {
    let weight = weightKg
    let repetitions = reps
    let failure = toFailure
    dismiss()
    Task {
      await store.record(
        exercise: exercise, kind: draft.kind, index: draft.index, weightKg: weight,
        reps: repetitions, completed: true, toFailure: failure)
    }
  }
}

/// A anilha menor da academia é de 1,25 kg de cada lado, então o passo de 2,5 kg
/// é a menor mudança que dá para montar de verdade na barra.
struct WeightStepper: View {
  @Binding var weightKg: Double

  var body: some View {
    Stepper(value: $weightKg, in: 0...1_000, step: 2.5) {
      Text(weightLabel(weightKg)).monospacedDigit()
    }
  }
}
