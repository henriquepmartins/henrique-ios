import Foundation
import Testing

@testable import HenriqueCore

/// 8 de setembro de 2026 é uma terça, então a janela de sete dias vai da quarta
/// anterior até ela, e o único dia da semana no plano das fixtures é o 2.
@Suite("A fita dos sete dias")
struct StreakTests {
  static let terca = CalendarDate(iso: "2026-09-08")!

  static func date(_ iso: String) throws -> CalendarDate {
    try #require(CalendarDate(iso: iso))
  }

  static func planItem(weekdays: [Int]) -> WeekPlanItem {
    WeekPlanItem(
      id: "tpl-\(weekdays.map(String.init).joined(separator: "-"))", weekdays: weekdays,
      name: "Empurrar A", focus: "peito", exerciseCount: 0, exercises: [], estimatedMinutes: 45)
  }

  /// Cada item de `plan` é um treino com os seus dias.
  static func dashboard(
    currentStreak: Int = 0, weeklyCompleted: Int = 0, weeklyPlanned: Int = 0,
    plan: [[Int]] = [], sessionDates: [CalendarDate]? = []
  ) -> Dashboard {
    Dashboard(
      date: Self.terca, workout: nil, consistencyPercent: 0, currentStreak: currentStreak,
      weeklyCompleted: weeklyCompleted, weeklyPlanned: weeklyPlanned,
      weekPlan: plan.map(planItem(weekdays:)), sessionDates: sessionDates,
      exerciseCatalog: [], strengthGoal: nil, progress: [], measurements: [], projection: nil,
      onboardingCompleted: true)
  }

  static func state(_ iso: String, in streak: WorkoutStreak) throws -> StreakDayState {
    try #require(
      streak.days.first { $0.date.iso == iso }?.state, "o dia \(iso) não está na fita")
  }

  @Test("saem sete dias em ordem, terminando em hoje")
  func sevenDaysEndingToday() {
    let streak = WorkoutStreak(dashboard: Self.dashboard(), today: Self.terca)
    #expect(
      streak.days.map(\.date.iso) == [
        "2026-09-02", "2026-09-03", "2026-09-04", "2026-09-05", "2026-09-06", "2026-09-07",
        "2026-09-08",
      ])
    #expect(streak.days.last?.date == Self.terca)
  }

  @Test("o dia com sessão fica feito mesmo fora do plano")
  func sessionOutsideThePlanIsDone() throws {
    let domingo = try Self.date("2026-09-06")
    let streak = WorkoutStreak(
      dashboard: Self.dashboard(plan: [[2]], sessionDates: [domingo]), today: Self.terca)
    #expect(try Self.state("2026-09-06", in: streak) == .done)
  }

  @Test("dia passado com treino no plano e sem sessão fica perdido, sem plano vira folga")
  func pastDaySplitsByThePlan() throws {
    let streak = WorkoutStreak(dashboard: Self.dashboard(plan: [[4]]), today: Self.terca)
    #expect(try Self.state("2026-09-03", in: streak) == .missed)
    #expect(try Self.state("2026-09-04", in: streak) == .rest)
  }

  @Test("um treino em dois dias marca os dois na fita")
  func oneWorkoutOnTwoDays() {
    let streak = WorkoutStreak(dashboard: Self.dashboard(plan: [[2, 4]]), today: Self.terca)
    #expect(
      streak.days.map(\.state) == [.rest, .missed, .rest, .rest, .rest, .rest, .planned])
    #expect(streak.isAtRisk)
  }

  @Test("hoje planejado e ainda não feito deixa a fita em risco")
  func plannedTodayIsAtRisk() throws {
    let streak = WorkoutStreak(dashboard: Self.dashboard(plan: [[2]]), today: Self.terca)
    #expect(try Self.state("2026-09-08", in: streak) == .planned)
    #expect(streak.isAtRisk)
    #expect(!streak.isTodayDone)
  }

  @Test("hoje já feito tira a fita do risco")
  func doneTodayLeavesNoRisk() throws {
    let streak = WorkoutStreak(
      dashboard: Self.dashboard(plan: [[2]], sessionDates: [Self.terca]), today: Self.terca)
    #expect(streak.isTodayDone)
    #expect(!streak.isAtRisk)
  }

  @Test("hoje sem treino no plano fica livre")
  func todayWithoutPlanIsOpen() throws {
    let streak = WorkoutStreak(dashboard: Self.dashboard(plan: [[4]]), today: Self.terca)
    #expect(try Self.state("2026-09-08", in: streak) == .open)
    #expect(!streak.isAtRisk)
  }

  @Test("semana sem nada planejado devolve progresso zero em vez de estourar")
  func emptyWeekHasZeroProgress() {
    let streak = WorkoutStreak(
      dashboard: Self.dashboard(weeklyCompleted: 2, weeklyPlanned: 0), today: Self.terca)
    #expect(streak.weekProgress == 0)
    #expect(streak.weeklyPlanned == 0)
  }

  @Test("o progresso da semana é o completo sobre o planejado, preso em um")
  func weekProgressIsClamped() {
    let metade = WorkoutStreak(
      dashboard: Self.dashboard(weeklyCompleted: 2, weeklyPlanned: 4), today: Self.terca)
    let demais = WorkoutStreak(
      dashboard: Self.dashboard(weeklyCompleted: 5, weeklyPlanned: 4), today: Self.terca)
    #expect(metade.weekProgress == 0.5)
    #expect(demais.weekProgress == 1)
  }

  @Test("sem sessionDates nenhum dia fica feito")
  func nilSessionDatesMarksNothingDone() {
    let streak = WorkoutStreak(
      dashboard: Self.dashboard(plan: [[2]], sessionDates: nil), today: Self.terca)
    #expect(!streak.days.contains { $0.state == .done })
    #expect(!streak.isTodayDone)
    #expect(streak.isAtRisk)
  }

  @Test("a fixture do painel monta a fita inteira")
  func buildsFromFixture() throws {
    let dashboard = try ContractTests.dashboard()
    let streak = WorkoutStreak(dashboard: dashboard, today: dashboard.date)
    #expect(streak.attendance == StreakFigure(count: 6, target: 10))
    #expect(streak.complete == StreakFigure(count: 4, target: 7))
    #expect(streak.weeklyCompleted == 2)
    #expect(streak.weekProgress == 0.5)
    #expect(
      streak.days.map(\.state) == [.rest, .rest, .done, .rest, .done, .done, .planned])
    #expect(streak.isAtRisk)
    #expect(!streak.isTodayDone)
  }

  @Test("a captura do servidor real não tem o campo e a fita ainda sai")
  func capturedServerHasNoSessionDates() throws {
    let dashboard = try CapturedResponseTests.dashboard()
    #expect(dashboard.sessionDates == nil)
    let streak = WorkoutStreak(dashboard: dashboard)
    #expect(streak.days.count == 7)
    #expect(streak.attendance == StreakFigure(count: 0, target: nil))
    #expect(streak.complete == StreakFigure(count: 0, target: nil))
  }
}
