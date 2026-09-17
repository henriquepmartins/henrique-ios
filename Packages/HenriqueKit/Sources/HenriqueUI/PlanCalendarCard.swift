import HenriqueCore
import SwiftUI

/// O calendário da tela "plano": por dia, qual treino foi feito e qual o plano
/// pede. Recebe a frequência e o plano já carregados e pede o intervalo do mês
/// visível a quem tem o servidor; assim o preview roda com dados fabricados.
struct PlanCalendarCard: View {
  @Environment(\.locale) private var locale
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var period: AttendancePeriod = .month(containing: .today)
  @State private var calendarGrid: PlanCalendar
  let attendance: [CalendarDate: AttendanceDay]
  let weekPlan: [WeekPlanItem]
  let load: (CalendarDate, CalendarDate) async -> Void

  init(
    attendance: [CalendarDate: AttendanceDay], weekPlan: [WeekPlanItem],
    load: @escaping (CalendarDate, CalendarDate) async -> Void
  ) {
    self.attendance = attendance
    self.weekPlan = weekPlan
    self.load = load
    _calendarGrid = State(
      initialValue: PlanCalendar(period: .month(containing: .today), attendance: attendance, weekPlan: weekPlan))
  }

  private var workoutsById: [String: WeekPlanItem] {
    Dictionary(weekPlan.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
  }

  private var nextIsFuture: Bool {
    period.next.range().lowerBound > .today
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      header
      ZStack {
        // Um mês é uma peça só, e o mês seguinte tem a mesma forma. Deslizar
        // uma grade 10pt por cima da outra deixava as duas legíveis ao mesmo
        // tempo, com os números de dois meses sobrepostos. `blurReplace` é a
        // troca que o sistema usa para conteúdo que muda no lugar.
        PlanMonthGrid(grid: calendarGrid, workoutsById: workoutsById)
          // A frequência chega depois da rede, e sem isto as casas saltavam do
          // cinza para a cor do treino no quadro em que a resposta volta. Fica
          // dentro do `id` de propósito: mês novo é view nova, não tem cor
          // velha para atravessar.
          .animation(reduceMotion ? nil : Motion.crossfade, value: calendarGrid)
          .id(period)
          .transition(.blurReplace)
      }
      .animation(reduceMotion ? nil : Motion.tap, value: period)
      PlanLegend()
    }
    .padding(18).paperCard(radius: 28)
    .onChange(of: period) { rebuild() }
    .onChange(of: attendance, initial: true) { rebuild() }
    .onChange(of: weekPlan) { rebuild() }
    .task(id: period) {
      let range = period.range()
      await load(range.lowerBound, range.upperBound)
    }
  }

  private var header: some View {
    HStack(spacing: 8) {
      Text(period.title(locale: locale)).font(.subheadline).foregroundStyle(Color.ink)
        .lineLimit(1).minimumScaleFactor(0.8)
      Spacer(minLength: 4)
      Button("Mês anterior", systemImage: "chevron.left") { period = period.previous }
      Button("Próximo mês", systemImage: "chevron.right") { period = period.next }
      .disabled(nextIsFuture)
    }
    .labelStyle(.iconOnly).buttonStyle(.glass).controlSize(.small)
  }

  private func rebuild() {
    calendarGrid = PlanCalendar(period: period, attendance: attendance, weekPlan: weekPlan)
  }
}

private struct PlanMonthGrid: View {
  @Environment(\.locale) private var locale
  let grid: PlanCalendar
  let workoutsById: [String: WeekPlanItem]

  private var weekdayInitials: [(weekday: Int, initial: String)] {
    var calendar = Calendar.autoupdatingCurrent
    calendar.locale = locale
    let symbols = calendar.shortStandaloneWeekdaySymbols
    let first = calendar.firstWeekday - 1
    return (0..<7).map { weekday in ((first + weekday) % 7, symbols[(first + weekday) % 7]) }
  }

  var body: some View {
    VStack(spacing: 4) {
      HStack(spacing: 4) {
        ForEach(weekdayInitials, id: \.weekday) { _, initial in
          Text(initial).font(.caption2).foregroundStyle(Color.mutedInk)
            .textCase(.lowercase).lineLimit(1).minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
        }
      }
      .accessibilityHidden(true)
      ForEach(grid.weeks) { week in
        HStack(spacing: 4) {
          ForEach(week.cells) { cell in
            DayCell(cell: cell, workoutsById: workoutsById)
              .aspectRatio(1, contentMode: .fit).frame(maxWidth: .infinity)
          }
        }
      }
    }
  }
}

private struct DayCell: View {
  @Environment(\.locale) private var locale
  let cell: PlanCalendar.Cell
  let workoutsById: [String: WeekPlanItem]
  private let radius: CGFloat = 8

  private var workout: WeekPlanItem? {
    switch cell.mark {
    case .none: nil
    case .done(let ids):
      // Id desconhecido (treino apagado) ou feito sem treino conhecido: o
      // palpite é o treino que o plano pede nesse weekday, para o feito sair
      // na cor sólida do folder em vez de cinza.
      ids.first.flatMap { workoutsById[$0] }
        ?? workoutsById.values.first { $0.weekdays.contains(cell.slot.weekday()) }
    case .planned(let id), .missed(let id): workoutsById[id]
    }
  }

  var body: some View {
    if let date = cell.date {
      background
        .overlay { content }
        .overlay {
          if cell.isToday {
            RoundedRectangle(cornerRadius: radius + 1.5)
              .strokeBorder(Color.ink, lineWidth: 1.5)
              .padding(-3)
          }
        }
        .accessibilityElement()
        .accessibilityLabel(label(for: date))
    } else {
      Color.clear.accessibilityHidden(true)
    }
  }

  @ViewBuilder private var background: some View {
    let shape = RoundedRectangle(cornerRadius: radius)
    switch cell.mark {
    case .none:
      shape.fill(Color.ink.opacity(0.04))
    case .done:
      shape.fill(workout?.tone.top ?? Color.ink.opacity(0.18))
    case .planned:
      let tone = workout?.tone.top ?? Color.mutedInk
      shape.fill(.white)
        .overlay { Hachura().stroke(tone.opacity(0.45), lineWidth: 1).clipShape(.rect(cornerRadius: radius)) }
        .overlay { shape.strokeBorder(tone, lineWidth: 1.5) }
    case .missed:
      let tone = workout?.tone.top ?? Color.mutedInk
      shape.fill(.white)
        .overlay { shape.strokeBorder(tone.opacity(0.28), lineWidth: 1.5) }
    }
  }

  private var content: some View {
    VStack(spacing: 1) {
      Text("\(cell.slot.day)").font(.system(size: 10, weight: .medium)).monospacedDigit()
      if let word = workout?.name.split(separator: " ").first {
        Text(word.lowercased()).font(.system(size: 8.5, weight: .semibold))
          .lineLimit(1).minimumScaleFactor(0.7).padding(.horizontal, 2)
      }
    }
    .foregroundStyle(textColor)
  }

  private var textColor: Color {
    switch cell.mark {
    case .none: Color.mutedInk
    case .done: workout?.tone.ink ?? Color.ink.opacity(0.5)
    case .planned: workout?.tone.ink ?? Color.mutedInk
    case .missed: Color.mutedInk.opacity(0.6)
    }
  }

  private func label(for date: CalendarDate) -> String {
    let day = date.date().formatted(Date.FormatStyle(locale: locale).day().month(.wide))
    switch cell.mark {
    case .none: return "\(day), sem treino"
    case .done: return "\(day), feito" + (workout.map { ", \($0.name)" } ?? "")
    case .planned: return "\(day), planejado" + (workout.map { ", \($0.name)" } ?? "")
    case .missed: return "\(day), planejado, não treinou"
    }
  }
}

private struct Hachura: Shape {
  var espaco: CGFloat = 5

  func path(in rect: CGRect) -> Path {
    var path = Path()
    var x = -rect.height
    while x < rect.width {
      path.move(to: CGPoint(x: x, y: rect.maxY))
      path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
      x += espaco
    }
    return path
  }
}

private struct PlanLegend: View {
  private let side: CGFloat = 11
  private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 3) }

  var body: some View {
    HStack(spacing: 4) {
      shape.fill(Color.mutedInk).frame(width: side, height: side)
      Text("feito")
      shape.fill(.white)
        .overlay { Hachura(espaco: 3).stroke(Color.mutedInk.opacity(0.45), lineWidth: 1).clipShape(.rect(cornerRadius: 3)) }
        .overlay { shape.strokeBorder(Color.mutedInk, lineWidth: 1) }
        .frame(width: side, height: side)
        .padding(.leading, 6)
      Text("planejado")
      shape.strokeBorder(Color.mutedInk.opacity(0.28), lineWidth: 1)
        .frame(width: side, height: side)
        .padding(.leading, 6)
      Text("furou")
    }
    .font(.caption2).foregroundStyle(Color.mutedInk)
    .frame(maxWidth: .infinity, alignment: .trailing)
    .accessibilityHidden(true)
  }
}

#if DEBUG
  #Preview("Calendário do plano") {
    ScrollView {
      PlanCalendarCard(attendance: PlanCalendarPreview.attendance, weekPlan: PlanCalendarPreview.plan) { _, _ in }
        .padding(16)
    }
    .background(Color.canvas)
    .environment(\.locale, Locale(identifier: "pt_BR"))
  }

  enum PlanCalendarPreview {
    /// Peito na segunda, costas na terça, perna na quinta, ombro no sábado.
    static let plan: [WeekPlanItem] = {
      let tones = WorkoutTone.all
      let json = """
        [
          {"id": "peito", "weekdays": [1], "name": "peito e tríceps", "focus": "", "exerciseCount": 0,
           "exercises": [], "estimatedMinutes": 50, "color": "\(tones[0].hex)"},
          {"id": "costas", "weekdays": [2], "name": "costas e bíceps", "focus": "", "exerciseCount": 0,
           "exercises": [], "estimatedMinutes": 50, "color": "\(tones[1].hex)"},
          {"id": "perna", "weekdays": [4], "name": "perna", "focus": "", "exerciseCount": 0,
           "exercises": [], "estimatedMinutes": 60, "color": "\(tones[4].hex)"},
          {"id": "ombro", "weekdays": [6], "name": "ombro e abdômen", "focus": "", "exerciseCount": 0,
           "exercises": [], "estimatedMinutes": 40, "color": "\(tones[2].hex)"}
        ]
        """
      return try! JSONDecoder.henrique().decode([WeekPlanItem].self, from: Data(json.utf8))
    }()

    static var attendance: [CalendarDate: AttendanceDay] {
      let today = CalendarDate.today
      var days: [CalendarDate: AttendanceDay] = [:]
      for back in 1..<60 {
        let date = today.adding(days: -back)
        guard let item = plan.first(where: { $0.weekdays.contains(date.weekday()) }) else { continue }
        // A cada nove dias o treino ficou por fazer; o de 40 dias atrás veio de
        // um servidor que ainda não dizia qual treino foi.
        if back % 9 == 0 { continue }
        let ids = back == 40 ? [] : [item.id]
        days[date] = AttendanceDay(date: date, workSets: 12, completed: true, workoutTemplateIds: ids)
      }
      return days
    }
  }
#endif
