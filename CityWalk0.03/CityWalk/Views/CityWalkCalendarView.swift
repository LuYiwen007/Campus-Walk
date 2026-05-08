import SwiftUI

/// 与原型 JourneyPage 日历区块一致的月视图：行程日浅蓝点、可选按日筛选、今日描边。
struct CityWalkCalendarView: View {
    @Binding var year: Int
    @Binding var month: Int
    /// 在当前 `year`/`month` 中选中的日；`nil` 表示不按日筛选（显示全部行程）
    @Binding var selectedFilterDay: Int?
    /// 落在任意行程日期范围内的「日」（仅用于当前显示的 `year`/`month` 画点）
    let occupiedDaysInMonth: [Int]

    private let weekDays = ["日", "一", "二", "三", "四", "五", "六"]

    private let cal = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(red: 0.45, green: 0.48, blue: 0.52))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }

                Spacer()

                Text("\(year)年\(month)月")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.33))

                Spacer()

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(red: 0.45, green: 0.48, blue: 0.52))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(weekDays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12))
                        .foregroundStyle(CampusWalkUITheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            let days = makeDays()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let d = day {
                        dayCell(day: d)
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerCard, style: .continuous)
                .stroke(CampusWalkUITheme.borderSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func dayCell(day: Int) -> some View {
        let isFilterSelected = selectedFilterDay == day
        let isTodayCell = isToday(year: year, month: month, day: day)
        let hasTrip = occupiedDaysInMonth.contains(day)

        Button {
            if selectedFilterDay == day {
                selectedFilterDay = nil
            } else {
                selectedFilterDay = day
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(cellBackground(isFilterSelected: isFilterSelected, isToday: isTodayCell, hasTrip: hasTrip))
                Text("\(day)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(cellForeground(isFilterSelected: isFilterSelected, isToday: isTodayCell, hasTrip: hasTrip))

                if hasTrip && !isFilterSelected && !isTodayCell {
                    Circle()
                        .fill(CampusWalkUITheme.brandBlue.opacity(0.75))
                        .frame(width: 4, height: 4)
                        .offset(y: 14)
                }
            }
            .aspectRatio(1, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            isTodayCell && !isFilterSelected ? CampusWalkUITheme.brandBlueBorder : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func cellBackground(isFilterSelected: Bool, isToday: Bool, hasTrip: Bool) -> Color {
        if isFilterSelected {
            return CampusWalkUITheme.brandBlue
        }
        if isToday {
            return CampusWalkUITheme.brandBlueMutedBg
        }
        if hasTrip {
            return CampusWalkUITheme.brandBlueMutedBg
        }
        return Color.clear
    }

    private func cellForeground(isFilterSelected: Bool, isToday: Bool, hasTrip: Bool) -> Color {
        if isFilterSelected {
            return .white
        }
        if isToday || hasTrip {
            return CampusWalkUITheme.brandBlue
        }
        return Color(red: 0.28, green: 0.30, blue: 0.33)
    }

    private func isToday(year: Int, month: Int, day: Int) -> Bool {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        guard let date = cal.date(from: c) else { return false }
        return cal.isDateInToday(date)
    }

    private func makeDays() -> [Int?] {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = 1
        guard let date = cal.date(from: c) else { return [] }
        let range = cal.range(of: .day, in: .month, for: date)!
        let firstWeekday = cal.component(.weekday, from: date)
        let prefix = Array(repeating: nil as Int?, count: firstWeekday - 1)
        let days = Array(range).map { $0 as Int? }
        return prefix + days
    }

    private func previousMonth() {
        if month == 1 {
            month = 12
            year -= 1
        } else {
            month -= 1
        }
        selectedFilterDay = nil
    }

    private func nextMonth() {
        if month == 12 {
            month = 1
            year += 1
        } else {
            month += 1
        }
        selectedFilterDay = nil
    }
}
