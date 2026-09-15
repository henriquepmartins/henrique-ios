import XCTest

final class FluxoDrive: XCTestCase {
  let app = XCUIApplication(bundleIdentifier: "app.henrique.academia")
  let env = ProcessInfo.processInfo.environment
  var shots: String { env["HENRIQUE_SHOTS"] ?? NSTemporaryDirectory() }

  override func setUp() {
    continueAfterFailure = false
    try? FileManager.default.createDirectory(atPath: shots, withIntermediateDirectories: true)
  }

  func shot(_ name: String) {
    let data = XCUIScreen.main.screenshot().pngRepresentation
    FileManager.default.createFile(atPath: "\(shots)/\(name).png", contents: data)
  }

  func launch(aba: String = "treino") {
    app.terminate()
    app.launchArguments = ["--app", "academia", "--aba", aba]
    app.launch()
    let user = app.textFields["usuário"]
    if user.waitForExistence(timeout: 4) {
      let banner = app.alerts.buttons["ok"]
      if banner.waitForExistence(timeout: 1) { banner.tap() }
      guard let username = env["HENRIQUE_TEST_USERNAME"], let password = env["HENRIQUE_TEST_PASSWORD"] else {
        XCTFail("faltam HENRIQUE_TEST_USERNAME e HENRIQUE_TEST_PASSWORD no ambiente")
        return
      }
      user.tap()
      user.typeText(username)
      let pass = app.secureTextFields["senha"]
      pass.tap()
      pass.typeText(password)
      app.buttons["entrar"].tap()
    }
    let counter = app.buttons["sequência"]
    XCTAssert(counter.waitForExistence(timeout: 15), "painel carregou depois do login")
    // O iOS oferece guardar a senha depois do primeiro login de cada instalação.
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    for notNow in [app.buttons["Not Now"], springboard.buttons["Not Now"]] where notNow.waitForExistence(timeout: 3) {
      notNow.tap()
      break
    }
    let setup = app.buttons["fechar"]
    if setup.waitForExistence(timeout: 1) { setup.tap() }
  }

  /// O plano semeado não tem treino em toda terça, quinta, sábado e domingo.
  /// Quando hoje cai num desses dias, o fluxo põe o dia no primeiro treino do
  /// plano, pelo mesmo editor que o usuário usa.
  func ensureWorkoutToday() {
    guard app.staticTexts["sem exercícios"].waitForExistence(timeout: 3) else { return }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
    let names = ["domingo", "segunda", "terça", "quarta", "quinta", "sexta", "sábado"]
    let today = names[calendar.component(.weekday, from: Date()) - 1]
    app.tabBars.buttons["plano"].tap()
    let menu = app.buttons["editar Superiores"]
    XCTAssert(menu.waitForExistence(timeout: 8), "plano listou Superiores")
    menu.tap()
    let editar = app.buttons["editar"]
    XCTAssert(editar.waitForExistence(timeout: 3), "menu do treino abriu")
    editar.tap()
    XCTAssert(app.navigationBars["Superiores"].waitForExistence(timeout: 3), "editor de Superiores abriu")
    let day = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", today)).firstMatch
    XCTAssert(day.waitForExistence(timeout: 3), "dia \(today) visível no editor")
    day.tap()
    app.buttons["salvar"].tap()
    XCTAssert(app.navigationBars["Superiores"].waitForNonExistence(timeout: 10), "editor fechou depois de salvar")
    app.tabBars.buttons["treino"].tap()
    XCTAssert(app.buttons["Concluir série 1"].firstMatch.waitForExistence(timeout: 10), "treino de hoje apareceu com séries")
  }

  func counterValue() -> String { app.buttons["sequência"].value as? String ?? "" }

  func replaceText(_ field: XCUIElement, with text: String) {
    field.doubleTap()
    field.typeText(text)
  }

  func dismissKeyboard() {
    let done = app.buttons["keyboard.done"]
    let localizedDone = app.buttons["concluído"]
    XCTAssert(done.waitForExistence(timeout: 2) || localizedDone.waitForExistence(timeout: 2), "teclado tem botão nativo para concluir")
    (done.exists ? done : localizedDone).tap()
    XCTAssert(app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "concluir fecha o teclado")
  }

  func testZCargaETeclado() {
    launch()
    ensureWorkoutToday()
    let weight = app.textFields["set.supino-inclinado.work.1.weight"]
    XCTAssert(weight.waitForExistence(timeout: 5), "carga da série valendo está disponível")
    let completion = app.buttons["set.supino-inclinado.work.1.completion"]
    let previousLabel = completion.label
    replaceText(weight, with: "37,5")
    shot("10-teclado-carga")
    dismissKeyboard()
    XCTAssertEqual(completion.label, previousLabel, "editar carga preserva conclusão da série")

    app.tabBars.buttons["plano"].tap()
    app.buttons["editar Superiores"].tap()
    app.buttons["editar"].tap()
    let planWeight = app.textFields["Carga em kg"].firstMatch
    XCTAssert(planWeight.waitForExistence(timeout: 5), "editor mostra carga do plano")
    let updated = NSPredicate(format: "value == %@", "37,5")
    expectation(for: updated, evaluatedWith: planWeight)
    waitForExpectations(timeout: 10)
    shot("11-carga-no-plano")
    app.buttons["cancelar"].tap()

    launch()
    XCTAssert(weight.waitForExistence(timeout: 10), "série reaparece depois de abrir o app")
    XCTAssertEqual(weight.value as? String, "37,5", "carga persiste depois de reabrir")
    XCTAssertEqual(completion.label, previousLabel, "conclusão também persiste")
    completion.tap()
    XCTAssertNotEqual(completion.label, previousLabel, "check responde ao toque")
    shot("12-check")
  }

  func testZTreinoSemDia() {
    launch(aba: "semana")
    app.tabBars.buttons["plano"].tap()
    app.buttons["novo treino"].tap()
    let name = app.textFields["nome"]
    XCTAssert(name.waitForExistence(timeout: 5), "editor de treino abriu")
    name.tap()
    name.typeText("Treino futuro de teste")
    let focus = app.textFields["foco"]
    focus.tap()
    focus.typeText("Adaptação")
    app.buttons["adicionar"].tap()
    let search = app.textFields["Buscar exercício"]
    XCTAssert(search.waitForExistence(timeout: 5), "busca de exercícios abriu")
    search.tap()
    search.typeText("Supino inclinado")
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] 'supino inclinado'")).firstMatch.tap()
    let save = app.buttons["salvar"]
    XCTAssert(save.waitForExistence(timeout: 5) && save.isEnabled, "treino sem dia pode ser salvo")
    shot("13-treino-sem-dia-editor")
    save.tap()
    XCTAssert(app.navigationBars["Treino futuro de teste"].waitForNonExistence(timeout: 10), "treino sem dia foi salvo")
    shot("14-treino-sem-dia-plano")

    launch(aba: "semana")
    app.tabBars.buttons["plano"].tap()
    let tile = app.buttons["editar Treino futuro de teste, sem dia"]
    XCTAssert(tile.waitForExistence(timeout: 10), "treino sem dia continua no plano após reabrir")
    tile.tap()
    XCTAssert(app.navigationBars["Treino futuro de teste"].waitForExistence(timeout: 5), "toque no treino sem dia abre edição")
    app.buttons["sábado"].tap()
    app.buttons["salvar"].tap()
    XCTAssert(app.navigationBars["Treino futuro de teste"].waitForNonExistence(timeout: 10), "treino futuro recebeu um dia")
    XCTAssert(app.buttons["iniciar Treino futuro de teste, sábado"].waitForExistence(timeout: 5), "treino agendado pode ser iniciado")
    shot("15-treino-agendado")
  }

  func testZZTecladoEmEstudos() {
    launch()
    app.terminate()
    app.launchArguments = ["--app", "estudos", "--aba", "sessao"]
    app.launch()
    let note = app.textViews.firstMatch
    XCTAssert(note.waitForExistence(timeout: 10), "anotação da sessão abriu")
    if !note.isHittable { app.swipeUp() }
    note.tap()
    note.typeText("Primeira linha\nSegunda linha")
    XCTAssert((note.value as? String ?? "").contains("\n"), "retorno mantém quebra de linha no editor")
    shot("16-teclado-estudos")
    dismissKeyboard()
  }

  func testFluxo() {
    launch()
    ensureWorkoutToday()
    XCTAssertEqual(counterValue(), "3 treinos", "contador começa com 3 do cenário")
    shot("01-treino")

    app.buttons["sequência"].tap()
    XCTAssert(app.navigationBars["sequência"].waitForExistence(timeout: 3), "tela de sequência abriu")
    XCTAssert(app.staticTexts["3 treinos, 3 completos"].waitForExistence(timeout: 3) || app.otherElements["3 treinos, 3 completos"].exists, "anel mostra 3 treinos e 3 completos")
    shot("02-sequencia")
    app.buttons["fechar"].tap()
    XCTAssert(app.navigationBars["sequência"].waitForNonExistence(timeout: 3), "tela de sequência fechou")

    // Aquecimento e valendo usam o mesmo rótulo; no card aberto o último é o valendo.
    XCTAssert(app.buttons["Concluir série 1"].firstMatch.waitForExistence(timeout: 5), "séries do primeiro exercício visíveis")
    let done = app.buttons.matching(identifier: "Concluir série 1").allElementsBoundByIndex.last!
    done.tap()
    shot("03b-toque")
    let lit = app.buttons["sequência"]
    let toFour = NSPredicate(format: "value == %@", "4 treinos")
    let wait = XCTNSPredicateExpectation(predicate: toFour, object: lit)
    shot("03c-toque")
    XCTAssertEqual(XCTWaiter.wait(for: [wait], timeout: 10), .completed, "contador foi para 4 depois da série")
    XCTAssert(app.buttons["Desmarcar série 1"].firstMatch.waitForExistence(timeout: 3), "série valendo ficou marcada")
    shot("03-aceso")

    app.tabBars.buttons["progresso"].tap()
    let nova = app.buttons["nova meta"]
    XCTAssert(nova.waitForExistence(timeout: 5), "progresso abriu")
    nova.tap()
    XCTAssert(app.navigationBars["meta"].waitForExistence(timeout: 3), "editor de meta abriu")
    app.buttons["presença"].tap()
    let stepper = app.steppers.firstMatch
    XCTAssert(stepper.waitForExistence(timeout: 3), "campo alvo da presença visível")
    stepper.buttons["Increment"].tap()
    stepper.buttons["Increment"].tap()
    app.buttons["salvar"].tap()
    let card = app.buttons["meta de presença, 4 de 11"]
    XCTAssert(card.waitForExistence(timeout: 10), "card de meta de presença com 4 de 11")
    shot("04-meta")

    launch(aba: "progresso")
    XCTAssert(app.buttons["meta de presença, 4 de 11"].waitForExistence(timeout: 10), "meta continua depois de reabrir")
    shot("05-meta-reaberta")

    app.tabBars.buttons["plano"].tap()
    XCTAssert(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'iniciar '")).firstMatch.waitForExistence(timeout: 5), "plano listou treinos")
    shot("06-plano")

    app.tabBars.buttons["apps"].tap()
    let estudos = app.buttons["estudos"]
    XCTAssert(estudos.waitForExistence(timeout: 3), "painel de apps abriu")
    estudos.tap()
    XCTAssert(app.tabBars.buttons["matérias"].waitForExistence(timeout: 10), "estudos abriu")
    shot("07-estudos")
  }
}
