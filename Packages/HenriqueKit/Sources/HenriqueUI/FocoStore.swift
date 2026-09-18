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

/// O registro local é a verdade e a fila offline. O servidor guarda as sessões
/// e a meta; `sync()` sobe o que está pendente e traz o resto. Uma falha de
/// rede não chega ao usuário: a fila fica para a próxima.
@Observable
@MainActor
public final class FocoStore {
  public private(set) var ledger: FocoLedger
  /// Verdadeiro só entre abrir o app com uma corrida gravada e a primeira tela
  /// de foco reabrir o cronômetro. Minimizar depois disso não reabre.
  private var resumePending: Bool
  private let fileURL: URL
  private let estudos: EstudosStore?
  private let calendar = StudyFormat.calendar
  @ObservationIgnored private var syncing = false

  static let batchSize = 500

  public init(fileURL: URL = FocoStore.defaultFileURL, estudos: EstudosStore?) {
    self.fileURL = fileURL
    self.estudos = estudos
    let loaded = Self.load(from: fileURL)
    ledger = loaded
    resumePending = loaded.running != nil
  }

  public func takeResume() -> Bool {
    defer { resumePending = false }
    return resumePending
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
    Task { await sync() }
    return result
  }

  public func remove(_ entry: FocoEntry) {
    ledger.remove(id: entry.id)
    save()
    Task { await sync() }
  }

  public func setGoal(minutes: Int) {
    ledger.setGoal(minutes: minutes)
    save()
    Task { await sync() }
  }

  // MARK: Sincronização

  /// Sobe a fila e depois adota a lista do servidor. Um sync por vez; o segundo
  /// pedido enquanto um roda é descartado, porque o que ele subiria já está na
  /// fila do primeiro ou entra na próxima chamada.
  public func sync() async {
    guard let client = estudos?.client, !syncing else { return }
    syncing = true
    defer { syncing = false }
    do {
      try await pushUploads(client)
      try await pushRemovals(client)
      if ledger.goalDirty {
        _ = try await client.focoSetGoal(minutes: ledger.dailyGoalMinutes)
        ledger.markGoalSynced()
        save()
      }
      let list = try await client.focoList()
      ledger.merge(server: list.entries, serverGoal: list.dailyGoalMinutes)
      save()
    } catch {
      // Sem rede ou sessão caída a fila fica como está. O 401 já derrubou o
      // token no cliente, e a próxima tela que falar com o servidor desloga.
    }
  }

  private func pushUploads(_ client: APIClient) async throws {
    while !ledger.pendingUploads.isEmpty {
      let batch = ledger.entries
        .filter { ledger.pendingUploads.contains($0.id) }
        .prefix(Self.batchSize)
      guard !batch.isEmpty else { return }
      // `saved` volta sem o id que já pertence a outro usuário. Insistir nele
      // não muda nada, então o lote inteiro sai da fila.
      _ = try await client.focoSave(Array(batch))
      ledger.markUploaded(batch.map(\.id))
      save()
    }
  }

  private func pushRemovals(_ client: APIClient) async throws {
    while !ledger.pendingRemovals.isEmpty {
      let batch = Array(ledger.pendingRemovals.prefix(Self.batchSize))
      _ = try await client.focoRemove(ids: batch)
      ledger.markRemoved(batch)
      save()
    }
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

  /// O JSON no disco usa o mesmo codificador do cliente HTTP. O antigo gravava
  /// sem fração de segundo, e o `henrique()` lê os dois formatos.
  private static let encoder = JSONEncoder.henrique()
  private static let decoder = JSONDecoder.henrique()
}
