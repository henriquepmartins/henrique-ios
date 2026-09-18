import Foundation
import HenriqueCore
import Observation

/// O que a tela escura mostra depois de parar: a sessão gravada (ou nada, se
/// foi curta demais) e o que mudou no streak e na meta por causa dela.
public struct FocoResult: Hashable, Sendable {
  public var entry: FocoEntry?
  public var streakBefore: FocoStreak
  public var streakAfter: FocoStreak
  public var goalJustReached: Bool
}

/// O registro local é a verdade. O servidor só recebe um espelho das sessões
/// de estudos, e uma falha lá não chega ao usuário.
@Observable
@MainActor
public final class FocoStore {
  public private(set) var ledger: FocoLedger
  public private(set) var lastResult: FocoResult?

  private let fileURL: URL
  private let estudos: EstudosStore?
  private let calendar = StudyFormat.calendar

  public init(fileURL: URL = FocoStore.defaultFileURL, estudos: EstudosStore?) {
    self.fileURL = fileURL
    self.estudos = estudos
    ledger = Self.load(from: fileURL)
  }

  public static var defaultFileURL: URL {
    URL.applicationSupportDirectory.appending(path: "foco.json")
  }

  public var isRunning: Bool { ledger.running != nil }

  public func start(_ track: FocoTrack) {
    let previous = ledger.running
    ledger.start(track, at: .now)
    save()
    if let previous, let id = previous.serverSessionId {
      finishOnServer(id: id, seconds: previous.seconds(at: .now))
    }
    guard track.source == .estudos, let subjectId = track.subjectId, let estudos else { return }
    let startedAt = ledger.running?.startedAt
    Task {
      guard let session = try? await estudos.startSession(subjectId: subjectId) else { return }
      if ledger.running?.track.id == track.id, ledger.running?.startedAt == startedAt {
        ledger.running?.serverSessionId = session.id
        save()
      }
    }
  }

  @discardableResult
  public func stop() -> FocoResult? {
    guard let run = ledger.running else { return nil }
    let now = Date.now
    let today = CalendarDate(now, in: calendar)
    let before = ledger.streak(now: now, calendar: calendar)
    let goalBefore = ledger.seconds(on: today, now: run.startedAt, calendar: calendar) >= goalSeconds
    let entry = ledger.stop(at: now)
    save()
    let after = ledger.streak(now: now, calendar: calendar)
    let goalAfter = ledger.seconds(on: today, now: now, calendar: calendar) >= goalSeconds
    if let id = run.serverSessionId {
      finishOnServer(id: id, seconds: run.seconds(at: now))
    }
    let result = FocoResult(
      entry: entry, streakBefore: before, streakAfter: after,
      goalJustReached: goalAfter && !goalBefore)
    lastResult = result
    return result
  }

  public func remove(_ entry: FocoEntry) {
    ledger.remove(id: entry.id)
    save()
  }

  public func setGoal(minutes: Int) {
    ledger.dailyGoalMinutes = minutes
    save()
  }

  private var goalSeconds: TimeInterval { Double(ledger.dailyGoalMinutes) * 60 }

  private func finishOnServer(id: String, seconds: TimeInterval) {
    guard let estudos else { return }
    Task { _ = try? await estudos.finishSession(id: id, minutes: max(1, Int(seconds / 60))) }
  }

  private static func load(from url: URL) -> FocoLedger {
    guard let data = try? Data(contentsOf: url),
      let ledger = try? decoder.decode(FocoLedger.self, from: data)
    else { return FocoLedger() }
    return ledger
  }

  private func save() {
    do {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try Self.encoder.encode(ledger).write(to: fileURL, options: .atomic)
    } catch {
      // Sem disco o registro segue em memória até o app fechar. Não há o que
      // dizer ao usuário que ele possa resolver.
    }
  }

  private static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()

  private static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()
}
