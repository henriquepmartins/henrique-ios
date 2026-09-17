import Foundation
import HenriqueCore
import Testing

@testable import HenriqueUI

/// A rede do teste. Ela recusa tudo enquanto `offline` estiver ligado, que é o
/// que acontece na academia, e conta quantas vezes o app tentou gravar a série.
final class FakeNetwork: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var offline = true
  nonisolated(unsafe) static var recordedSets = 0

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func stopLoading() {}

  override func startLoading() {
    let path = request.url?.path ?? ""
    if path == Route.recordSet.rawValue { Self.recordedSets += 1 }
    guard !Self.offline else {
      client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
      return
    }
    let response = HTTPURLResponse(
      url: request.url!, statusCode: 200, httpVersion: nil,
      headerFields: ["Content-Type": "application/json"])!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(dashboardDeHoje().utf8))
    client?.urlProtocolDidFinishLoading(self)
  }
}

struct MemoryTokenStore: TokenStore {
  nonisolated(unsafe) static var token: String? = "sessao-de-teste"
  func read() -> String? { Self.token }
  func write(_ token: String?) { Self.token = token }
}

@MainActor
private func makeStore() -> AcademiaStore {
  let configuration = URLSessionConfiguration.ephemeral
  configuration.protocolClasses = [FakeNetwork.self]
  let client = APIClient(
    baseURL: URL(string: "https://exemplo.invalido")!,
    tokenStore: MemoryTokenStore(),
    session: URLSession(configuration: configuration))
  return AcademiaStore(client: client)
}

/// O painel só é aceito quando a data que volta é a data pedida, então a
/// fixture nasce com a data de hoje em vez de uma escrita à mão que vence.
func dashboardDeHoje() -> String {
  dashboardJSON.replacingOccurrences(of: "2026-09-17", with: CalendarDate.today.iso)
}

private let chave = SetKey(
  date: .today, templateId: "tpl-terca", exerciseId: "supino-reto", kind: .work, index: 1)

/// A academia começa com sinal: você abre o app em casa, o painel carrega, e o
/// sinal some lá dentro. Marcar série antes do painel existir é outro caso.
@MainActor
private func lojaComPainel() async -> AcademiaStore {
  FakeNetwork.offline = false
  let store = makeStore()
  await store.start()
  FakeNetwork.offline = true
  return store
}

@Suite("A fila de séries não enviadas", .serialized)
@MainActor
struct PendingSetQueueTests {
  init() {
    FakeNetwork.offline = true
    FakeNetwork.recordedSets = 0
    limparFila()
  }

  @Test("sem rede a série continua marcada na tela")
  func keepsTheMarkOffline() async {
    let store = await lojaComPainel()
    _ = await store.record(key: chave, weightKg: 42.5, reps: 9, completed: true, toFailure: true)?
      .value

    #expect(store.isWaiting(chave))
    #expect(store.banner?.contains("guardada") == true)
    let série = store.dashboard?.workout?.exercises
      .first { $0.id == chave.exerciseId }?.sets.work.first { $0.index == chave.index }
    #expect(série?.isDone == true)
    #expect(série?.weightKg == 42.5)
  }

  @Test("a série guardada chega ao servidor quando a rede volta")
  func resendsWhenTheNetworkReturns() async {
    let store = await lojaComPainel()
    _ = await store.record(key: chave, weightKg: 42.5, reps: 9, completed: true, toFailure: true)?
      .value
    #expect(store.isWaiting(chave))
    let tentativasOffline = FakeNetwork.recordedSets

    FakeNetwork.offline = false
    await store.load()
    await esperar { !store.isWaiting(chave) }

    #expect(!store.isWaiting(chave))
    #expect(FakeNetwork.recordedSets > tentativasOffline)
  }

  @Test("a série guardada sobrevive ao app fechar")
  func survivesRelaunch() async {
    let primeiro = await lojaComPainel()
    _ = await primeiro.record(
      key: chave, weightKg: 42.5, reps: 9, completed: true, toFailure: true)?.value
    #expect(primeiro.isWaiting(chave))

    let segundo = makeStore()
    #expect(segundo.isWaiting(chave))
  }
}

/// O disco é o mesmo para toda a suíte, então cada teste começa com ele limpo.
@MainActor
private func limparFila() {
  guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
    .first?.appending(path: "henrique-series-pendentes.json")
  else { return }
  try? FileManager.default.removeItem(at: url)
}

private func esperar(_ condicao: @MainActor () -> Bool) async {
  for _ in 0..<200 {
    if await MainActor.run(body: condicao) { return }
    try? await Task.sleep(for: .milliseconds(25))
  }
}

private let dashboardJSON = #"""
{"date": "2026-09-17", "workout": {"id": "tpl-terca", "name": "Empurrar A", "focus": "peito, ombro e tríceps", "estimatedMinutes": 55, "exerciseCount": 2, "workSetCount": 4, "completedWorkSetCount": 1, "completionPercent": 25, "exercises": [{"id": "supino-reto", "name": "Supino reto", "muscleGroup": "peito", "equipment": "barra", "order": 1, "prescription": {"prepSets": 2, "workSets": 2, "repsMin": 6, "repsMax": 10, "workToFailure": true, "startingWeightKg": 40}, "previous": {"date": "2026-09-01", "weightKg": 42.5, "reps": [9, 7], "volumeKg": 680}, "sets": {"prep": [{"kind": "prep", "index": 1, "weightKg": 20, "reps": 10, "completedAt": "2026-09-08T13:02:11.482Z"}, {"kind": "prep", "index": 2, "weightKg": 30, "reps": 10, "completedAt": null}], "work": [{"kind": "work", "index": 1, "weightKg": 42.5, "reps": 9, "toFailure": true, "completedAt": "2026-09-08T13:09:40Z"}, {"kind": "work", "index": 2, "weightKg": 42.5, "reps": 10, "toFailure": true, "completedAt": null}]}}, {"id": "desenvolvimento", "name": "Desenvolvimento com halteres", "muscleGroup": "ombro", "equipment": "halteres", "order": 2, "prescription": {"prepSets": 1, "workSets": 2, "repsMin": 8, "repsMax": 12, "workToFailure": false, "startingWeightKg": 14}, "previous": null, "sets": {"prep": [{"kind": "prep", "index": 1, "weightKg": 10, "reps": 12, "completedAt": null}], "work": [{"kind": "work", "index": 1, "weightKg": 14, "reps": 12, "toFailure": false, "completedAt": null}, {"kind": "work", "index": 2, "weightKg": 14, "reps": 12, "toFailure": false, "completedAt": null}]}}]}, "consistencyPercent": 75, "currentStreak": 4, "attendanceStreak": 6, "streakGoals": [{"kind": "attendance", "target": 10}, {"kind": "complete", "target": 7}], "weeklyCompleted": 2, "weeklyPlanned": 4, "weekPlan": [{"id": "tpl-terca", "weekdays": [2], "weekday": 2, "name": "Empurrar A", "focus": "peito, ombro e tríceps", "exerciseCount": 2, "estimatedMinutes": 55, "exercises": [{"exerciseId": "supino-reto", "prepSets": 2, "workSets": 2, "repsMin": 6, "repsMax": 10, "workToFailure": true, "startingWeightKg": 40}]}], "sessionDates": [], "exerciseCatalog": [{"id": "supino-reto", "name": "Supino reto", "muscleGroup": "peito", "equipment": "barra"}], "strengthGoal": {"exerciseId": "supino-reto", "exerciseName": "Supino reto", "targetValue": 60, "lastSession": {"date": "2026-09-01", "weightKg": 42.5, "reps": [9, 7], "volumeKg": 680}}, "progress": [{"date": "2026-09-01", "estimatedOneRepMax": 55.25, "volumeKg": 680}], "measurements": [{"id": "m1", "date": "2026-09-01", "weightKg": 78.4, "bodyFatPercent": 18.2, "waistCm": 84, "chestCm": null, "armCm": null, "thighCm": null}], "projection": {"metric": "estimated_1rm", "current": 55.25, "target": 60, "weeklyChange": 1.2, "weeksRemaining": 4, "confidence": "medium"}, "onboardingCompleted": true}
"""#
