import Foundation
import Testing

@testable import HenriqueCore

@Suite("CalendarDate")
struct CalendarDateTests {
  @Test("ida e volta pelo texto ISO")
  func roundTrip() throws {
    let date = try #require(CalendarDate(iso: "2026-09-08"))
    #expect(date.year == 2026)
    #expect(date.month == 9)
    #expect(date.day == 8)
    #expect(date.iso == "2026-09-08")
  }

  @Test(
    "recusa texto fora do formato",
    arguments: ["2026-9-8", "08/09/2026", "2026-13-01", "2026-09-32", "", "hoje"])
  func rejectsBadInput(_ text: String) {
    #expect(CalendarDate(iso: text) == nil)
  }

  @Test("o dia da semana casa com o que a API espera")
  func weekdayMatchesServer() throws {
    // 8 de setembro de 2026 é uma terça, e a API numera domingo como zero.
    let date = try #require(CalendarDate(iso: "2026-09-08"))
    #expect(date.weekday() == 2)
  }

  @Test("andar pelo calendário atravessa o fim do mês")
  func addingDaysCrossesMonth() throws {
    let date = try #require(CalendarDate(iso: "2026-09-30"))
    #expect(date.adding(days: 1).iso == "2026-10-01")
    #expect(date.adding(days: -30).iso == "2026-08-31")
  }

  @Test("ordena por dia, não por texto")
  func ordering() throws {
    let older = try #require(CalendarDate(iso: "2026-09-08"))
    let newer = try #require(CalendarDate(iso: "2026-10-01"))
    #expect(older < newer)
  }

  @Test("codifica como string simples, não como objeto")
  func encodesAsString() throws {
    let date = try #require(CalendarDate(iso: "2026-09-08"))
    let json = try #require(String(data: JSONEncoder().encode(date), encoding: .utf8))
    #expect(json == "\"2026-09-08\"")
  }
}
