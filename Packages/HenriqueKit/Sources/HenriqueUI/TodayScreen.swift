import HenriqueCore
import SwiftUI

public struct TodayScreen: View {
  @Environment(AcademiaStore.self) private var store

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        if let dashboard = store.dashboard {
          DayStrip(selected: dashboard.date)
          StatsRow(
            streak: dashboard.currentStreak,
            weeklyCompleted: dashboard.weeklyCompleted,
            weeklyPlanned: dashboard.weeklyPlanned,
            consistencyPercent: dashboard.consistencyPercent)

          if let workout = dashboard.workout {
            WorkoutHeaderCard(
              name: workout.name, focus: workout.focus, estimatedMinutes: workout.estimatedMinutes,
              completedWorkSetCount: workout.completedWorkSetCount,
              workSetCount: workout.workSetCount, completionPercent: workout.completionPercent)

            ForEach(workout.exercises) { exercise in
              ExerciseCard(exercise: exercise)
            }
          } else {
            RestDayCard()
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 40)
    }
    .scrollBounceBehavior(.basedOnSize)
    .navigationTitle("Hoje")
    .refreshable { await store.load() }
    .overlay { TodayPlaceholder(phase: store.phase) }
  }
}

/// Cobre a tela só enquanto não há painel para mostrar. Depois do primeiro
/// carregamento a falha vira faixa e o conteúdo antigo continua de pé.
struct TodayPlaceholder: View {
  let phase: AcademiaStore.Phase

  var body: some View {
    switch phase {
    case .loading:
      ProgressView().controlSize(.large)
    case .failed(let message):
      ContentUnavailableView("Não carregou", systemImage: "wifi.exclamationmark", description: Text(message))
    case .idle, .ready:
      EmptyView()
    }
  }
}

struct StatsRow: View {
  let streak: Int
  let weeklyCompleted: Int
  let weeklyPlanned: Int
  let consistencyPercent: Int

  var body: some View {
    GlassEffectContainer(spacing: 12) {
      HStack(spacing: 12) {
        StatTile(value: "\(streak)", caption: streak == 1 ? "treino seguido" : "treinos seguidos")
        StatTile(value: "\(weeklyCompleted)/\(weeklyPlanned)", caption: "nesta semana")
        StatTile(value: "\(consistencyPercent)%", caption: "constância")
      }
    }
  }
}

struct StatTile: View {
  @Environment(\.accent) private var accent
  let value: String
  let caption: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value)
        .font(.title2.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(accent.base)
      Text(caption)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 12)
    .padding(.horizontal, 14)
    .glassEffect(.regular, in: .rect(cornerRadius: 20))
  }
}

struct WorkoutHeaderCard: View {
  @Environment(\.accent) private var accent
  let name: String
  let focus: String
  let estimatedMinutes: Int
  let completedWorkSetCount: Int
  let workSetCount: Int
  let completionPercent: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text(name).font(.largeTitle.weight(.semibold))
        Text(focus).font(.callout).foregroundStyle(.secondary)
      }

      HStack(spacing: 10) {
        Label("\(estimatedMinutes) min", systemImage: "clock")
        Label("\(completedWorkSetCount) de \(workSetCount) séries", systemImage: "checkmark.circle")
      }
      .font(.footnote)
      .foregroundStyle(.secondary)

      ProgressView(value: Double(completionPercent), total: 100)
        .tint(accent.signal)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .glassEffect(.regular.tint(accent.pale.opacity(0.5)), in: .rect(cornerRadius: 28))
  }
}

struct RestDayCard: View {
  var body: some View {
    ContentUnavailableView(
      "Hoje é descanso",
      systemImage: "moon.zzz",
      description: Text("Nenhum treino marcado para este dia. Você pode montar um na aba Semana."))
      .padding(.vertical, 40)
  }
}
