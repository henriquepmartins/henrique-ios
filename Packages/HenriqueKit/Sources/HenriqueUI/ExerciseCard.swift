import HenriqueCore
import SwiftUI

struct ExerciseCard: View {
  @Environment(AcademiaStore.self) private var store
  @Environment(\.accent) private var accent
  let exercise: DashboardExercise
  let isOpen: Bool
  let onToggle: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      Button(action: onToggle) {
        HStack(spacing: 12) {
          Image(systemName: "dumbbell").font(.title3).foregroundStyle(accent.base)
            .frame(width: 48, height: 48).background(accent.pale.opacity(0.4), in: .circle)
          VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name.lowercased()).font(.headline.weight(.medium))
            Text(prescription).font(.caption).foregroundStyle(Color.mutedInk)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 0)
          Text("\(exercise.sets.completedWorkCount)/\(exercise.prescription.workSets)")
            .font(.caption).monospacedDigit().foregroundStyle(Color.mutedInk)
          Image(systemName: isOpen ? "chevron.up" : "chevron.down").font(.caption2)
        }.padding(16).frame(minHeight: 92).contentShape(.rect)
      }.buttonStyle(.plain).accessibilityValue(isOpen ? "expandido" : "recolhido")
      if isOpen {
        VStack(spacing: 8) {
          HStack {
            Text("série").frame(width: 34, alignment: .leading)
            Text("peso").frame(maxWidth: .infinity)
            Text("reps").frame(maxWidth: .infinity)
            Text("feita").frame(width: 44)
          }.font(.caption2).foregroundStyle(Color.mutedInk)
          if !exercise.sets.prep.isEmpty {
            group("preparação", color: .mutedInk)
            ForEach(exercise.sets.prep) { set in
              TrainingSetRow(exercise: exercise, kind: .prep, index: set.index,
                weight: set.weightKg, repetitions: set.reps, done: set.isDone, failure: false)
            }
          }
          group(exercise.prescription.workToFailure ? "valendo, até a falha" : "valendo", color: accent.base)
          ForEach(exercise.sets.work) { set in
            TrainingSetRow(exercise: exercise, kind: .work, index: set.index,
              weight: set.weightKg, repetitions: set.reps, done: set.isDone, failure: set.toFailure)
          }
          Text(previous).font(.caption).foregroundStyle(Color.mutedInk)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
        }.padding(14).background(.white, in: .rect(cornerRadius: 24)).padding(6)
          .transition(.opacity)
      }
    }
    .background(Color.surfaceMuted, in: .rect(cornerRadius: 30))
    .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(Color.ink.opacity(0.08)))
  }

  private var prescription: String {
    let p = exercise.prescription
    let prep = p.prepSets > 0 ? "\(p.prepSets) prep + " : ""
    let work = p.workToFailure ? "\(p.workSets) até a falha" : "\(p.workSets) valendo de \(p.repsMin) a \(p.repsMax)"
    return "\(prep)\(work) · \(weightLabel(exercise.previous?.weightKg ?? p.startingWeightKg))"
  }
  private var previous: String {
    guard let previous = exercise.previous else {
      return "comece com \(weightLabel(exercise.prescription.startingWeightKg)) e ajuste pela execução"
    }
    return "última vez: \(previous.reps.map(String.init).joined(separator: ", ")) reps com \(weightLabel(previous.weightKg))"
  }
  private func group(_ title: String, color: Color) -> some View {
    HStack(spacing: 6) {
      Circle().fill(color).frame(width: 5, height: 5)
      Text(title).font(.caption)
      Spacer()
    }.foregroundStyle(color).padding(.top, 8)
  }
}

struct TrainingSetRow: View {
  @Environment(AcademiaStore.self) private var store
  @Environment(\.accent) private var accent
  @State private var weightDraft: Double?
  @State private var repsDraft: Int?
  let exercise: DashboardExercise
  let kind: SetKey.Kind
  let index: Int
  let weight: Double
  let repetitions: Int
  let done: Bool
  let failure: Bool

  private var key: SetKey { .init(exerciseId: exercise.id, kind: kind, index: index) }
  private var saving: Bool { store.inFlight.contains(key) }

  var body: some View {
    HStack(spacing: 8) {
      Text(kind == .prep ? "P\(index)" : "\(index)").font(.caption).frame(width: 26)
      HStack(spacing: 2) {
        TextField("0", value: $weightDraft, format: .number.precision(.fractionLength(0...2)))
          #if os(iOS)
          .keyboardType(.decimalPad)
          #endif
          .accessibilityLabel("Peso da série \(index)")
        Text("kg").font(.caption2).foregroundStyle(Color.mutedInk)
      }.padding(8).background(.white, in: .rect(cornerRadius: 10))
      HStack(spacing: 2) {
        TextField("0", value: $repsDraft, format: .number)
          #if os(iOS)
          .keyboardType(.numberPad)
          #endif
          .accessibilityLabel("Repetições da série \(index)")
        if failure { Text("falha").font(.system(size: 9)).foregroundStyle(accent.base) }
      }.padding(8).background(.white, in: .rect(cornerRadius: 10))
      Button {
        Task {
          await store.record(exercise: exercise, kind: kind, index: index,
            weightKg: weightDraft ?? weight, reps: repsDraft ?? repetitions,
            completed: !done, toFailure: failure)
        }
      } label: {
        Image(systemName: "checkmark").font(.body.weight(.semibold))
          .frame(width: 44, height: 44)
          .foregroundStyle(done ? accent.deep : Color.mutedInk.opacity(0.5))
          .background(done ? accent.acid : .white, in: .rect(cornerRadius: 12))
      }.buttonStyle(.plain).disabled(saving || (weightDraft ?? -1) < 0 || (repsDraft ?? 0) < 1)
        .accessibilityLabel(done ? "Desmarcar série \(index)" : "Concluir série \(index)")
        .sensoryFeedback(.success, trigger: done)
    }
    .font(.subheadline).monospacedDigit().multilineTextAlignment(.center)
    .padding(6).background(kind == .prep ? Color.surfaceMuted : accent.pale.opacity(0.5), in: .rect(cornerRadius: 16))
    .onChange(of: weight, initial: true) { weightDraft = weight }
    .onChange(of: repetitions, initial: true) { repsDraft = repetitions }
  }
}

func weightLabel(_ kilograms: Double) -> String {
  kilograms.formatted(.number.precision(.fractionLength(0...1))) + " kg"
}
