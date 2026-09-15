import Foundation

/// A série gravada. O aquecimento não tem falha e a série de trabalho sempre
/// tem, então o enum impede de montar a combinação que o servidor recusaria.
public enum RecordSetInput: Hashable, Sendable, Encodable {
  case prep(Fields)
  case work(Fields, toFailure: Bool)

  public struct Fields: Hashable, Sendable, Encodable {
    public var date: CalendarDate
    public var workoutTemplateId: String
    public var exerciseId: String
    public var setIndex: Int
    public var weightKg: Double
    public var reps: Int
    public var completed: Bool

    public init(
      date: CalendarDate, workoutTemplateId: String, exerciseId: String, setIndex: Int,
      weightKg: Double, reps: Int, completed: Bool
    ) {
      self.date = date
      self.workoutTemplateId = workoutTemplateId
      self.exerciseId = exerciseId
      self.setIndex = setIndex
      self.weightKg = weightKg
      self.reps = reps
      self.completed = completed
    }
  }

  private enum CodingKeys: String, CodingKey {
    case kind, date, workoutTemplateId, exerciseId, setIndex, weightKg, reps, completed, toFailure
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    let fields: Fields
    switch self {
    case .prep(let value):
      fields = value
      try container.encode("prep", forKey: .kind)
    case .work(let value, let toFailure):
      fields = value
      try container.encode("work", forKey: .kind)
      try container.encode(toFailure, forKey: .toFailure)
    }
    try container.encode(fields.date, forKey: .date)
    try container.encode(fields.workoutTemplateId, forKey: .workoutTemplateId)
    try container.encode(fields.exerciseId, forKey: .exerciseId)
    try container.encode(fields.setIndex, forKey: .setIndex)
    try container.encode(fields.weightKg, forKey: .weightKg)
    try container.encode(fields.reps, forKey: .reps)
    try container.encode(fields.completed, forKey: .completed)
  }
}

public struct AddMeasurementInput: Hashable, Sendable, Encodable {
  public var date: CalendarDate
  public var weightKg: Double
  public var bodyFatPercent: Double?
  public var waistCm: Double?
  public var chestCm: Double?
  public var armCm: Double?
  public var thighCm: Double?

  public init(
    date: CalendarDate, weightKg: Double, bodyFatPercent: Double? = nil, waistCm: Double? = nil,
    chestCm: Double? = nil, armCm: Double? = nil, thighCm: Double? = nil
  ) {
    self.date = date
    self.weightKg = weightKg
    self.bodyFatPercent = bodyFatPercent
    self.waistCm = waistCm
    self.chestCm = chestCm
    self.armCm = armCm
    self.thighCm = thighCm
  }
}

public struct SaveWorkoutInput: Hashable, Sendable, Encodable {
  public var date: CalendarDate
  /// Nulo cria um treino novo. Com id, atualiza esse treino.
  public var workoutTemplateId: String?
  /// Os dias que passam a ser desse treino. Outro treino que tinha algum deles
  /// perde só esses dias.
  public var weekdays: [Int]
  public var name: String
  public var focus: String
  public var estimatedMinutes: Int
  public var exercises: [PlanExercise]

  public init(
    date: CalendarDate, workoutTemplateId: String?, weekdays: [Int], name: String, focus: String,
    estimatedMinutes: Int, exercises: [PlanExercise]
  ) {
    self.date = date
    self.workoutTemplateId = workoutTemplateId
    self.weekdays = weekdays
    self.name = name
    self.focus = focus
    self.estimatedMinutes = estimatedMinutes
    self.exercises = exercises
  }
}

public struct SetStrengthGoalInput: Hashable, Sendable, Encodable {
  public var date: CalendarDate
  public var exerciseId: String
  public var targetValue: Double

  public init(date: CalendarDate, exerciseId: String, targetValue: Double) {
    self.date = date
    self.exerciseId = exerciseId
    self.targetValue = targetValue
  }
}

public struct DateInput: Hashable, Sendable, Encodable {
  public var date: CalendarDate
  public init(date: CalendarDate) { self.date = date }
}

public struct DeleteWorkoutInput: Hashable, Sendable, Encodable {
  public var date: CalendarDate
  public var workoutTemplateId: String

  public init(date: CalendarDate, workoutTemplateId: String) {
    self.date = date
    self.workoutTemplateId = workoutTemplateId
  }
}
