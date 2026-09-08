import SwiftUI

public enum Accent: String, CaseIterable, Identifiable, Sendable, Codable {
  case verde, rosa, vermelho, azul, amarelo, grafite

  public var id: String { rawValue }

  public var label: String {
    self == .grafite ? "preto e branco" : rawValue
  }

  public var base: Color {
    switch self {
    case .verde: Color(hex: 0x09_7860)
    case .rosa: Color(hex: 0xb0_3a6e)
    case .vermelho: Color(hex: 0xc0_3028)
    case .azul: Color(hex: 0x1f_5fbf)
    case .amarelo: Color(hex: 0x8a_6a08)
    case .grafite: Color(hex: 0x2e_2e2c)
    }
  }

  public var acid: Color {
    switch self {
    case .verde: Color(hex: 0xe1f96c)
    case .rosa: Color(hex: 0xffd3e6)
    case .vermelho: Color(hex: 0xffd6c2)
    case .azul: Color(hex: 0xcfe6ff)
    case .amarelo: Color(hex: 0xffeaa0)
    case .grafite: Color(hex: 0xe7e6e3)
    }
  }

  public var mint: Color {
    switch self {
    case .verde: Color(hex: 0x9fead9)
    case .rosa: Color(hex: 0xf7bcd6)
    case .vermelho: Color(hex: 0xf9c0b4)
    case .azul: Color(hex: 0xb3d1f7)
    case .amarelo: Color(hex: 0xf5dd9a)
    case .grafite: Color(hex: 0xd5d4d0)
    }
  }

  public var deep: Color {
    switch self {
    case .verde: Color(hex: 0x09_5544)
    case .rosa: Color(hex: 0x7c_2049)
    case .vermelho: Color(hex: 0x8a_1d18)
    case .azul: Color(hex: 0x12_3f85)
    case .amarelo: Color(hex: 0x5d_4705)
    case .grafite: Color(hex: 0x1a_1a19)
    }
  }

  public var pale: Color {
    switch self {
    case .verde: Color(hex: 0xce_e4df)
    case .rosa: Color(hex: 0xef_d8e3)
    case .vermelho: Color(hex: 0xf0_dad6)
    case .azul: Color(hex: 0xd6_e0f2)
    case .amarelo: Color(hex: 0xee_e3c8)
    case .grafite: Color(hex: 0xde_dddb)
    }
  }

  /// O tom de sinalização, usado onde o web usa `--acid`. É o verde-limão que
  /// marca a série concluída e a barra de progresso.
  public var signal: Color {
    switch self {
    case .verde: Color(hex: 0xae_c82f)
    case .rosa: Color(hex: 0xe5_8ab5)
    case .vermelho: Color(hex: 0xef_8f6a)
    case .azul: Color(hex: 0x6a_a8ef)
    case .amarelo: Color(hex: 0xd8_b02a)
    case .grafite: Color(hex: 0xa3_a29e)
    }
  }
}

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xff) / 255,
      green: Double((hex >> 8) & 0xff) / 255,
      blue: Double(hex & 0xff) / 255,
      opacity: 1)
  }
}

/// O acento escolhido desce pela árvore em vez de ser lido de um singleton,
/// então a pré-visualização consegue trocar de cor sem tocar em nada global.
///
/// Escrito à mão porque o macro `@Entry` só existe com o Xcode instalado, e essa
/// toolchain é só a das Command Line Tools.
private struct AccentKey: EnvironmentKey {
  static let defaultValue: Accent = .verde
}

extension EnvironmentValues {
  public var accent: Accent {
    get { self[AccentKey.self] }
    set { self[AccentKey.self] = newValue }
  }
}
