import HenriqueCore
import SwiftUI

/// O laranja da chama não é o acento do app. A sequência é a mesma coisa em
/// qualquer cor escolhida, então ela pega a primeira vaga da paleta de treino e
/// fica com ela.
private let streakTone = WorkoutTone.all[0]

/// Tudo o que as duas telas do streak precisam. `week` é nulo quando o servidor
/// não mandou `sessionDates`. Aí nenhum dia sairia como feito e a fita
/// desenharia uma semana perdida que talvez nunca tenha existido. Some sem
/// aviso; o resto dos números vem de campos próprios e continua honesto.
struct StreakSnapshot: Equatable {
  var streak: WorkoutStreak
  var week: [StreakDay]?

  init(dashboard: Dashboard, today: CalendarDate = .today) {
    let streak = WorkoutStreak(dashboard: dashboard, today: today)
    self.streak = streak
    self.week = dashboard.sessionDates == nil ? nil : streak.days
  }
}

// MARK: - O card de hoje

struct StreakCard: View {
  let snapshot: StreakSnapshot
  let action: () -> Void

  private var streak: WorkoutStreak { snapshot.streak }

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 14) {
          FlameBadge(size: 44)
          VStack(alignment: .leading, spacing: 2) {
            Text("\(streak.count)")
              .font(.system(size: 38, weight: .medium)).monospacedDigit()
              .contentTransition(.numericText())
              .animation(.smooth(duration: 0.3), value: streak.count)
            Text("treinos seguidos").font(.caption).foregroundStyle(Color.mutedInk)
          }
          Spacer(minLength: 0)
          Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold)).foregroundStyle(Color.mutedInk)
        }
        if let week = snapshot.week {
          StreakRibbon(days: week, style: .card)
        }
        Text("\(streak.weeklyCompleted) de \(streak.weeklyPlanned) nesta semana")
          .font(.caption).foregroundStyle(Color.mutedInk)
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
      .foregroundStyle(Color.ink)
      .paperCard()
    }
    .buttonStyle(StudyPressStyle())
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "\(streak.count) treinos seguidos, \(streak.weeklyCompleted) de \(streak.weeklyPlanned) nesta semana"
    )
    .accessibilityHint("Abre a sequência")
    .accessibilityAddTraits(.isButton)
  }
}

// MARK: - A tela cheia

struct StreakScreen: View {
  @Environment(\.dismiss) private var dismiss
  @State private var entered = false
  let snapshot: StreakSnapshot

  private var streak: WorkoutStreak { snapshot.streak }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 28) {
          StreakRing(streak: streak, entered: entered)
          if let week = snapshot.week {
            StreakRibbon(days: week, style: .screen, entered: entered)
          }
          Text("\(streak.weeklyCompleted) de \(streak.weeklyPlanned) nesta semana")
            .font(.subheadline).foregroundStyle(Color.mutedInk)
          keepGoing
        }
        .padding(20)
        .padding(.top, 8)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity)
      }
      .background(Color.canvas.ignoresSafeArea())
      .navigationTitle("sua sequência")
      .toolbarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Fechar") { dismiss() }
        }
      }
    }
    .presentationDragIndicator(.visible)
    .onAppear { entered = true }
  }

  private var keepGoing: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("como manter").font(.caption).foregroundStyle(streakTone.ink)
      Text(
        "A sequência segue de pé enquanto não passarem mais de cinco dias entre um treino e o outro. Treinou, a contagem anda."
      )
      .font(.subheadline).foregroundStyle(Color.mutedInk)
      .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .paperCard()
  }
}

// MARK: - O anel

private struct StreakRing: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let streak: WorkoutStreak
  let entered: Bool

  private let diameter: CGFloat = 216
  private let line: CGFloat = 18
  private let badge: CGFloat = 54

  var body: some View {
    ZStack {
      Circle().stroke(streakTone.bottom.opacity(0.32), lineWidth: line)
      Circle()
        .trim(from: 0, to: shownProgress)
        // Degradê reto e não angular: o angular emenda a última cor na primeira
        // bem no ponto onde o traço começa, e a ponta arredondada mostra o corte.
        .stroke(
          LinearGradient(
            colors: [streakTone.top, streakTone.bottom],
            startPoint: .topTrailing, endPoint: .bottomLeading),
          style: StrokeStyle(lineWidth: line, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(growth, value: entered)
      StreakCount(count: streak.count, entered: entered)
    }
    .frame(width: diameter, height: diameter)
    .modifier(AttentionPulse(active: streak.isAtRisk, trigger: entered))
    .overlay {
      if streak.isTodayDone, !reduceMotion {
        SparkBurst(trigger: entered, radius: diameter / 2)
      }
    }
    .overlay(alignment: .bottom) {
      FlamePulse(size: badge, isTodayDone: streak.isTodayDone, trigger: entered)
        .offset(y: badge / 2)
    }
    .padding(.bottom, badge / 2)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(streak.count) treinos seguidos")
  }

  private var shownProgress: Double { entered || reduceMotion ? streak.weekProgress : 0 }

  private var growth: Animation? {
    reduceMotion ? nil : .snappy(duration: 0.7, extraBounce: 0.25)
  }
}

/// O número parte do estado final e a entrada é um desvio que volta para ele.
/// Escrito assim porque o contrário deixa o número invisível se a animação não
/// chegar a rodar, e um número que some é pior do que um que não pula.
private struct StreakCount: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let count: Int
  let entered: Bool

  var body: some View {
    if reduceMotion {
      label
    } else {
      KeyframeAnimator(initialValue: CountPose(), trigger: entered) { pose in
        label.scaleEffect(pose.scale).opacity(pose.opacity)
      } keyframes: { _ in
        // O primeiro salto some com o número no mesmo quadro; o resto da espera
        // é o anel dando a volta sozinho.
        KeyframeTrack(\.scale) {
          LinearKeyframe(0.55, duration: 0.001)
          LinearKeyframe(0.55, duration: 0.3)
          SpringKeyframe(1.12, duration: 0.24, spring: .snappy)
          SpringKeyframe(1, duration: 0.22)
        }
        KeyframeTrack(\.opacity) {
          LinearKeyframe(0, duration: 0.001)
          LinearKeyframe(0, duration: 0.3)
          LinearKeyframe(1, duration: 0.14)
          LinearKeyframe(1, duration: 0.32)
        }
      }
    }
  }

  private var label: some View {
    VStack(spacing: 4) {
      Text("\(count)")
        .font(.system(size: 66, weight: .medium)).monospacedDigit()
        .contentTransition(.numericText())
      Text("treinos seguidos").font(.caption).foregroundStyle(Color.mutedInk)
    }
  }
}

private struct CountPose {
  var scale: Double = 1
  var opacity: Double = 1
}

/// Uma batida curta quando a sequência está por um fio. É aviso, não festa, e
/// acontece uma vez só.
private struct AttentionPulse: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let active: Bool
  let trigger: Bool

  func body(content: Content) -> some View {
    if active, !reduceMotion {
      PhaseAnimator([0, 1, 2, 3], trigger: trigger) { phase in
        content.scaleEffect(scale(phase))
      } animation: { phase in
        phase == 0 ? nil : .snappy(duration: 0.22, extraBounce: 0.35).delay(phase == 1 ? 0.8 : 0)
      }
    } else {
      content
    }
  }

  private func scale(_ phase: Int) -> Double {
    switch phase {
    case 1: 1.045
    case 2: 0.985
    default: 1
    }
  }
}

// MARK: - A chama

struct FlameBadge: View {
  let size: CGFloat

  var body: some View {
    Circle()
      .fill(
        LinearGradient(
          colors: [streakTone.top, streakTone.bottom], startPoint: .top, endPoint: .bottom)
      )
      .frame(width: size, height: size)
      .overlay {
        Image(systemName: "flame.fill")
          .font(.system(size: size * 0.46, weight: .semibold))
          .foregroundStyle(.white)
      }
      .overlay { Circle().strokeBorder(Color.canvas, lineWidth: 3) }
  }
}

private struct FlamePulse: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let size: CGFloat
  let isTodayDone: Bool
  let trigger: Bool

  var body: some View {
    if reduceMotion {
      FlameBadge(size: size)
    } else {
      PhaseAnimator(Array(beats.indices), trigger: trigger) { phase in
        FlameBadge(size: size).scaleEffect(beats[phase])
      } animation: { phase in
        phase == 0 ? nil : .snappy(duration: 0.26, extraBounce: 0.4).delay(phase == 1 ? 0.15 : 0)
      }
    }
  }

  /// Treinou hoje, a chama bate mais vezes e para. Pulsar para sempre numa tela
  /// parada gasta bateria e cansa o olho.
  private var beats: [Double] {
    isTodayDone ? [1, 1.2, 1, 1.14, 1, 1.09, 1] : [1, 1.16, 1]
  }
}

// MARK: - As faíscas

private struct SparkBurst: View {
  let trigger: Bool
  let radius: CGFloat

  private let sparks = 12

  var body: some View {
    ZStack {
      ForEach(Array(0..<sparks), id: \.self) { index in
        let angle = Double(index) / Double(sparks) * 2 * .pi - .pi / 2
        KeyframeAnimator(initialValue: SparkPose(), trigger: trigger) { pose in
          Circle()
            .fill(index.isMultiple(of: 2) ? streakTone.top : streakTone.bottom)
            .frame(width: 8, height: 8)
            .scaleEffect(pose.scale)
            .opacity(pose.opacity)
            .offset(
              x: cos(angle) * (radius + pose.distance),
              y: sin(angle) * (radius + pose.distance))
        } keyframes: { _ in
          KeyframeTrack(\.distance) {
            LinearKeyframe(0, duration: 0.26)
            SpringKeyframe(46, duration: 0.5, spring: .snappy)
          }
          KeyframeTrack(\.scale) {
            LinearKeyframe(0, duration: 0.26)
            SpringKeyframe(1.1, duration: 0.18)
            LinearKeyframe(0.45, duration: 0.32)
          }
          KeyframeTrack(\.opacity) {
            LinearKeyframe(0, duration: 0.26)
            LinearKeyframe(1, duration: 0.1)
            LinearKeyframe(0, duration: 0.4)
          }
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

private struct SparkPose {
  var distance: CGFloat = 0
  var scale: Double = 0
  var opacity: Double = 0
}

// MARK: - A fita dos sete dias

/// Os dois tamanhos da fita numa tabela só, para o card e a tela cheia nunca
/// discordarem sobre o que é um dia feito.
private enum StreakRibbonStyle {
  case card, screen

  var marker: CGFloat { self == .card ? 22 : 32 }
  var spacing: CGFloat { self == .card ? 4 : 6 }
  var showsWeekday: Bool { self == .screen }
  /// No card a cascata brigaria com a entrada escalonada da pilha inteira.
  var cascades: Bool { self == .screen }
}

private struct StreakRibbon: View {
  @Environment(\.accent) private var accent
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let days: [StreakDay]
  let style: StreakRibbonStyle
  var entered = true

  var body: some View {
    HStack(spacing: style.spacing) {
      ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
        VStack(spacing: 6) {
          if style.showsWeekday {
            // A inicial sozinha não serve em português, sexta, sábado e segunda
            // começam todas com s.
            Text(day.date.date(), format: .dateTime.weekday(.abbreviated))
              .font(.caption2).foregroundStyle(Color.mutedInk)
              .textCase(.lowercase)
          }
          DayMarker(
            day: day, isToday: index == days.count - 1, size: style.marker, accent: accent)
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(shown ? 1 : 0.35)
        .opacity(shown ? 1 : 0)
        .animation(cascade(index), value: entered)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
          Text(
            "\(day.date.date(), format: .dateTime.weekday(.wide)), \(day.state.spokenLabel)"))
      }
    }
  }

  private var shown: Bool { entered || reduceMotion || !style.cascades }

  private func cascade(_ index: Int) -> Animation? {
    guard style.cascades, !reduceMotion else { return nil }
    return .snappy(duration: 0.42, extraBounce: 0.35).delay(0.45 + 0.04 * Double(index))
  }
}

private struct DayMarker: View {
  let day: StreakDay
  let isToday: Bool
  let size: CGFloat
  let accent: Accent

  var body: some View {
    ZStack {
      if isToday {
        Circle()
          .strokeBorder(accent.base.opacity(0.5), lineWidth: 1.5)
          .frame(width: size + 9, height: size + 9)
      }
      mark.frame(width: size, height: size)
    }
    .frame(width: size + 10, height: size + 10)
  }

  @ViewBuilder
  private var mark: some View {
    switch day.state {
    case .done:
      Circle().fill(streakTone.top)
        .overlay {
          Image(systemName: "checkmark")
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(.white)
        }
    case .missed:
      Circle().strokeBorder(Color.ink.opacity(0.16), lineWidth: 1.5)
    case .rest:
      Circle().fill(Color.ink.opacity(0.16))
        .frame(width: size * 0.28, height: size * 0.28)
    case .planned:
      Circle().strokeBorder(accent.base, lineWidth: 2)
    case .open:
      Circle().fill(Color.ink.opacity(0.08))
        .frame(width: size * 0.28, height: size * 0.28)
    }
  }
}

extension StreakDayState {
  var spokenLabel: String {
    switch self {
    case .done: "treino feito"
    case .missed: "treino perdido"
    case .rest: "folga"
    case .planned: "treino planejado"
    case .open: "dia livre"
    }
  }
}
