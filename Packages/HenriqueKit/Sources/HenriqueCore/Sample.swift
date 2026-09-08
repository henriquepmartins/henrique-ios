import Foundation

extension Dashboard {
  /// Um painel completo, com treino em andamento, histórico e meta. Alimenta as
  /// pré-visualizações do Xcode e o modo `--amostra` do app, que é como dá para
  /// mexer nas telas sem servidor rodando.
  public static let sample: Dashboard = {
    guard let url = Bundle.module.url(forResource: "amostra", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let dashboard = try? JSONDecoder.henrique().decode(Dashboard.self, from: data)
    else {
      fatalError("amostra.json faltando ou fora do contrato")
    }
    return dashboard
  }()
}
