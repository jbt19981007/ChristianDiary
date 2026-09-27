import SwiftUI
import DevotionCore

/// 月历：标出写过灵修的日子，点选某一天筛选笔记。
struct MonthCalendarView: View {
    @Binding var month: YearMonth
    @Binding var selectedDay: DayKey?
    let markedDays: Set<DayKey>
    let today: DayKey

    @Environment(\.appLanguage) private var lang

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var weekdaySymbols: [String] {
        lang == .chinese ? ["日", "一", "二", "三", "四", "五", "六"] : ["S", "M", "T", "W", "T", "F", "S"]
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    withAnimation { month = month.adding(months: -1) }
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel(lang.pick("上个月", "Previous month"))

                Spacer()
                VStack(spacing: 2) {
                    Text(month.formatted(lang))
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text(lang.pick("本月灵修 \(DevotionStats.count(days: markedDays, in: month)) 天",
                                   "\(DevotionStats.count(days: markedDays, in: month)) days this month"))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer()

                Button {
                    withAnimation { month = month.adding(months: 1) }
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 36)
                }
                .disabled(month >= today.yearMonth)
                .accessibilityLabel(lang.pick("下个月", "Next month"))
            }
            .buttonStyle(.borderless)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(index == 0 ? Theme.accent : Theme.inkSecondary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(Array(month.calendarGrid.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }

            if month != today.yearMonth {
                Button(lang.pick("回到本月", "This month")) {
                    withAnimation { month = today.yearMonth }
                }
                .font(.footnote)
                .buttonStyle(.borderless)
            }
        }
    }

    private func dayCell(_ day: DayKey) -> some View {
        let isSelected = selectedDay == day
        let isToday = day == today
        let hasNote = markedDays.contains(day)
        let isFuture = day > today
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedDay = isSelected ? nil : day
            }
        } label: {
            VStack(spacing: 2) {
                Text(String(day.day))
                    .font(.subheadline.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.white : (isFuture ? Theme.inkSecondary.opacity(0.5) : Theme.ink))
                Circle()
                    .fill(isSelected ? Color.white : Theme.accent)
                    .frame(width: 5, height: 5)
                    .opacity(hasNote ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.accent)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.accent, lineWidth: 1.2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(day.formatted(lang) + (hasNote ? lang.pick("，有灵修", ", has entries") : ""))
    }
}
