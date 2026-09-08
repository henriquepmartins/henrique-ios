import HenriqueCore
import HenriqueUI
import SwiftUI

@main
struct HenriqueApp: App {
  @State private var store = AcademiaStore(
    client: APIClient(baseURL: AppConfiguration.baseURL, tokenStore: KeychainTokenStore()))

  var body: some Scene {
    WindowGroup {
      RootView(store: store)
    }
  }
}

enum AppConfiguration {
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
