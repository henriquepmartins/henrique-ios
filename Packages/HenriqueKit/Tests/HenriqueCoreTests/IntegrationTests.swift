import Foundation
import Testing

@testable import HenriqueCore

/// Sobe contra o servidor de verdade. Fica desligado por padrão porque depende
/// de um banco rodando; para ligar:
///
///     bun run dev
///     HENRIQUE_TEST_BASE_URL=http://localhost:3000 \
///     HENRIQUE_TEST_USERNAME=henrique HENRIQUE_TEST_PASSWORD=... swift test
@Suite(
  "Integração com o servidor",
  .enabled(if: ProcessInfo.processInfo.environment["HENRIQUE_TEST_BASE_URL"] != nil))
struct IntegrationTests {
  static func client() throws -> APIClient {
    let environment = ProcessInfo.processInfo.environment
    let raw = try #require(environment["HENRIQUE_TEST_BASE_URL"])
    let url = try #require(URL(string: raw))
    return APIClient(baseURL: url, tokenStore: MemoryTokenStore())
  }

  static func signedInClient() async throws -> APIClient {
    let environment = ProcessInfo.processInfo.environment
    let client = try client()
    let username = try #require(environment["HENRIQUE_TEST_USERNAME"])
    let password = try #require(environment["HENRIQUE_TEST_PASSWORD"])
    try await client.signIn(username: username, password: password)
    return client
  }

  @Test("entra e guarda o cookie de sessão")
  func signsIn() async throws {
    let client = try await Self.signedInClient()
    #expect(await client.isSignedIn)
  }

  @Test("senha errada não abre sessão")
  func rejectsBadPassword() async throws {
    let client = try Self.client()
    await #expect(throws: APIError.self) {
      try await client.signIn(username: "henrique", password: "senha-errada")
    }
    #expect(await client.isSignedIn == false)
  }

  @Test("sem sessão o painel responde 401")
  func unauthorizedWithoutSession() async throws {
    let client = try Self.client()
    await #expect(throws: APIError.unauthorized) {
      _ = try await client.dashboard(on: .today)
    }
  }

  @Test("o painel do dia chega decodificado")
  func loadsDashboard() async throws {
    let client = try await Self.signedInClient()
    let date = try #require(CalendarDate(iso: "2026-09-13"))
    let dashboard = try await client.dashboard(on: date)
    #expect(dashboard.date == date)
    #expect(!dashboard.exerciseCatalog.isEmpty)
  }

  /// Gravar a mesma série duas vezes tem que parar no mesmo lugar. É o que
  /// deixa a tela repetir a chamada depois de uma queda de rede sem inventar
  /// uma série a mais.
  @Test("gravar a mesma série duas vezes dá o mesmo resultado")
  func recordingIsIdempotent() async throws {
    let client = try await Self.signedInClient()
    let date = try #require(CalendarDate(iso: "2026-09-13"))
    let before = try await client.dashboard(on: date)
    let workout = try #require(before.workout)
    let exercise = try #require(workout.exercises.first)

    let input = RecordSetInput.work(
      .init(
        date: date, workoutTemplateId: workout.id, exerciseId: exercise.id, setIndex: 1,
        weightKg: 12.5, reps: 11, completed: true),
      toFailure: true)

    let first = try await client.recordSet(input)
    let second = try await client.recordSet(input)

    let firstSet = try #require(first.workout?.exercises.first?.sets.work.first)
    let secondSet = try #require(second.workout?.exercises.first?.sets.work.first)
    #expect(firstSet.weightKg == secondSet.weightKg)
    #expect(firstSet.reps == secondSet.reps)
    #expect(firstSet.isDone && secondSet.isDone)
    #expect(first.workout?.completedWorkSetCount == second.workout?.completedWorkSetCount)
  }
}
