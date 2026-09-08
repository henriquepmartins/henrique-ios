import HenriqueCore
import SwiftUI

/// A semana em volta do dia escolhido. O toque troca o dia e o painel inteiro
/// vem de novo do servidor.
struct DayStrip: View {
  @Environment(AcademiaStore.self) private var store
  let selected: CalendarDate

  private var days: [CalendarDate] {
    (-3...3).map { selected.adding(days: $0) }
  }

  var body: some View {
    GlassEffectContainer(spacing: 8) {
      HStack(spacing: 8) {
        ForEach(days, id: \.self) { day in
          DayChip(day: day, isSelected: day == selected, isToday: day == .today) {
            Task { await store.select(date: day) }
          }
        }
      }
    }
  }
}

struct DayChip: View {
  @Environment(\.accent) private var accent
  let day: CalendarDate
  let isSelected: Bool
  let isToday: Bool
  let onTap: () -> Void

  private static let weekdayFormat = Date.FormatStyle.dateTime.weekday(.narrow)

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 3) {
        Text(day.date(), format: Self.weekdayFormat)
          .font(.caption2)
          .textCase(.uppercase)
        Text("\(day.day)")
          .font(.subheadline.weight(isSelected ? .bold : .regular))
          .monospacedDigit()
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 9)
      .foregroundStyle(isSelected ? .white : (isToday ? accent.base : .primary))
    }
    .buttonStyle(.plain)
    .glassEffect(
      isSelected ? .regular.tint(accent.base).interactive() : .regular.interactive(),
      in: .rect(cornerRadius: 16))
    .accessibilityLabel(Text(day.date(), format: .dateTime.weekday(.wide).day().month(.wide)))
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }
}
