import Foundation

// MARK: - Trilha

/// O que se estuda: uma matéria de estudos ou o alemão de idiomas. O registro
/// guarda uma cópia do nome e da cor em cada sessão, então renomear a matéria
/// não reescreve o histórico.
public struct FocoTrack: Codable, Hashable, Sendable, Identifiable {
  public enum Source: String, Codable, Hashable, Sendable { case estudos, idiomas }

  public var id: String
  public var name: String
  public var color: String
  public var source: Source
  public var subjectId: String?

  public init(id: String, name: String, color: String, source: Source, subjectId: String? = nil) {
    self.id = id
    self.name = name
    self.color = color
    self.source = source
    self.subjectId = subjectId
  }

  public static let alemao = FocoTrack(
    id: "idiomas:alemao", name: "alemão", color: "#0b6e4f", source: .idiomas)

  public static func subject(id: String, name: String, color: String) -> FocoTrack {
    FocoTrack(id: "estudos:\(id)", name: name, color: color, source: .estudos, subjectId: id)
  }
}

// MARK: - Sessões

public struct FocoEntry: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID
  public var track: FocoTrack
  public var startedAt: Date
  public var endedAt: Date

  public init(id: UUID = UUID(), track: FocoTrack, startedAt: Date, endedAt: Date) {
    self.id = id
    self.track = track
    self.startedAt = startedAt
    self.endedAt = endedAt
  }

  public var seconds: TimeInterval { endedAt.timeIntervalSince(startedAt) }
}

public struct FocoRun: Codable, Hashable, Sendable {
  public var track: FocoTrack
  public var startedAt: Date
  public var serverSessionId: String?

  public init(track: FocoTrack, startedAt: Date, serverSessionId: String? = nil) {
    self.track = track
    self.startedAt = startedAt
    self.serverSessionId = serverSessionId
  }

  public func seconds(at now: Date) -> TimeInterval { max(0, now.timeIntervalSince(startedAt)) }
}

public struct FocoStreak: Hashable, Sendable {
  public var current: Int
  public var best: Int
  public var isTodayDone: Bool

  public init(current: Int, best: Int, isTodayDone: Bool) {
    self.current = current
    self.best = best
    self.isTodayDone = isTodayDone
  }
}

public struct FocoDay: Hashable, Sendable, Identifiable {
  public var date: CalendarDate
  public var seconds: TimeInterval
  public var level: Int
  public var id: CalendarDate { date }

  public init(date: CalendarDate, seconds: TimeInterval, level: Int) {
    self.date = date
    self.seconds = seconds
    self.level = level
  }
}

// MARK: - Registro

/// O registro inteiro de foco, no aparelho. Uma sessão pertence ao dia em que
/// começou, inclusive a que atravessa a meia-noite, e a corrida em andamento
/// entra em toda soma.
public struct FocoLedger: Codable, Hashable, Sendable {
  public var entries: [FocoEntry] = []
  public var running: FocoRun?
  public var dailyGoalMinutes: Int = 120

  public static let minimumSeconds: TimeInterval = 10
  public static let dayCountsMinutes = 25

  public init(entries: [FocoEntry] = [], running: FocoRun? = nil, dailyGoalMinutes: Int = 120) {
    self.entries = entries
    self.running = running
    self.dailyGoalMinutes = dailyGoalMinutes
  }

  public mutating func start(_ track: FocoTrack, at now: Date) {
    if running != nil { _ = stop(at: now) }
    running = FocoRun(track: track, startedAt: now)
  }

  @discardableResult
  public mutating func stop(at now: Date) -> FocoEntry? {
    guard let run = running else { return nil }
    running = nil
    guard run.seconds(at: now) >= Self.minimumSeconds else { return nil }
    let entry = FocoEntry(track: run.track, startedAt: run.startedAt, endedAt: now)
    entries.append(entry)
    return entry
  }

  public mutating func remove(id: UUID) {
    entries.removeAll { $0.id == id }
  }

  public func seconds(on day: CalendarDate, now: Date, calendar: Calendar) -> TimeInterval {
    seconds(on: day, track: nil, now: now, calendar: calendar)
  }

  public func seconds(on day: CalendarDate, track id: String, now: Date, calendar: Calendar)
    -> TimeInterval
  {
    seconds(on: day, track: Optional(id), now: now, calendar: calendar)
  }

  public func entries(on day: CalendarDate, calendar: Calendar) -> [FocoEntry] {
    entries
      .filter { CalendarDate($0.startedAt, in: calendar) == day }
      .sorted { $0.startedAt > $1.startedAt }
  }

  public func streak(now: Date, calendar: Calendar) -> FocoStreak {
    let today = CalendarDate(now, in: calendar)
    let counted = countedDays(now: now, calendar: calendar)
    let isTodayDone = counted.contains(today)

    var current = 0
    var cursor = isTodayDone ? today : today.adding(days: -1, in: calendar)
    while counted.contains(cursor) {
      current += 1
      cursor = cursor.adding(days: -1, in: calendar)
    }

    var best = 0
    var run = 0
    var previous: CalendarDate?
    for day in counted.sorted() {
      if let previous, previous.adding(days: 1, in: calendar) == day {
        run += 1
      } else {
        run = 1
      }
      best = max(best, run)
      previous = day
    }
    return FocoStreak(current: current, best: best, isTodayDone: isTodayDone)
  }

  public func days(endingOn today: CalendarDate, count: Int, now: Date, calendar: Calendar)
    -> [FocoDay]
  {
    let totals = secondsByDay(now: now, calendar: calendar)
    let goal = Double(max(dailyGoalMinutes, 1)) * 60
    return (0..<count).reversed().map { back in
      let date = today.adding(days: -back, in: calendar)
      let seconds = totals[date] ?? 0
      return FocoDay(date: date, seconds: seconds, level: Self.level(seconds: seconds, goal: goal))
    }
  }

  static func level(seconds: TimeInterval, goal: TimeInterval) -> Int {
    guard seconds > 0 else { return 0 }
    let fraction = seconds / goal
    if fraction < 0.25 { return 1 }
    if fraction < 0.5 { return 2 }
    if fraction < 1 { return 3 }
    return 4
  }

  private func seconds(on day: CalendarDate, track id: String?, now: Date, calendar: Calendar)
    -> TimeInterval
  {
    var total = entries
      .filter { CalendarDate($0.startedAt, in: calendar) == day && (id == nil || $0.track.id == id) }
      .reduce(0) { $0 + $1.seconds }
    if let running, id == nil || running.track.id == id,
      CalendarDate(running.startedAt, in: calendar) == day
    {
      total += running.seconds(at: now)
    }
    return total
  }

  private func secondsByDay(now: Date, calendar: Calendar) -> [CalendarDate: TimeInterval] {
    var totals: [CalendarDate: TimeInterval] = [:]
    for entry in entries {
      totals[CalendarDate(entry.startedAt, in: calendar), default: 0] += entry.seconds
    }
    if let running {
      totals[CalendarDate(running.startedAt, in: calendar), default: 0] += running.seconds(at: now)
    }
    return totals
  }

  private func countedDays(now: Date, calendar: Calendar) -> Set<CalendarDate> {
    let floor = Double(Self.dayCountsMinutes) * 60
    return Set(secondsByDay(now: now, calendar: calendar).filter { $0.value >= floor }.keys)
  }
}
