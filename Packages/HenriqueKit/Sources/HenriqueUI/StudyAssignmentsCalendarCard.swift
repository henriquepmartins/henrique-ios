import HenriqueCore
import SwiftUI

/// O calendário da tela de entregas: um mês por vez, com a marca de cada dia.
/// Tocar num dia filtra a lista para ele. Recebe a lista inteira e o relógio
/// do overview, para "atrasada" contar igual na grade e nos cartões.
struct StudyAssignmentsCalendarCard: View {
  @Environment(\.locale) private var locale
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let assignments: [StudyAssignment]
  let now: Date
  @Binding var selectedDay: CalendarDate?
  @State private var month: CalendarDate
  @State private var grid: AssignmentCalendar
  @State private var direction: CGFloat = 1

  init(
    assignments: [StudyAssignment], now: Date, selectedDay: Binding<CalendarDate?>
  ) {
    self.assignments = assignments
    self.now = now
    _selectedDay = selectedDay
    let start = CalendarDate(Date(), in: StudyFormat.calendar)
    _month = State(initialValue: start)
    _grid = State(
      initialValue: AssignmentCalendar(
        month: start, assignments: assignments, now: now,
        calendar: StudyFormat.calendar))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      ZStack {
        StudyMonthGrid(
          grid: grid, today: CalendarDate(Date(), in: StudyFormat.calendar),
          selectedDay: selectedDay
        ) { cell in
          guard cell.date != nil else { return }
          withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
            selectedDay = selectedDay == cell.slot ? nil : cell.slot
          }
        }
        .id(month)
        .transition(
          .asymmetric(
            insertion: .offset(x: 10 * direction).combined(with: .opacity),
            removal: .offset(x: -10 * direction).combined(with: .opacity)))
      }
      .animation(reduceMotion ? nil : .easeOut(duration: 0.26), value: month)
    }
    .padding(16)
    .background(.white, in: .rect(cornerRadius: StudyRadius.card))
    .overlay(RoundedRectangle(cornerRadius: StudyRadius.card).strokeBorder(Color.studyLine))
    .onChange(of: month) { rebuild() }
    .onChange(of: assignments) { rebuild() }
  }

  private var header: some View {
    HStack(spacing: 8) {
      Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Color.studyInk)
        .lineLimit(1).minimumScaleFactor(0.8)
      Spacer(minLength: 4)
      Button("Mês anterior", systemImage: "chevron.left") {
        direction = -1
        month = previousMonth(of: month)
      }
      Button("Próximo mês", systemImage: "chevron.right") {
        direction = 1
        month = nextMonth(of: month)
      }
    }
    .labelStyle(.iconOnly).buttonStyle(.glass).controlSize(.small)
  }

  private var title: String {
    let date = CalendarDate(year: month.year, month: month.month, day: 1)!
      .date(in: StudyFormat.calendar)
    var style = Date.FormatStyle(locale: locale, calendar: StudyFormat.calendar)
    return date.formatted(style.month(.wide).year())
  }

  private func rebuild() {
    grid = AssignmentCalendar(
      month: month, assignments: assignments, now: now,
      calendar: StudyFormat.calendar)
  }

  private func previousMonth(of date: CalendarDate) -> CalendarDate {
    if date.month == 1 { return CalendarDate(year: date.year - 1, month: 12, day: 1)! }
    return CalendarDate(year: date.year, month: date.month - 1, day: 1)!
  }

  private func nextMonth(of date: CalendarDate) -> CalendarDate {
    if date.month == 12 { return CalendarDate(year: date.year + 1, month: 1, day: 1)! }
    return CalendarDate(year: date.year, month: date.month + 1, day: 1)!
  }
}

private struct StudyMonthGrid: View {
  let grid: AssignmentCalendar
  let today: CalendarDate
  let selectedDay: CalendarDate?
  let onTap: (AssignmentCalendar.Cell) -> Void

  private var weekdayInitials: [(weekday: Int, initial: String)] {
    var calendar = StudyFormat.calendar
    calendar.locale = Locale(identifier: "pt_BR")
    let symbols = calendar.shortStandaloneWeekdaySymbols
    let first = calendar.firstWeekday - 1
    return (0..<7).map { weekday in ((first + weekday) % 7, symbols[(first + weekday) % 7]) }
  }

  var body: some View {
    VStack(spacing: 4) {
      HStack(spacing: 4) {
        ForEach(weekdayInitials, id: \.weekday) { _, initial in
          Text(initial).font(.caption2).foregroundStyle(Color.studyInk40)
            .textCase(.lowercase).lineLimit(1).minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
        }
      }
      .accessibilityHidden(true)
      ForEach(grid.weeks) { week in
        HStack(spacing: 4) {
          ForEach(week.cells) { cell in
            StudyDayCell(
              cell: cell, isToday: cell.slot == today,
              isSelected: cell.slot == selectedDay
            )
            .aspectRatio(1, contentMode: .fit).frame(maxWidth: .infinity)
            .onTapGesture { onTap(cell) }
          }
        }
      }
    }
  }
}

private struct StudyDayCell: View {
  let cell: AssignmentCalendar.Cell
  let isToday: Bool
  let isSelected: Bool

  var body: some View {
    if cell.date != nil {
      background
        .overlay { content }
        .overlay {
          if isToday {
            RoundedRectangle(cornerRadius: 9.5)
              .strokeBorder(Color.studyBlue, lineWidth: 1.5)
              .padding(-3)
          }
        }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    } else {
      Color.clear.accessibilityHidden(true)
    }
  }

  @ViewBuilder private var background: some View {
    let shape = RoundedRectangle(cornerRadius: 8)
    if isSelected {
      shape.fill(Color.studyInk)
    } else if let mark = cell.mark {
      if mark.hasOverdue {
        shape.fill(Color.studyCoral.opacity(0.16))
      } else if mark.isComplete {
        shape.fill(Color.studyCoreGreen)
      } else {
        shape.fill(Color.studySky)
      }
    } else {
      shape.fill(Color.black.opacity(0.04))
    }
  }

  private var content: some View {
    VStack(spacing: 1) {
      Text("\(cell.slot.day)")
        .font(.system(size: 10, weight: .medium)).monospacedDigit()
      if let mark = cell.mark {
        Text("\(mark.pending > 0 ? mark.pending : mark.total)")
          .font(.system(size: 8.5, weight: .semibold))
          .lineLimit(1).minimumScaleFactor(0.7).padding(.horizontal, 2)
      }
    }
    .foregroundStyle(textColor)
  }

  private var textColor: Color {
    if isSelected { return .white }
    guard let mark = cell.mark else { return Color.studyInk40 }
    if mark.hasOverdue { return Color(hex: 0xa3200e) }
    if mark.isComplete { return Color(hex: 0x0b6b30) }
    return Color.studyBlue
  }

  private var label: String {
    let day = cell.slot.date(in: StudyFormat.calendar).formatted(
      Date.FormatStyle(locale: Locale(identifier: "pt_BR"), calendar: StudyFormat.calendar)
        .day().month(.wide))
    guard let mark = cell.mark else { return "\(day), sem entregas" }
    let total = mark.total == 1 ? "1 entrega" : "\(mark.total) entregas"
    if mark.hasOverdue { return "\(day), \(total), atrasada" }
    if mark.isComplete { return "\(day), \(total), feitas" }
    return "\(day), \(total)"
  }
}
