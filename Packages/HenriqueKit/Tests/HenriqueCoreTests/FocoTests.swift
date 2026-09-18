import Foundation
import Testing

@testable import HenriqueCore

/// Fuso fixo em Fortaleza, o mesmo de `StudyFormat.calendar`, para a meia-noite
/// dos testes não depender do aparelho que os roda.
@Suite("O registro de foco")
struct FocoTests {
  static let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Fortaleza")!
    return calendar
  }()

  static let fisica = FocoTrack.subject(id: "fis", name: "física", color: "#0075de")

  /// "2026-09-08 14:05" no fuso de Fortaleza.
  static func at(_ day: String, _ time: String) -> Date {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter.date(from: "\(day) \(time)")!
  }

  static func day(_ iso: String) -> CalendarDate { CalendarDate(iso: iso)! }

  static func entry(_ track: FocoTrack, _ day: String, _ from: String, _ to: String) -> FocoEntry {
    FocoEntry(track: track, startedAt: at(day, from), endedAt: at(day, to))
  }

  /// Um dia inteiro que conta para o streak: 30 min de física.
  static func counted(_ day: String) -> FocoEntry {
    entry(fisica, day, "09:00", "09:30")
  }

  @Test("o total do dia soma duas sessões e a corrida em andamento")
  func todayTotalIncludesTheRun() {
    var ledger = FocoLedger(entries: [
      Self.entry(Self.fisica, "2026-09-08", "14:05", "14:52"),
      Self.entry(.alemao, "2026-09-08", "16:00", "16:10"),
    ])
    ledger.start(Self.fisica, at: Self.at("2026-09-08", "20:00"))
    let now = Self.at("2026-09-08", "20:03")
    #expect(
      ledger.seconds(on: Self.day("2026-09-08"), now: now, calendar: Self.calendar)
        == (47 + 10 + 3) * 60)
    #expect(
      ledger.seconds(
        on: Self.day("2026-09-08"), track: Self.fisica.id, now: now, calendar: Self.calendar)
        == (47 + 3) * 60)
  }

  @Test("sessão com menos de 10 segundos não grava")
  func shortSessionIsDropped() {
    var ledger = FocoLedger()
    ledger.start(.alemao, at: Self.at("2026-09-08", "10:00"))
    let entry = ledger.stop(at: Self.at("2026-09-08", "10:00").addingTimeInterval(9))
    #expect(entry == nil)
    #expect(ledger.entries.isEmpty)
    #expect(ledger.running == nil)
  }

  @Test("começar outra trilha fecha a que rodava")
  func startClosesThePreviousRun() {
    var ledger = FocoLedger()
    ledger.start(.alemao, at: Self.at("2026-09-08", "10:00"))
    ledger.start(Self.fisica, at: Self.at("2026-09-08", "10:20"))
    #expect(ledger.entries.map(\.track.id) == [FocoTrack.alemao.id])
    #expect(ledger.entries.first?.seconds == 1200.0)
    #expect(ledger.running?.track == Self.fisica)
  }

  @Test("streak de 3 com hoje feito")
  func streakEndingToday() {
    let ledger = FocoLedger(entries: ["2026-09-06", "2026-09-07", "2026-09-08"].map(Self.counted))
    let streak = ledger.streak(now: Self.at("2026-09-08", "18:00"), calendar: Self.calendar)
    #expect(streak == FocoStreak(current: 3, best: 3, isTodayDone: true))
  }

  @Test("hoje em aberto não quebra o streak, que termina ontem")
  func streakEndingYesterdayWhileTodayIsOpen() {
    let ledger = FocoLedger(entries: ["2026-09-05", "2026-09-06", "2026-09-07"].map(Self.counted))
    let streak = ledger.streak(now: Self.at("2026-09-08", "18:00"), calendar: Self.calendar)
    #expect(streak == FocoStreak(current: 3, best: 3, isTodayDone: false))
  }

  @Test("buraco ontem zera o streak e o recorde fica")
  func gapYesterdayResetsTheStreak() {
    let ledger = FocoLedger(entries: ["2026-09-04", "2026-09-05", "2026-09-06"].map(Self.counted))
    let streak = ledger.streak(now: Self.at("2026-09-08", "18:00"), calendar: Self.calendar)
    #expect(streak == FocoStreak(current: 0, best: 3, isTodayDone: false))
  }

  @Test("o recorde é a maior sequência do registro inteiro")
  func bestIsTheLongestRun() {
    let ledger = FocoLedger(
      entries: ["2026-08-01", "2026-08-02", "2026-08-03", "2026-08-04", "2026-09-08"].map(
        Self.counted))
    let streak = ledger.streak(now: Self.at("2026-09-08", "18:00"), calendar: Self.calendar)
    #expect(streak == FocoStreak(current: 1, best: 4, isTodayDone: true))
  }

  @Test("sessão das 23:30 às 00:30 conta para o dia em que começou")
  func sessionAcrossMidnightBelongsToItsStartDay() {
    let ledger = FocoLedger(entries: [
      FocoEntry(
        track: Self.fisica, startedAt: Self.at("2026-09-07", "23:30"),
        endedAt: Self.at("2026-09-08", "00:30"))
    ])
    let now = Self.at("2026-09-08", "08:00")
    #expect(ledger.seconds(on: Self.day("2026-09-07"), now: now, calendar: Self.calendar) == 3600)
    #expect(ledger.seconds(on: Self.day("2026-09-08"), now: now, calendar: Self.calendar) == 0)
  }

  @Test("os níveis da grade vão de 0 a 4 contra a meta de 120 min")
  func gridLevelsAgainstTheGoal() {
    let ledger = FocoLedger(
      entries: [
        Self.entry(Self.fisica, "2026-09-04", "09:00", "09:20"),
        Self.entry(Self.fisica, "2026-09-05", "09:00", "09:40"),
        Self.entry(Self.fisica, "2026-09-06", "09:00", "10:30"),
        Self.entry(Self.fisica, "2026-09-07", "09:00", "11:00"),
      ], dailyGoalMinutes: 120)
    let days = ledger.days(
      endingOn: Self.day("2026-09-07"), count: 5, now: Self.at("2026-09-08", "08:00"),
      calendar: Self.calendar)
    #expect(days.map(\.date.iso) == [
      "2026-09-03", "2026-09-04", "2026-09-05", "2026-09-06", "2026-09-07",
    ])
    #expect(days.map(\.level) == [0, 1, 2, 3, 4])
  }

  @Test("o registro faz ida e volta em JSON com a corrida")
  func ledgerRoundTripsThroughJSON() throws {
    var ledger = FocoLedger(entries: [Self.counted("2026-09-07")], dailyGoalMinutes: 180)
    ledger.start(Self.fisica, at: Self.at("2026-09-08", "10:00"))
    ledger.running?.serverSessionId = "srv-1"
    let data = try JSONEncoder().encode(ledger)
    let decoded = try JSONDecoder().decode(FocoLedger.self, from: data)
    #expect(decoded == ledger)
    #expect(decoded.running?.serverSessionId == "srv-1")
  }

  // MARK: Fila de sincronização

  @Test("JSON gravado antes da fila decodifica com todo o histórico pendente")
  func legacyJSONMarksEverythingPending() throws {
    let old = Self.counted("2026-09-07")
    let json = """
      {"entries":[{"id":"\(old.id.uuidString)","track":{"id":"estudos:fis","name":"física","color":"#0075de","source":"estudos","subjectId":"fis"},"startedAt":"2026-09-07T12:00:00Z","endedAt":"2026-09-07T12:30:00Z"}],"dailyGoalMinutes":90}
      """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let ledger = try decoder.decode(FocoLedger.self, from: Data(json.utf8))
    #expect(ledger.entries.map(\.id) == [old.id])
    #expect(ledger.pendingUploads == [old.id])
    #expect(ledger.pendingRemovals == [])
    #expect(ledger.goalDirty == false)
    #expect(ledger.dailyGoalMinutes == 90)
  }

  @Test("parar enfileira a sessão gravada; a curta demais não")
  func stopQueuesTheEntry() {
    var ledger = FocoLedger()
    ledger.start(.alemao, at: Self.at("2026-09-08", "10:00"))
    let entry = ledger.stop(at: Self.at("2026-09-08", "10:20"))!
    #expect(ledger.pendingUploads == [entry.id])
    ledger.start(.alemao, at: Self.at("2026-09-08", "11:00"))
    ledger.stop(at: Self.at("2026-09-08", "11:00").addingTimeInterval(5))
    #expect(ledger.pendingUploads == [entry.id])
  }

  @Test("começar outra trilha enfileira a que fechou")
  func startQueuesTheClosedRun() {
    var ledger = FocoLedger()
    ledger.start(.alemao, at: Self.at("2026-09-08", "10:00"))
    ledger.start(Self.fisica, at: Self.at("2026-09-08", "10:20"))
    #expect(ledger.pendingUploads == [ledger.entries[0].id])
  }

  @Test("apagar uma pendente só tira da fila de subida")
  func removingPendingDoesNotQueueRemoval() {
    let entry = Self.counted("2026-09-07")
    var ledger = FocoLedger(entries: [entry], pendingUploads: [entry.id])
    ledger.remove(id: entry.id)
    #expect(ledger.entries == [])
    #expect(ledger.pendingUploads == [])
    #expect(ledger.pendingRemovals == [])
  }

  @Test("apagar uma sincronizada enfileira a remoção")
  func removingSyncedQueuesRemoval() {
    let entry = Self.counted("2026-09-07")
    var ledger = FocoLedger(entries: [entry])
    ledger.remove(id: entry.id)
    #expect(ledger.entries == [])
    #expect(ledger.pendingRemovals == [entry.id])
  }

  @Test("merge traz a nova do servidor, mantém a pendente, esconde a removida e não duplica")
  func mergeCombinesServerAndQueue() {
    let synced = Self.entry(Self.fisica, "2026-09-05", "09:00", "09:30")
    let removed = Self.entry(Self.fisica, "2026-09-06", "09:00", "09:30")
    let pending = Self.entry(.alemao, "2026-09-08", "09:00", "09:30")
    let fromServer = Self.entry(Self.fisica, "2026-09-07", "09:00", "09:30")
    var ledger = FocoLedger(
      entries: [synced, pending], pendingUploads: [pending.id], pendingRemovals: [removed.id])
    ledger.start(.alemao, at: Self.at("2026-09-08", "12:00"))
    let run = ledger.running
    ledger.merge(server: [fromServer, removed, synced], serverGoal: nil)
    #expect(ledger.entries.map(\.id) == [synced.id, fromServer.id, pending.id])
    #expect(ledger.pendingUploads == [pending.id])
    #expect(ledger.pendingRemovals == [removed.id])
    #expect(ledger.running == run)
  }

  @Test("meta suja vence o servidor; limpa adota a do servidor; sem meta lá fica a local")
  func mergeGoal() {
    var dirty = FocoLedger(dailyGoalMinutes: 180)
    dirty.setGoal(minutes: 60)
    dirty.merge(server: [], serverGoal: 240)
    #expect(dirty.dailyGoalMinutes == 60)
    #expect(dirty.goalDirty)

    var clean = FocoLedger(dailyGoalMinutes: 180)
    clean.merge(server: [], serverGoal: 240)
    #expect(clean.dailyGoalMinutes == 240)

    var alone = FocoLedger(dailyGoalMinutes: 180)
    alone.merge(server: [], serverGoal: nil)
    #expect(alone.dailyGoalMinutes == 180)
  }

  @Test("marcar subida, remoção e meta esvazia a fila")
  func marksDrainTheQueue() {
    let a = Self.counted("2026-09-06")
    let b = Self.counted("2026-09-07")
    var ledger = FocoLedger(
      entries: [a], pendingUploads: [a.id], pendingRemovals: [b.id], goalDirty: true)
    ledger.markUploaded([a.id])
    ledger.markRemoved([b.id])
    ledger.markGoalSynced()
    #expect(ledger.pendingUploads == [])
    #expect(ledger.pendingRemovals == [])
    #expect(ledger.goalDirty == false)
  }

  @Test("o contrato HTTP faz ida e volta pelo codificador do app")
  func entryRoundTripsThroughTheAppCoders() throws {
    let entry = Self.entry(.alemao, "2026-09-08", "10:00", "10:47")
    let data = try JSONEncoder.henrique().encode(FocoSaveInput(entries: [entry]))
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let sent = try #require((json["entries"] as? [[String: Any]])?.first)
    #expect(sent["startedAt"] as? String == "2026-09-08T13:00:00.000Z")
    #expect((sent["track"] as? [String: Any])?["subjectId"] == nil)
    let back = """
      {"entries":[{"id":"\(entry.id.uuidString.lowercased())","track":{"id":"idiomas:alemao","name":"alemão","color":"#0b6e4f","source":"idiomas","subjectId":null},"startedAt":"2026-09-08T13:00:00.000Z","endedAt":"2026-09-08T13:47:00Z"}],"dailyGoalMinutes":null}
      """
    let list = try JSONDecoder.henrique().decode(FocoListResponse.self, from: Data(back.utf8))
    #expect(list.entries == [entry])
    #expect(list.dailyGoalMinutes == nil)
  }
}
