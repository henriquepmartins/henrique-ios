import Foundation
import HenriqueCore
import Observation

public struct SetKey: Hashable, Sendable {
  public enum Kind: Hashable, Sendable { case prep, work }

  public let date: CalendarDate
  public let templateId: String
  public let exerciseId: String
  public let kind: Kind
  public let index: Int

  public init(date: CalendarDate, templateId: String, exerciseId: String, kind: Kind, index: Int) {
    self.date = date
    self.templateId = templateId
    self.exerciseId = exerciseId
    self.kind = kind
    self.index = index
  }
}

struct SetDraft: Equatable, Sendable {
  let weightKg: Double
  let reps: Int
  let completed: Bool
  let toFailure: Bool
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
  /// Falso até a primeira leitura do chaveiro responder. Sem isto, todo arranque
  /// a frio mostra a entrada por uma fração de segundo mesmo com sessão válida.
  public private(set) var sessionChecked = false
  private var acceptedDashboard: Dashboard?
  private struct PendingSet {
    let key: SetKey
    let draft: SetDraft
    let revision: Int
  }
  private var pendingSets: [SetKey: PendingSet] = [:]
  @ObservationIgnored private var mutationTail: Task<Bool, Never>?
  @ObservationIgnored private var revision = 0

  public var dashboard: Dashboard? {
    guard var value = acceptedDashboard else { return nil }
    for pending in pendingSets.values.sorted(by: { $0.revision < $1.revision }) {
      let key = pending.key
      let draft = pending.draft
      if key.kind == .work,
        let plan = value.weekPlan.firstIndex(where: { $0.id == key.templateId }),
        let exercise = value.weekPlan[plan].exercises.firstIndex(where: { $0.exerciseId == key.exerciseId }) {
        value.weekPlan[plan].exercises[exercise].startingWeightKg = draft.weightKg
      }
      guard value.date == key.date, value.workout?.id == key.templateId,
        var workout = value.workout,
        let exercise = workout.exercises.firstIndex(where: { $0.id == key.exerciseId }) else { continue }
      if key.kind == .prep,
        let row = workout.exercises[exercise].sets.prep.firstIndex(where: { $0.index == key.index }) {
        workout.exercises[exercise].sets.prep[row].weightKg = draft.weightKg
        workout.exercises[exercise].sets.prep[row].reps = draft.reps
        workout.exercises[exercise].sets.prep[row].completedAt = draft.completed ? .now : nil
      } else if key.kind == .work,
        let row = workout.exercises[exercise].sets.work.firstIndex(where: { $0.index == key.index }) {
        workout.exercises[exercise].prescription.startingWeightKg = draft.weightKg
        workout.exercises[exercise].sets.work[row].weightKg = draft.weightKg
        workout.exercises[exercise].sets.work[row].reps = draft.reps
        workout.exercises[exercise].sets.work[row].toFailure = draft.toFailure
        workout.exercises[exercise].sets.work[row].completedAt = draft.completed ? .now : nil
      }
      workout.completedWorkSetCount = workout.exercises.reduce(0) { $0 + $1.sets.completedWorkCount }
      workout.completionPercent = workout.workSetCount == 0 ? 0
        : Int((Double(workout.completedWorkSetCount) / Double(workout.workSetCount) * 100).rounded())
      value.workout = workout
    }
    return value
  }
  private var deletingWorkoutIds: Set<String> = []
  public private(set) var isSignedIn: Bool = false
  public var selectedDate: CalendarDate = .today
  public var banner: String?

  private let client: APIClient
  private struct CachedDay {
    let dashboard: Dashboard
    let storedAt: Date
  }
  @ObservationIgnored private var dayCache: [CalendarDate: CachedDay] = [:]
  public private(set) var attendance: [CalendarDate: AttendanceDay] = [:]
  @ObservationIgnored private var attendanceRanges: [ClosedRange<CalendarDate>] = []
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
    persist(value)
  }

  private static var snapshotURL: URL? {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
      .appending(path: "henrique-dashboard.json")
  }

  /// Pinta a última tela salva antes da rede responder. Só vale para hoje: dia
  /// antigo entra apagado e desabilitado, pior que o esqueleto.
  private func loadSnapshot() {
    guard let url = Self.snapshotURL,
      let data = try? Data(contentsOf: url),
      let saved = try? JSONDecoder.henrique().decode(Dashboard.self, from: data),
      saved.date == .today
    else { return }
    acceptedDashboard = saved
    phase = .ready
  }

  private func persist(_ value: Dashboard) {
    guard let url = Self.snapshotURL,
      let data = try? JSONEncoder.henrique().encode(value)
    else { return }
    Task.detached(priority: .background) {
      try? data.write(to: url, options: .atomic)
    }
  }

  private func clearSnapshot() {
    guard let url = Self.snapshotURL else { return }
    Task.detached(priority: .background) {
      try? FileManager.default.removeItem(at: url)
    }
  }

  public init(client: APIClient) {
    self.client = client
    loadSnapshot()
  }

  #if DEBUG
    /// A casca do app sem servidor nem conta, só para capturar as telas com
    /// `--casca`. Nada carrega, então as abas aparecem vazias.
    @ObservationIgnored private var isCaptureShell = false

    public func openCaptureShell() {
      isCaptureShell = true
      isSignedIn = true
      sessionChecked = true
      phase = .ready
    }
  #endif

  public func start() async {
    #if DEBUG
      if isCaptureShell { return }
    #endif
    isSignedIn = await client.isSignedIn
    sessionChecked = true
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
      phase = .failed("não entrou")
    }
  }

  public func signOut() async {
    sessionID = UUID()
    invalidateDays()
    isSignedIn = false
    acceptedDashboard = nil
    clearSnapshot()
    attendance.removeAll()
    attendanceRanges.removeAll()
    pendingSets.removeAll()
    mutationTail?.cancel()
    mutationTail = nil
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
      acceptedDashboard = cached.dashboard
      phase = .ready
    }
    await fetchDay(date)
  }

  private func fetchDay(_ date: CalendarDate) async {
    cancelRead()
    let requestID = readID
    if dashboard == nil { phase = .loading }
    let task = Task { [weak self, client] in
      _ = await self?.mutationTail?.value
      guard !Task.isCancelled else { return }
      do {
        let received = try await client.dashboard(on: date)
        guard let self, self.readID == requestID, self.selectedDate == date,
          received.date == date, !Task.isCancelled else { return }
        self.remember(received)
        self.acceptedDashboard = received
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

  /// Frequência não é dado crítico: falhou, o mapa fica como está, sem banner.
  /// Um intervalo já carregado não volta ao servidor; os dias antigos ficam e
  /// os novos entram por cima.
  public func loadAttendance(from: CalendarDate, to: CalendarDate) async {
    #if DEBUG
      if isCaptureShell { return }
    #endif
    guard from <= to, isSignedIn else { return }
    let range = from...to
    if attendanceRanges.contains(where: { $0.lowerBound <= from && to <= $0.upperBound }) { return }
    let session = sessionID
    guard let days = try? await client.attendance(.init(from: from, to: to)),
      session == sessionID else { return }
    for day in days { attendance[day.date] = day }
    attendanceRanges.append(range)
  }

  @discardableResult
  public func record(
    key: SetKey, weightKg: Double, reps: Int,
    completed: Bool, toFailure: Bool
  ) -> Task<Bool, Never>? {
    guard key.date == selectedDate, dashboard?.date == key.date, dashboard?.workout?.id == key.templateId,
      weightKg.isFinite, weightKg >= 0, reps > 0 else { return nil }
    let draft = SetDraft(weightKg: weightKg, reps: reps, completed: completed, toFailure: toFailure)
    if pendingSets[key]?.draft == draft { return mutationTail }
    revision += 1
    let pending = PendingSet(key: key, draft: draft, revision: revision)
    pendingSets[key] = pending
    let fields = RecordSetInput.Fields(
      date: key.date, workoutTemplateId: key.templateId, exerciseId: key.exerciseId, setIndex: key.index,
      weightKg: weightKg, reps: reps, completed: completed)
    let input: RecordSetInput = key.kind == .prep ? .prep(fields) : .work(fields, toFailure: toFailure)
    return enqueue(pending: pending) { try await self.client.recordSet(input) }
  }

  @discardableResult
  public func addMeasurement(_ input: AddMeasurementInput) async -> Bool {
    await apply { try await self.client.addMeasurement(input) }
  }

  @discardableResult
  public func saveWorkout(_ input: SaveWorkoutInput) async -> Bool {
    await apply { try await self.client.saveWorkout(input) }
  }

  /// O plano sem os treinos que estão sendo apagados. O card some no toque, sem
  /// esperar o servidor apagar as sessões e recalcular o painel.
  public var weekPlan: [WeekPlanItem] {
    (dashboard?.weekPlan ?? []).filter { !deletingWorkoutIds.contains($0.id) }
  }

  /// Volta a mostrar o treino se o servidor recusar. No sucesso o painel novo
  /// chega na mesma volta do laço, já sem ele, e o card não pisca.
  public func deleteWorkout(workoutTemplateId: String) {
    guard deletingWorkoutIds.insert(workoutTemplateId).inserted else { return }
    let date = selectedDate
    Task {
      defer { deletingWorkoutIds.remove(workoutTemplateId) }
      await apply {
        try await self.client.deleteWorkout(.init(date: date, workoutTemplateId: workoutTemplateId))
      }
    }
  }

  @discardableResult
  public func setStrengthGoal(_ input: SetStrengthGoalInput) async -> Bool {
    await apply { try await self.client.setStrengthGoal(input) }
  }

  @discardableResult
  public func setStreakGoal(_ input: SetStreakGoalInput) async -> Bool {
    await apply { try await self.client.setStreakGoal(input) }
  }

  @discardableResult
  public func completeSetup() async -> Bool {
    await apply {
      try await self.client.completeOnboarding()
      return try await self.client.dashboard(on: self.selectedDate)
    }
  }

  @discardableResult
  private func apply(_ work: @escaping @Sendable () async throws -> Dashboard) async -> Bool {
    await enqueue(work).value
  }

  private func enqueue(
    pending: PendingSet? = nil, _ work: @escaping @Sendable () async throws -> Dashboard
  ) -> Task<Bool, Never> {
    invalidateDays()
    let mutationSession = sessionID
    let previous = mutationTail
    let task = Task { @MainActor in
      _ = await previous?.value
      guard sessionID == mutationSession, !Task.isCancelled else { return false }
      defer {
        if let pending, pendingSets[pending.key]?.revision == pending.revision {
          pendingSets.removeValue(forKey: pending.key)
        }
      }
      do {
        let received = try await work()
        guard sessionID == mutationSession, !Task.isCancelled else { return false }
        dayCache.removeAll()
        // a série gravada muda a frequência; o mapa fica na tela e o próximo
        // mês visitado busca de novo.
        attendanceRanges.removeAll()
        remember(received)
        if received.date == selectedDate {
          acceptedDashboard = received
          phase = .ready
        }
        return true
      } catch {
        guard sessionID == mutationSession, !Task.isCancelled else { return false }
        dayCache.removeAll()
        if !(error is CancellationError) { handle(error) }
        return false
      }
    }
    mutationTail = task
    return task
  }

  private func handle(_ error: any Error) {
    switch error {
    case APIError.unauthorized:
      sessionID = UUID()
      invalidateDays()
      isSignedIn = false
      acceptedDashboard = nil
      attendance.removeAll()
      attendanceRanges.removeAll()
      pendingSets.removeAll()
      mutationTail?.cancel()
      mutationTail = nil
      phase = .idle
      banner = "sessão expirou"
    case let error as APIError:
      if dashboard == nil {
        phase = .failed(error.message)
      } else {
        banner = error.message
      }
    default:
      banner = "erro"
    }
  }
}
