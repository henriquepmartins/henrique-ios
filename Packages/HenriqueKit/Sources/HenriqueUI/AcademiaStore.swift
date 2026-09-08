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

  public init(client: APIClient) {
    self.client = client
  }

  public func start() async {
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
    await client.signOut()
    isSignedIn = false
    dashboard = nil
    phase = .idle
  }

  public func load() async {
    if dashboard == nil { phase = .loading }
    await apply { try await self.client.dashboard(on: self.selectedDate) }
  }

  public func select(date: CalendarDate) async {
    guard date != selectedDate else { return }
    selectedDate = date
    await load()
  }

  /// Grava a série e recebe o painel inteiro de volta. O servidor é quem decide
  /// o estado final, então a tela não tenta adivinhar antes da resposta.
  public func record(
    exercise: DashboardExercise, kind: SetKey.Kind, index: Int, weightKg: Double, reps: Int,
    completed: Bool, toFailure: Bool
  ) async {
    guard let templateId = dashboard?.workout?.id else { return }
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

  public func addMeasurement(_ input: AddMeasurementInput) async {
    await apply { try await self.client.addMeasurement(input) }
  }

  public func saveWorkout(_ input: SaveWorkoutInput) async {
    await apply { try await self.client.saveWorkout(input) }
  }

  public func setStrengthGoal(_ input: SetStrengthGoalInput) async {
    await apply { try await self.client.setStrengthGoal(input) }
  }

  /// Toda chamada devolve o painel inteiro, então o tratamento de erro e a
  /// troca de estado ficam num lugar só.
  private func apply(_ work: @Sendable () async throws -> Dashboard) async {
    do {
      dashboard = try await work()
      phase = .ready
      banner = nil
    } catch APIError.unauthorized {
      isSignedIn = false
      dashboard = nil
      phase = .idle
      banner = "Sua sessão expirou. Entre de novo."
    } catch let error as APIError {
      if dashboard == nil {
        phase = .failed(error.message)
      } else {
        banner = error.message
      }
    } catch {
      banner = "Algo deu errado."
    }
  }
}
