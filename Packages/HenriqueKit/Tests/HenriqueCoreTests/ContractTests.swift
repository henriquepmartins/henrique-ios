import Foundation
import Testing

@testable import HenriqueCore

/// O que o servidor manda e o que o app manda de volta. Se a API mudar de forma,
/// é aqui que quebra, e não numa tela em produção.
@Suite("Contrato com a API")
struct ContractTests {
  static func fixture(_ name: String) throws -> Data {
    let url = try #require(
      Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "json"),
      "a fixture \(name).json não foi copiada para o bundle de teste")
    return try Data(contentsOf: url)
  }

  static func dashboard() throws -> Dashboard {
    try JSONDecoder.henrique().decode(Dashboard.self, from: fixture("dashboard"))
  }

  @Test("o painel do dia decodifica inteiro")
  func decodesDashboard() throws {
    let dashboard = try Self.dashboard()
    #expect(dashboard.date.iso == "2026-09-08")
    #expect(dashboard.currentStreak == 4)
    #expect(dashboard.weeklyCompleted == 2)
    #expect(dashboard.weeklyPlanned == 4)
    #expect(dashboard.onboardingCompleted)
    #expect(dashboard.workout?.name == "Empurrar A")
    #expect(dashboard.workout?.exercises.count == 2)
  }

  @Test("o instante da série aceita com e sem milissegundos")
  func decodesBothTimestampShapes() throws {
    let exercises = try #require(Self.dashboard().workout?.exercises)
    let comFracao = try #require(exercises[0].sets.prep.first?.completedAt)
    let semFracao = try #require(exercises[0].sets.work.first?.completedAt)
    #expect(comFracao.timeIntervalSince1970 > 0)
    #expect(semFracao.timeIntervalSince1970 > 0)
    #expect(semFracao > comFracao)
  }

  @Test("série sem completedAt fica pendente")
  func openSetHasNoTimestamp() throws {
    let exercises = try #require(Self.dashboard().workout?.exercises)
    #expect(exercises[0].sets.work[0].isDone)
    #expect(!exercises[0].sets.work[1].isDone)
    #expect(exercises[0].sets.completedWorkCount == 1)
  }

  @Test("o exercício sem histórico decodifica com previous nulo")
  func missingPreviousIsNil() throws {
    let exercises = try #require(Self.dashboard().workout?.exercises)
    #expect(exercises[0].previous?.weightKg == 42.5)
    #expect(exercises[1].previous == nil)
  }

  @Test("as medidas opcionais viram nulo, não zero")
  func nullMeasurementsStayNil() throws {
    let measurement = try #require(Self.dashboard().measurements.first)
    #expect(measurement.weightKg == 78.4)
    #expect(measurement.bodyFatPercent == 18.2)
    #expect(measurement.chestCm == nil)
    #expect(measurement.armCm == nil)
  }

  @Test("a confiança da projeção casa com o enum do servidor")
  func projectionConfidence() throws {
    let projection = try #require(Self.dashboard().projection)
    #expect(projection.confidence == .medium)
    #expect(projection.weeksRemaining == 4)
  }

  @Test("o exercício fica completo quando todas as séries de trabalho terminam")
  func completionMatchesPrescription() throws {
    let exercises = try #require(Self.dashboard().workout?.exercises)
    #expect(!exercises[0].isComplete)
    #expect(exercises[0].prescription.repsLabel == "6–10")
  }

  @Test("o aquecimento sai sem o campo de falha")
  func prepSetOmitsToFailure() throws {
    let input = RecordSetInput.prep(
      .init(
        date: try #require(CalendarDate(iso: "2026-09-08")), workoutTemplateId: "tpl-terca",
        exerciseId: "supino-reto", setIndex: 1, weightKg: 20, reps: 10, completed: true))
    let json = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(input)) as? [String: Any])
    #expect(json["kind"] as? String == "prep")
    #expect(json["toFailure"] == nil)
    #expect(json["date"] as? String == "2026-09-08")
    #expect(json["weightKg"] as? Double == 20)
  }

  @Test("a série de trabalho sempre leva o campo de falha")
  func workSetCarriesToFailure() throws {
    let input = RecordSetInput.work(
      .init(
        date: try #require(CalendarDate(iso: "2026-09-08")), workoutTemplateId: "tpl-terca",
        exerciseId: "supino-reto", setIndex: 2, weightKg: 42.5, reps: 9, completed: true),
      toFailure: true)
    let json = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(input)) as? [String: Any])
    #expect(json["kind"] as? String == "work")
    #expect(json["toFailure"] as? Bool == true)
    #expect(json["setIndex"] as? Int == 2)
  }

  @Test("a estimativa de 1RM bate com a do servidor")
  func oneRepMaxMatchesServer() {
    #expect(estimateOneRepMax(weightKg: 42.5, reps: 9) == 42.5 * (1 + 9.0 / 30))
    #expect(estimateOneRepMax(weightKg: 60, reps: 1) == 60)
    #expect(estimateOneRepMax(weightKg: 0, reps: 5) == 0)
    #expect(estimateOneRepMax(weightKg: 50, reps: 0) == 0)
  }

  @Test("o volume só conta série concluída")
  func volumeCountsDoneSetsOnly() throws {
    let exercise = try #require(Self.dashboard().workout?.exercises.first)
    #expect(workVolumeKg(exercise.sets.work) == 42.5 * 9)
  }
}
