import Foundation

public struct ExercisePrescription: Codable, Hashable, Sendable {
  public var prepSets: Int
  public var workSets: Int
  public var repsMin: Int
  public var repsMax: Int
  public var workToFailure: Bool
  public var startingWeightKg: Double

  public init(
    prepSets: Int, workSets: Int, repsMin: Int, repsMax: Int, workToFailure: Bool,
    startingWeightKg: Double
  ) {
    self.prepSets = prepSets
    self.workSets = workSets
    self.repsMin = repsMin
    self.repsMax = repsMax
    self.workToFailure = workToFailure
    self.startingWeightKg = startingWeightKg
  }

  public var repsLabel: String {
    repsMin == repsMax ? "\(repsMin)" : "\(repsMin)–\(repsMax)"
  }
}

/// A série de aquecimento. O índice é único dentro do exercício, então serve de
/// identidade estável para a lista.
public struct PrepSet: Codable, Hashable, Sendable, Identifiable {
  public var index: Int
  public var weightKg: Double
  public var reps: Int
  public var completedAt: Date?

  public var id: Int { index }
  public var isDone: Bool { completedAt != nil }
}

public struct WorkSet: Codable, Hashable, Sendable, Identifiable {
  public var index: Int
  public var weightKg: Double
  public var reps: Int
  public var toFailure: Bool
  public var completedAt: Date?

  public var id: Int { index }
  public var isDone: Bool { completedAt != nil }
}

public struct ExerciseSets: Codable, Hashable, Sendable {
  public var prep: [PrepSet]
  public var work: [WorkSet]

  public var completedWorkCount: Int { work.count(where: \.isDone) }
}

public struct PreviousWorkSets: Codable, Hashable, Sendable {
  public var date: CalendarDate
  public var weightKg: Double
  public var reps: [Int]
  public var volumeKg: Double
}

public struct DashboardExercise: Codable, Hashable, Sendable, Identifiable {
  public var id: String
  public var name: String
  public var muscleGroup: String
  public var equipment: String
  public var order: Int
  public var prescription: ExercisePrescription
  public var previous: PreviousWorkSets?
  public var sets: ExerciseSets

  public var isComplete: Bool { sets.completedWorkCount >= prescription.workSets }
}

public struct WorkoutSummary: Codable, Hashable, Sendable, Identifiable {
  public var id: String
  public var name: String
  public var focus: String
  public var estimatedMinutes: Int
  public var exerciseCount: Int
  public var workSetCount: Int
  public var completedWorkSetCount: Int
  public var completionPercent: Int
  public var exercises: [DashboardExercise]
}

public struct ProgressPoint: Codable, Hashable, Sendable, Identifiable {
  public var date: CalendarDate
  public var estimatedOneRepMax: Double
  public var volumeKg: Double

  public var id: CalendarDate { date }
}

public struct BodyMeasurement: Codable, Hashable, Sendable, Identifiable {
  public var id: String
  public var date: CalendarDate
  public var weightKg: Double
  public var bodyFatPercent: Double?
  public var waistCm: Double?
  public var chestCm: Double?
  public var armCm: Double?
  public var thighCm: Double?
}

public enum ProjectionConfidence: String, Codable, Hashable, Sendable {
  case low, medium, high

  public var label: String {
    switch self {
    case .low: "estimativa fraca"
    case .medium: "estimativa razoável"
    case .high: "estimativa firme"
    }
  }
}

public struct Projection: Codable, Hashable, Sendable {
  public var metric: String
  public var current: Double
  public var target: Double
  public var weeklyChange: Double
  public var weeksRemaining: Int?
  public var confidence: ProjectionConfidence
}

public struct PlanExercise: Codable, Hashable, Sendable, Identifiable {
  public var exerciseId: String
  public var prepSets: Int
  public var workSets: Int
  public var repsMin: Int
  public var repsMax: Int
  public var workToFailure: Bool
  public var startingWeightKg: Double

  public var id: String { exerciseId }

  public init(
    exerciseId: String, prepSets: Int, workSets: Int, repsMin: Int, repsMax: Int,
    workToFailure: Bool, startingWeightKg: Double
  ) {
    self.exerciseId = exerciseId
    self.prepSets = prepSets
    self.workSets = workSets
    self.repsMin = repsMin
    self.repsMax = repsMax
    self.workToFailure = workToFailure
    self.startingWeightKg = startingWeightKg
  }
}

public struct WeekPlanItem: Codable, Hashable, Sendable, Identifiable {
  public var id: String
  public var weekday: Int
  public var name: String
  public var focus: String
  public var exerciseCount: Int
  public var exercises: [PlanExercise]
  public var estimatedMinutes: Int
}

public struct ExerciseCatalogItem: Codable, Hashable, Sendable, Identifiable {
  public var id: String
  public var name: String
  public var muscleGroup: String
  public var equipment: String
}

public struct StrengthGoal: Codable, Hashable, Sendable {
  public var exerciseId: String
  public var exerciseName: String
  public var targetValue: Double
  public var lastSession: PreviousWorkSets?
}

public struct Dashboard: Codable, Hashable, Sendable {
  public var date: CalendarDate
  public var workout: WorkoutSummary?
  public var consistencyPercent: Int
  public var currentStreak: Int
  public var weeklyCompleted: Int
  public var weeklyPlanned: Int
  public var weekPlan: [WeekPlanItem]
  /// Os dias com sessão concluída nas últimas quatro semanas. Nulo quando o
  /// servidor é velho demais para mandar o campo, e aí é "não sei", diferente da
  /// lista vazia, que é "nenhum treino".
  public var sessionDates: [CalendarDate]?
  public var exerciseCatalog: [ExerciseCatalogItem]
  public var strengthGoal: StrengthGoal?
  public var progress: [ProgressPoint]
  public var measurements: [BodyMeasurement]
  public var projection: Projection?
  public var onboardingCompleted: Bool
}

/// A fórmula de Epley, a mesma que o servidor usa para o gráfico de força.
public func estimateOneRepMax(weightKg: Double, reps: Int) -> Double {
  guard weightKg > 0, reps > 0 else { return 0 }
  if reps == 1 { return weightKg }
  return weightKg * (1 + Double(reps) / 30)
}

public func workVolumeKg(_ work: [WorkSet]) -> Double {
  work.reduce(0) { $0 + ($1.isDone ? $1.weightKg * Double($1.reps) : 0) }
}
