import Foundation
import HenriqueCore
import Observation

/// Identifica uma série dentro do treino do dia. Serve para saber quais linhas
/// estão esperando o servidor sem travar a tela inteira.
public struct SetKey: Hashable, Sendable {
  public enum Kind: Hashable, Sendable { case prep, work }

  public let exerciseId: String
  public let kind: Kind
  public let index: Int

  public init(exerciseId: String, kind: Kind, index: Int) {
    self.exerciseId = exerciseId
    self.kind = kind
    self.index = index
  }
}

@MainActor
@Observable
public final class AcademiaStore {
  public enum Phase: Equatable, Sendable {
    case idle
    case loading
    case ready
    case failed(String)
  }

  public private(set) var phase: Phase = .idle
  public private(set) var dashboard: Dashboard?
  public private(set) var inFlight: Set<SetKey> = []
  public private(set) var isSignedIn: Bool = false
  public var selectedDate: CalendarDate = .today
  public var banner: String?

  private let client: APIClient
  private struct CachedDay {
    let dashboard: Dashboard
    let storedAt: Date
  }
  @ObservationIgnored private var dayCache: [CalendarDate: CachedDay] = [:]
  @ObservationIgnored private var readTask: Task<Void, Never>?
  @ObservationIgnored private var readID = UUID()
  @ObservationIgnored private var sessionID = UUID()

  private func cancelRead() {
    readID = UUID()
    readTask?.cancel()
    readTask = nil
  }

  private func invalidateDays() {
    dayCache.removeAll()
    cancelRead()
  }

  private func remember(_ value: Dashboard) {
    dayCache[value.date] = CachedDay(dashboard: value, storedAt: Date())
    if dayCache.count > 14, let oldest = dayCache.min(by: { $0.value.storedAt < $1.value.storedAt })?.key {
      dayCache.removeValue(forKey: oldest)
    }
  }

  public init(client: APIClient) {
    self.client = client
  }

  #if DEBUG
    /// A casca do app sem servidor nem conta, só para capturar as telas com
    /// `--casca`. Nada carrega, então as abas aparecem vazias.
    @ObservationIgnored private var isCaptureShell = false

    public func openCaptureShell() {
      isCaptureShell = true
      isSignedIn = true
      phase = .ready
    }
  #endif

  public func start() async {
    #if DEBUG
      if isCaptureShell { return }
    #endif
    isSignedIn = await client.isSignedIn
    guard isSignedIn else {
      phase = .idle
      return
    }
    await load()
  }

  public func signIn(username: String, password: String) async {
    phase = .loading
    do {
      try await client.signIn(username: username, password: password)
      isSignedIn = true
      await load()
    } catch let error as APIError {
      phase = .failed(error.message)
    } catch {
      phase = .failed("Não consegui entrar.")
    }
  }

  public func signOut() async {
    sessionID = UUID()
    invalidateDays()
    isSignedIn = false
    dashboard = nil
    banner = nil
    phase = .idle
    await client.signOut()
  }

  public func load() async {
    await fetchDay(selectedDate)
  }

  public func select(date: CalendarDate) async {
    guard date != selectedDate else { return }
    selectedDate = date
    banner = nil
    if let cached = dayCache[date], Date().timeIntervalSince(cached.storedAt) < 30 {
      dashboard = cached.dashboard
      phase = .ready
    }
    await fetchDay(date)
  }

  private func fetchDay(_ date: CalendarDate) async {
    cancelRead()
    let requestID = readID
    if dashboard == nil { phase = .loading }
    let task = Task { [weak self, client] in
      do {
        let received = try await client.dashboard(on: date)
        guard let self, self.readID == requestID, self.selectedDate == date,
          received.date == date, !Task.isCancelled else { return }
        self.remember(received)
        self.dashboard = received
        self.phase = .ready
        self.banner = nil
      } catch {
        guard let self, self.readID == requestID, self.selectedDate == date,
          !Task.isCancelled, !(error is CancellationError) else { return }
        self.handle(error)
      }
    }
    readTask = task
    await task.value
    if readID == requestID { readTask = nil }
  }

  /// Grava a série e recebe o painel inteiro de volta. O servidor é quem decide
  /// o estado final, então a tela não tenta adivinhar antes da resposta.
  public func record(
    exercise: DashboardExercise, kind: SetKey.Kind, index: Int, weightKg: Double, reps: Int,
    completed: Bool, toFailure: Bool
  ) async {
    guard dashboard?.date == selectedDate, let templateId = dashboard?.workout?.id else { return }
    let key = SetKey(exerciseId: exercise.id, kind: kind, index: index)
    guard !inFlight.contains(key) else { return }

    let fields = RecordSetInput.Fields(
      date: selectedDate, workoutTemplateId: templateId, exerciseId: exercise.id, setIndex: index,
      weightKg: weightKg, reps: reps, completed: completed)
    let input: RecordSetInput =
      kind == .prep ? .prep(fields) : .work(fields, toFailure: toFailure)

    inFlight.insert(key)
    defer { inFlight.remove(key) }
    await apply { try await self.client.recordSet(input) }
  }

  @discardableResult
  public func addMeasurement(_ input: AddMeasurementInput) async -> Bool {
    await apply { try await self.client.addMeasurement(input) }
  }

  @discardableResult
  public func saveWorkout(_ input: SaveWorkoutInput) async -> Bool {
    await apply { try await self.client.saveWorkout(input) }
  }

  @discardableResult
  public func setStrengthGoal(_ input: SetStrengthGoalInput) async -> Bool {
    await apply { try await self.client.setStrengthGoal(input) }
  }

  @discardableResult
  public func completeSetup() async -> Bool {
    await apply {
      try await self.client.completeOnboarding()
      return try await self.client.dashboard(on: self.selectedDate)
    }
  }

  /// Toda chamada devolve o painel inteiro, então o tratamento de erro e a
  /// troca de estado ficam num lugar só.
  @discardableResult
  private func apply(_ work: @Sendable () async throws -> Dashboard) async -> Bool {
    invalidateDays()
    let mutationSession = sessionID
    do {
      let received = try await work()
      guard sessionID == mutationSession else { return false }
      invalidateDays()
      guard received.date == selectedDate else { return true }
      dashboard = received
      phase = .ready
      banner = nil
      return true
    } catch {
      guard sessionID == mutationSession else { return false }
      invalidateDays()
      if !(error is CancellationError) { handle(error) }
    }
    return false
  }

  private func handle(_ error: any Error) {
    switch error {
    case APIError.unauthorized:
      sessionID = UUID()
      invalidateDays()
      isSignedIn = false
      dashboard = nil
      phase = .idle
      banner = "Sua sessão expirou. Entre de novo."
    case let error as APIError:
      if dashboard == nil {
        phase = .failed(error.message)
      } else {
        banner = error.message
      }
    default:
      banner = "Algo deu errado."
    }
  }
}
