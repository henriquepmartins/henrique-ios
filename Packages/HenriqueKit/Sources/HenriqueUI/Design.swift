import SwiftUI

extension Color {
  static let canvas = Color(hex: 0xfaf9f7)
  static let ink = Color(hex: 0x1a1a19)
  static let mutedInk = Color(hex: 0x6b6b6a)
  static let surfaceMuted = Color(hex: 0xf0efed)
}

/// A paleta dos cards de treino. Um card não tem cor própria, ele herda a vaga
/// que calhou na lista, então o par vem endereçado por índice e não por nome do
/// treino. O tom escuro é o único legível sobre os dois extremos do degradê.
struct WorkoutTone: Sendable, Hashable {
  let top: Color
  let bottom: Color
  let ink: Color

  static let all: [WorkoutTone] = [
    WorkoutTone(top: 0xf9_7316, bottom: 0xfd_ba74, ink: 0x43_1407),
    WorkoutTone(top: 0x3b_82f6, bottom: 0x93_c5fd, ink: 0x17_2554),
    WorkoutTone(top: 0x8b_5cf6, bottom: 0xc4_b5fd, ink: 0x2e_1065),
    WorkoutTone(top: 0xef_4444, bottom: 0xfc_a5a5, ink: 0x45_0a0a),
    WorkoutTone(top: 0x22_c55e, bottom: 0x86_efac, ink: 0x05_2e16),
    WorkoutTone(top: 0xec_4899, bottom: 0xf9_a8d4, ink: 0x50_0724),
  ]

  /// Dá a volta na lista sozinho, então quem chama nunca precisa saber que são
  /// seis nem tratar índice negativo.
  static func at(_ index: Int) -> WorkoutTone {
    all[((index % all.count) + all.count) % all.count]
  }

  private init(top: UInt32, bottom: UInt32, ink: UInt32) {
    self.top = Color(hex: top)
    self.bottom = Color(hex: bottom)
    self.ink = Color(hex: ink)
  }
}

extension View {
  func paperCard(radius: CGFloat = 28) -> some View {
    background(.white, in: .rect(cornerRadius: radius))
      .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color.ink.opacity(0.08)))
  }
}

struct PageHeading: View {
  @Environment(\.accent) private var accent
  @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 40.0
  let eyebrow: String
  let title: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(eyebrow).font(.caption).foregroundStyle(accent.base)
      Text(title).font(.system(size: titleSize, weight: .medium)).tracking(-titleSize * 0.055)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
      if !subtitle.isEmpty {
        Text(subtitle).font(.subheadline).foregroundStyle(Color.mutedInk)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Movimento

struct StudyPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    Press(configuration: configuration)
  }

  private struct Press: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let configuration: ButtonStyleConfiguration

    var body: some View {
      configuration.label
        .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
        .opacity(configuration.isPressed && reduceMotion ? 0.7 : 1)
        // O encolher acontece no mesmo quadro do toque. Só a volta tem curva,
        // senão o botão parece responder atrasado ao dedo.
        .animation(configuration.isPressed ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
  }
}

extension View {
  /// Entrada em cascata da primeira montagem da lista. `isReady` é o momento em
  /// que os dados chegaram; o atraso para no oitavo item para a última linha não
  /// esperar meio segundo.
  func staggeredEntrance(index: Int, isReady: Bool) -> some View {
    modifier(StudyStaggeredEntrance(index: index, isReady: isReady))
  }
}

private struct StudyStaggeredEntrance: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var shown = false
  let index: Int
  let isReady: Bool

  func body(content: Content) -> some View {
    content
      .opacity(shown ? 1 : 0)
      .offset(y: shown || reduceMotion ? 0 : 12)
      .onChange(of: isReady, initial: true) { _, ready in
        guard ready, !shown else { return }
        withAnimation(animation) { shown = true }
      }
  }

  private var animation: Animation {
    reduceMotion
      ? .easeOut(duration: 0.15)
      : .easeOut(duration: 0.35).delay(0.06 * Double(min(index, 8)))
  }
}

extension View {
  @ViewBuilder
  func decimalInput() -> some View {
    #if os(iOS)
    self.keyboardType(.decimalPad)
    #else
    self
    #endif
  }
}
