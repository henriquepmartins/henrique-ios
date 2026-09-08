import HenriqueCore
import HenriqueUI
import SwiftUI

@main
struct HenriqueApp: App {
  @State private var store = AppConfiguration.makeStore()

  var body: some Scene {
    WindowGroup {
      RootView(store: store, initialTab: AppConfiguration.initialTab)
    }
  }
}

enum AppConfiguration {
  /// `--amostra` abre o app com o painel de exemplo, sem rede e sem login. É
  /// como olhar as telas com o servidor desligado.
  @MainActor static func makeStore() -> AcademiaStore {
    #if DEBUG
      if CommandLine.arguments.contains("--amostra") {
        return AcademiaStore(sample: .sample)
      }
    #endif
    return AcademiaStore(
      client: APIClient(baseURL: baseURL, tokenStore: KeychainTokenStore()))
  }

  /// `--aba progresso` abre direto naquela aba, para olhar uma tela sem navegar
  /// até ela.
  static var initialTab: AcademiaTab {
    #if DEBUG
      let arguments = CommandLine.arguments
      if let index = arguments.firstIndex(of: "--aba"), index + 1 < arguments.count,
        let tab = AcademiaTab(rawValue: arguments[index + 1])
      {
        return tab
      }
    #endif
    return .hoje
  }

  /// O endereço da API vem do Info.plist para o build de simulador apontar para
  /// o servidor local sem recompilar o app com outra constante embutida.
  static var baseURL: URL {
    let raw = Bundle.main.object(forInfoDictionaryKey: "HenriqueAPIBaseURL") as? String
    guard let raw, let url = URL(string: raw) else {
      fatalError("HenriqueAPIBaseURL faltando ou inválida no Info.plist")
    }
    return url
  }
}
