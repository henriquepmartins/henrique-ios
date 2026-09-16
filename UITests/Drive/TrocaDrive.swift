import XCTest

/// Dirige só a troca de app, na casca, para a gravação de tela pegar a barra
/// inferior quadro a quadro. Não precisa de servidor nem de sessão.
final class TrocaDrive: XCTestCase {
  let app = XCUIApplication(bundleIdentifier: "app.henrique.academia")

  override func setUp() { continueAfterFailure = false }

  func testTrocaDeApp() {
    app.terminate()
    app.launchArguments = ["--casca", "--app", "academia", "--aba", "treino"]
    app.launch()

    let bubble = app.tabBars.buttons["apps"]
    XCTAssert(bubble.waitForExistence(timeout: 10), "bolha de apps na barra")

    for destino in ["estudos", "academia", "estudos", "academia"] {
      bubble.tap()
      let row = app.buttons[destino]
      XCTAssert(row.waitForExistence(timeout: 5), "painel listou \(destino)")
      row.tap()
      Thread.sleep(forTimeInterval: 2.5)
    }
  }
}
