import SwiftUI

struct CityWalkCalendarView: View {
    @State private var currentYear: Int
    @State private var currentMonth: Int
    /// 当前选中天（可选）
    let selectedDay: Int?
    
    private let weekDays = ["日", "一", "二", "三", "四", "五", "六"]
    
    init(year: Int, month: Int, historyDays: [Int], selectedDay: Int?) {
        self._currentYear = State(initialValue: year)
        self._currentMonth = State(initialValue: month)
        self.selectedDay = selectedDay
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 年月标题和月份切换按钮
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text("\(currentYear)年\(currentMonth)月")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            // 周几标题
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                ForEach(weekDays, id: \.self) { day in
                    Text(day)
                        .font(.subheadline)
                        .foregroundColor(Color(.label))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            // 日历主体
            let days = makeDays()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                ForEach(Array(days.enumerated()), id: \.0) { index, day in
                    if let d = day {
                        VStack(spacing: 4) {
                            if let selected = selectedDay, selected == d, isCurrentMonth() {
                                // 当前选中的日期（仅在当前月份显示）
                                ZStack {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 32, height: 32)
                                    Text("\(d)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            } else {
                                // 所有其他日期 - 统一显示数字
                                Text("\(d)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(.label))
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(Color.clear)
                                    )
                            }
                        }
                        .frame(height: 50)
                    } else {
                        Color.clear.frame(height: 50)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(22)
        .shadow(color: Color(.black).opacity(0.06), radius: 8, x: 0, y: 2)
        .padding()
    }
    
    /// 生成日历天数（前面补空）
    private func makeDays() -> [Int?] {
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: currentYear, month: currentMonth)
        let date = calendar.date(from: dateComponents)!
        let range = calendar.range(of: .day, in: .month, for: date)!
        let firstWeekday = calendar.component(.weekday, from: date) // 1=周日
        let prefix = Array(repeating: nil as Int?, count: firstWeekday - 1)
        let days = Array(range).map { $0 as Int? }
        return prefix + days
    }
    
    /// 切换到上一月
    private func previousMonth() {
        if currentMonth == 1 {
            currentMonth = 12
            currentYear -= 1
        } else {
            currentMonth -= 1
        }
    }
    
    /// 切换到下一月
    private func nextMonth() {
        if currentMonth == 12 {
            currentMonth = 1
            currentYear += 1
        } else {
            currentMonth += 1
        }
    }
    
    /// 判断是否为当前月份
    private func isCurrentMonth() -> Bool {
        let now = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        return currentYear == self.currentYear && currentMonth == self.currentMonth
    }
} 