import SwiftUI

extension Color {
  static let canvas = Color(hex: 0xfaf9f7)
  static let ink = Color(hex: 0x1a1a19)
  static let mutedInk = Color(hex: 0x6b6b6a)
  static let surfaceMuted = Color(hex: 0xf0efed)
}

/// A paleta dos cards de treino. Um treino sem cor escolhida herda o tom do seu
/// primeiro dia, então o par também vem endereçado por índice. O tom escuro é o
/// único legível sobre os dois extremos do degradê.
struct WorkoutTone: Sendable, Hashable {
  let top: Color
  let bottom: Color
  let ink: Color
  /// `#rrggbb` do topo. Um treino novo nasce com o primeiro hex da paleta que
  /// nenhum outro treino usa.
  let hex: String
  /// O topo em matiz, saturação e brilho, o ponto de partida do seletor.
  let color: WorkoutColor

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

  /// O tom de uma cor qualquer do servidor. Nulo quando a string não é `#rrggbb`.
  static func from(hex: String) -> WorkoutTone? {
    WorkoutColor(hex: hex)?.tone
  }

  /// O primeiro tom da paleta fora de `used`. Com a paleta esgotada, dá a volta.
  static func unused(among used: [String]) -> WorkoutTone {
    let taken = Set(used.map { $0.lowercased() })
    return all.first { !taken.contains($0.hex) } ?? at(used.count)
  }

  private init(top: UInt32, bottom: UInt32, ink: UInt32) {
    self.top = Color(hex: top)
    self.bottom = Color(hex: bottom)
    self.ink = Color(hex: ink)
    hex = String(format: "#%06x", top)
    color = WorkoutColor(rgb: top)
  }

  fileprivate init(top: Color, bottom: Color, ink: Color, color: WorkoutColor) {
    self.top = top
    self.bottom = bottom
    self.ink = ink
    self.color = color
    hex = color.hex
  }
}

/// A cor do treino como o seletor mexe nela. Fica em matiz, saturação e brilho
/// porque é isso que o dedo arrasta; o hex só entra e sai na borda do servidor.
struct WorkoutColor: Hashable, Sendable {
  var hue: Double
  var saturation: Double
  var brightness: Double

  init(hue: Double, saturation: Double, brightness: Double) {
    self.hue = hue
    self.saturation = saturation
    self.brightness = brightness
  }

  init?(hex: String) {
    var digits = Substring(hex)
    if digits.hasPrefix("#") { digits = digits.dropFirst() }
    guard digits.count == 6, let rgb = UInt32(digits, radix: 16) else { return nil }
    self.init(rgb: rgb)
  }

  init(rgb: UInt32) {
    let r = Double((rgb >> 16) & 0xff) / 255
    let g = Double((rgb >> 8) & 0xff) / 255
    let b = Double(rgb & 0xff) / 255
    let high = max(r, g, b)
    let low = min(r, g, b)
    let delta = high - low
    brightness = high
    saturation = high == 0 ? 0 : delta / high
    if delta == 0 {
      hue = 0
    } else if high == r {
      hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6) / 6
    } else if high == g {
      hue = ((b - r) / delta + 2) / 6
    } else {
      hue = ((r - g) / delta + 4) / 6
    }
    if hue < 0 { hue += 1 }
  }

  var hex: String {
    let (r, g, b) = rgb
    return String(format: "#%02x%02x%02x", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
  }

  /// O par de degradê e a tinta, com a mesma fórmula que gerou a paleta fixa.
  /// Abaixo de 0.4 de brilho a tinta vira branca, porque tinta escura sobre
  /// bloco escuro some.
  var tone: WorkoutTone {
    WorkoutTone(
      top: Color(hue: hue, saturation: saturation, brightness: brightness),
      bottom: Color(hue: hue, saturation: saturation * 0.55, brightness: min(1, brightness * 0.25 + 0.75)),
      ink: brightness < 0.4
        ? .white
        : Color(hue: hue, saturation: min(1, saturation * 1.1), brightness: brightness * 0.26),
      color: self)
  }

  private var rgb: (Double, Double, Double) {
    let c = brightness * saturation
    let sector = hue * 6
    let x = c * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
    let m = brightness - c
    let (r, g, b): (Double, Double, Double) =
      switch Int(sector) % 6 {
      case 0: (c, x, 0)
      case 1: (x, c, 0)
      case 2: (0, c, x)
      case 3: (0, x, c)
      case 4: (x, 0, c)
      default: (c, 0, x)
      }
    return (r + m, g + m, b + m)
  }
}

extension View {
  func paperCard(radius: CGFloat = 28) -> some View {
    background(.white, in: .rect(cornerRadius: radius))
      .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color.ink.opacity(0.08)))
  }
}

struct PageHeading: View {
  @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 40.0
  let title: String

  var body: some View {
    Text(title).font(.system(size: titleSize, weight: .medium)).tracking(-titleSize * 0.055)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityAddTraits(.isHeader)
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

#if os(iOS)
import UIKit
#endif

extension View {
  func keyboardDone() -> some View {
    modifier(KeyboardDone())
  }
}

private struct KeyboardDone: ViewModifier {
  func body(content: Content) -> some View {
    #if os(iOS)
    content
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          KeyboardDoneButton()
        }
      }
      .onSubmit { dismissKeyboard() }
    #else
    content
    #endif
  }
}

struct KeyboardDoneButton: View {
  var body: some View {
    Button("concluído", action: dismissKeyboard)
      .accessibilityIdentifier("keyboard.done")
  }
}

@MainActor
func dismissKeyboard() {
  #if os(iOS)
  UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
    to: nil, from: nil, for: nil)
  #endif
}
