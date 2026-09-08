import SwiftUI

extension Color {
  static let canvas = Color(hex: 0xfaf9f7)
  static let ink = Color(hex: 0x1a1a19)
  static let mutedInk = Color(hex: 0x6b6b6a)
  static let surfaceMuted = Color(hex: 0xf0efed)
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
