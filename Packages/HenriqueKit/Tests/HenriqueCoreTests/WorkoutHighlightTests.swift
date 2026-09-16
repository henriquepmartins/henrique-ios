import Foundation
import Testing

@testable import HenriqueCore

@Suite("Onda nas pastas de treino")
struct WorkoutHighlightTests {
  @Test("destaca todos os mais feitos e o treino em andamento")
  func tiedLeadersAndActiveWorkout() throws {
    var dashboard = try ContractTests.dashboard()
    dashboard.workout?.id = "ativo"
    dashboard.weeklyWorkoutSessions = [
      .init(workoutTemplateId: "a", count: 2),
      .init(workoutTemplateId: "b", count: 2),
      .init(workoutTemplateId: "c", count: 1),
    ]
    #expect(dashboard.highlightedWorkoutIDs == ["a", "b", "ativo"])
  }

  @Test("sem histórico não transforma agenda em frequência")
  func legacyServerUsesOnlyInProgressWorkout() throws {
    var dashboard = try ContractTests.dashboard()
    #expect(dashboard.weeklyWorkoutSessions == nil)
    let workout = try #require(dashboard.workout)
    #expect(dashboard.highlightedWorkoutIDs == [workout.id])
    dashboard.workout?.completedWorkSetCount = 0
    #expect(dashboard.highlightedWorkoutIDs.isEmpty)
    dashboard.workout?.completedWorkSetCount = workout.workSetCount
    #expect(dashboard.highlightedWorkoutIDs.isEmpty)
  }

  @Test("zero sessões não cria líderes")
  func zeroAndEmptyWeek() throws {
    var dashboard = try ContractTests.dashboard()
    dashboard.workout = nil
    dashboard.weeklyWorkoutSessions = [.init(workoutTemplateId: "a", count: 0)]
    #expect(dashboard.highlightedWorkoutIDs.isEmpty)
    dashboard.weeklyWorkoutSessions = []
    #expect(dashboard.highlightedWorkoutIDs.isEmpty)
  }

  @Test("decodifica frequência nova sem depender da agenda atual")
  func decodesWeeklyCounts() throws {
    var json = try #require(JSONSerialization.jsonObject(
      with: ContractTests.fixture("dashboard")) as? [String: Any])
    json["weeklyWorkoutSessions"] = [["workoutTemplateId": "fora-da-agenda", "count": 3]]
    let dashboard = try JSONDecoder.henrique().decode(
      Dashboard.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(dashboard.weeklyWorkoutSessions == [.init(workoutTemplateId: "fora-da-agenda", count: 3)])
    #expect(dashboard.highlightedWorkoutIDs.contains("fora-da-agenda"))
  }
}
