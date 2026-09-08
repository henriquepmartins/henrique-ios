import HenriqueCore
import SwiftUI

struct ExerciseCard: View {
  @Environment(AcademiaStore.self) private var store
  @Environment(\.accent) private var accent
  @State private var draft: SetDraft?
  let exercise: DashboardExercise

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      ExerciseHeader(
        name: exercise.name, muscleGroup: exercise.muscleGroup, equipment: exercise.equipment,
        isComplete: exercise.isComplete)

      if let previous = exercise.previous {
        PreviousSessionLine(date: previous.date, weightKg: previous.weightKg, reps: previous.reps)
      }

      if !exercise.sets.prep.isEmpty {
        SetGroupLabel(title: "Aquecimento", detail: "leve, para preparar a articulação")
        ForEach(exercise.sets.prep) { set in
          SetRow(
            index: set.index, weightKg: set.weightKg, reps: set.reps, isDone: set.isDone,
            isToFailure: false, onEdit: { draft = draft(for: set) },
            onToggle: { toggle(prep: set) })
        }
      }

      SetGroupLabel(
        title: "Trabalho",
        detail: exercise.prescription.workToFailure
          ? "\(exercise.prescription.repsLabel) reps, última até a falha"
          : "\(exercise.prescription.repsLabel) reps")
      ForEach(exercise.sets.work) { set in
        SetRow(
          index: set.index, weightKg: set.weightKg, reps: set.reps, isDone: set.isDone,
          isToFailure: set.toFailure, onEdit: { draft = draft(for: set) },
          onToggle: { toggle(work: set) })
      }
    }
    .padding(18)
    .glassEffect(.regular, in: .rect(cornerRadius: 26))
    .sheet(item: $draft) { item in
      SetEditorSheet(draft: item, exercise: exercise)
    }
  }

  private func draft(for set: PrepSet) -> SetDraft {
    SetDraft(
      exerciseId: exercise.id, kind: .prep, index: set.index, weightKg: set.weightKg,
      reps: set.reps, toFailure: false)
  }

  private func draft(for set: WorkSet) -> SetDraft {
    SetDraft(
      exerciseId: exercise.id, kind: .work, index: set.index, weightKg: set.weightKg,
      reps: set.reps, toFailure: set.toFailure)
  }

  private func toggle(prep set: PrepSet) {
    Task {
      await store.record(
        exercise: exercise, kind: .prep, index: set.index, weightKg: set.weightKg, reps: set.reps,
        completed: !set.isDone, toFailure: false)
    }
  }

  private func toggle(work set: WorkSet) {
    Task {
      await store.record(
        exercise: exercise, kind: .work, index: set.index, weightKg: set.weightKg, reps: set.reps,
        completed: !set.isDone, toFailure: set.toFailure)
    }
  }
}

struct ExerciseHeader: View {
  @Environment(\.accent) private var accent
  let name: String
  let muscleGroup: String
  let equipment: String
  let isComplete: Bool

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 2) {
        Text(name).font(.headline)
        Text("\(muscleGroup) · \(equipment)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if isComplete {
        Image(systemName: "checkmark.seal.fill")
          .foregroundStyle(accent.base)
          .accessibilityLabel("exercício concluído")
      }
    }
  }
}

struct PreviousSessionLine: View {
  let date: CalendarDate
  let weightKg: Double
  let reps: [Int]

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "arrow.uturn.backward")
      Text(date.date(), format: .dateTime.day().month(.abbreviated))
      Text(weightLabel(weightKg))
      Text(reps.map(String.init).joined(separator: ", "))
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .accessibilityElement(children: .combine)
  }
}

struct SetGroupLabel: View {
  let title: String
  let detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(title).font(.subheadline.weight(.medium))
      Text(detail).font(.caption2).foregroundStyle(.secondary)
    }
    .padding(.top, 4)
  }
}

struct SetRow: View {
  @Environment(\.accent) private var accent
  let index: Int
  let weightKg: Double
  let reps: Int
  let isDone: Bool
  let isToFailure: Bool
  let onEdit: () -> Void
  let onToggle: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Text("\(index)")
        .font(.caption.weight(.medium))
        .monospacedDigit()
        .frame(width: 22, height: 22)
        .background(.quaternary, in: .circle)

      Button(action: onEdit) {
        HStack(spacing: 6) {
          Text(weightLabel(weightKg)).monospacedDigit()
          Text("×").foregroundStyle(.tertiary)
          Text("\(reps)").monospacedDigit()
          if isToFailure {
            Image(systemName: "flame.fill").font(.caption2).foregroundStyle(accent.signal)
          }
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("ajustar carga e repetições da série \(index)")

      Button(action: onToggle) {
        Image(systemName: isDone ? "checkmark" : "circle.dashed")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(isDone ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
          .frame(width: 34, height: 34)
          .contentTransition(.symbolEffect(.replace))
      }
      .buttonStyle(.plain)
      .glassEffect(
        isDone ? .regular.tint(accent.base).interactive() : .regular.interactive(), in: .circle)
      .accessibilityLabel(isDone ? "desmarcar série \(index)" : "marcar série \(index) como feita")
    }
    .padding(.vertical, 2)
  }
}

func weightLabel(_ kilograms: Double) -> String {
  Measurement(value: kilograms, unit: UnitMass.kilograms)
    .formatted(
      .measurement(
        width: .abbreviated, usage: .asProvided,
        numberFormatStyle: .number.precision(.fractionLength(0...1))))
}
