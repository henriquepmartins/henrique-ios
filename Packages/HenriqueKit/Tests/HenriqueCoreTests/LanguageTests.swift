import Foundation
import Testing

@testable import HenriqueCore

@Suite("Idiomas")
struct LanguageTests {
  static let terca = CalendarDate(iso: "2026-09-08")!

  static func fixture() throws -> Data {
    try ContractTests.fixture("idiomas")
  }

  static func sample() throws -> LanguageSample {
    try JSONDecoder.henrique().decode(LanguageSample.self, from: fixture())
  }

  @Test("o registro dos tipos cobre título, minutos e flags")
  func kindRegistry() {
    #expect(LanguageDrillKind.listen.title == "ouvir")
    #expect(LanguageDrillKind.shadow.title == "sombrear")
    #expect(LanguageDrillKind.produce.title == "produzir")
    #expect(LanguageDrillKind.review.title == "revisar")
    #expect(LanguageDrillKind.listen.minutes == 5)
    #expect(LanguageDrillKind.shadow.minutes == 7)
    #expect(LanguageDrillKind.produce.minutes == 8)
    #expect(LanguageDrillKind.review.minutes == 5)
    #expect(!LanguageDrillKind.listen.needsMic)
    #expect(LanguageDrillKind.shadow.needsMic)
    #expect(!LanguageDrillKind.produce.needsMic)
    #expect(!LanguageDrillKind.review.needsMic)
    #expect(!LanguageDrillKind.listen.needsAI)
    #expect(!LanguageDrillKind.shadow.needsAI)
    #expect(LanguageDrillKind.produce.needsAI)
    #expect(!LanguageDrillKind.review.needsAI)
  }

  @Test("a rotina decodifica os quatro tipos")
  func routineDecodes() throws {
    let sample = try Self.sample()
    #expect(sample.routine.drills.count == 4)
    #expect(sample.routine.drills.map(\.kind) == [.listen, .shadow, .produce, .review])
    #expect(sample.routine.drills[0].expectedDE == nil)
    #expect(sample.routine.drills[1].expectedDE != nil)
  }

  @Test("a fita marca todo dia sem treino como perdido, sem folga")
  func stripMarksEveryPastDayMissed() {
    let progress = LanguageProgress(doneDates: [], streakCount: 0, target: 7, today: Self.terca)
    #expect(progress.days.count == 7)
    #expect(progress.days.map(\.state) == [.missed, .missed, .missed, .missed, .missed, .missed, .planned])
    #expect(!progress.isTodayDone)
  }

  @Test("a fita com dois dias feitos termina feita hoje")
  func stripWithDoneDates() throws {
    let done = try [
      #require(CalendarDate(iso: "2026-09-07")),
      #require(CalendarDate(iso: "2026-09-08")),
    ]
    let progress = LanguageProgress(doneDates: done, streakCount: 2, target: 7, today: Self.terca)
    #expect(progress.days[6].state == .done)
    #expect(progress.isTodayDone)
    #expect(progress.figure == StreakFigure(count: 2, target: 7))
  }

  @Test("a rotina inteira anda até o fim")
  func reduceFullRoutine() {
    var state: LanguageSessionState = .drill(index: 0, step: .listen, micArmed: false, played: false, failed: false)
    state = state.reduce(.play, kind: .listen, total: 2)
    if case .drill(_, _, let mic, let played, _) = state {
      #expect(played)
      #expect(!mic)
    } else {
      Issue.record("esperava drill após play")
    }
    state = state.reduce(.submit, kind: .listen, total: 2)
    if case .drill(_, let step, _, _, _) = state {
      #expect(step == .respond)
    }
    state = state.reduce(.advance(total: 2), kind: .listen, total: 2)
    if case .drill(let index, let step, _, let played, _) = state {
      #expect(index == 1)
      #expect(step == .listen)
      #expect(!played)
    }
    state = state.reduce(.advance(total: 2), kind: .shadow, total: 2)
    #expect(state == .done)
    #expect(state.reduce(.play, kind: .listen, total: 2) == .done)
  }

  @Test("o microfone só arma no sombrear e o play desarma")
  func micArmsOnlyOnShadow() {
    var listen: LanguageSessionState = .drill(index: 0, step: .listen, micArmed: false, played: true, failed: false)
    listen = listen.reduce(.armMic(true), kind: .listen, total: 1)
    if case .drill(_, _, let mic, _, _) = listen {
      #expect(!mic)
    }
    var shadow: LanguageSessionState = .drill(index: 0, step: .listen, micArmed: false, played: false, failed: false)
    shadow = shadow.reduce(.armMic(true), kind: .shadow, total: 1)
    if case .drill(_, _, let mic, _, _) = shadow {
      #expect(mic)
    }
    shadow = shadow.reduce(.play, kind: .shadow, total: 1)
    if case .drill(_, _, let mic, let played, _) = shadow {
      #expect(!mic)
      #expect(played)
    }
  }

  @Test("a falha da IA não avança sozinha")
  func aiDownStaysOnDrill() {
    var state: LanguageSessionState = .drill(index: 0, step: .respond, micArmed: false, played: true, failed: false)
    state = state.reduce(.failed, kind: .produce, total: 2)
    if case .drill(let index, _, _, _, let failed) = state {
      #expect(index == 0)
      #expect(failed)
    } else {
      Issue.record("esperava drill após falha")
    }
  }

  @Test("a correção da IA decodifica todos os campos")
  func correctionDecodes() throws {
    let correction = try Self.sample().correction
    #expect(correction.id == "corr-1")
    #expect(correction.score == 78)
    #expect(correction.interval == 1)
    #expect(!correction.correctionPT.isEmpty)
    #expect(!correction.fixedDE.isEmpty)
  }

  @Test("o attemptId vai igual nas duas codificações")
  func attemptIdIsStable() throws {
    let attemptId = UUID()
    let payload = { (id: UUID) throws -> [String: Any] in
      try #require(
        JSONSerialization.jsonObject(
          with: JSONEncoder.henrique().encode(
            LanguageCompleteInput(attemptId: id, drillId: "drill-ouvir-1", text: "guten morgen", micUsed: false)))
          as? [String: Any])
    }
    let first = try payload(attemptId)
    let second = try payload(attemptId)
    #expect((first["attemptId"] as? String)?.lowercased() == attemptId.uuidString.lowercased())
    #expect(first["attemptId"] as? String == second["attemptId"] as? String)
    #expect(first["drillId"] as? String == "drill-ouvir-1")
    #expect(second["drillId"] as? String == "drill-ouvir-1")
  }

  @Test("a entrada de correção omite attemptId ausente")
  func correctionInputOmitsMissingAttempt() throws {
    let input = LanguageCorrectionInput(drillId: "drill-produz-1", text: "ich frühstücke brot")
    let json = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder.henrique().encode(input)) as? [String: Any])
    #expect(!json.keys.contains("attemptId"))
    #expect(json["drillId"] as? String == "drill-produz-1")
  }
}

struct LanguageSample: Codable, Hashable, Sendable {
  var routine: LanguageRoutine
  var queue: LanguageReviewQueue
  var progress: LanguageProgressPayload
  var correction: LanguageCorrection
  var complete: LanguageCompleteResult
}
