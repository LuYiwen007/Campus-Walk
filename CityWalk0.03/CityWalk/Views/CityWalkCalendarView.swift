import SwiftUI

struct CityWalkCalendarView: View {
    let year: Int
    let month: Int
    /// 有 CityWalk 历史的天（1~31）
    let historyDays: [Int]
    /// 当前选中天（可选）
    let selectedDay: Int?
    
    private let weekDays = ["日", "一", "二", "三", "四", "五", "六"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
            }
            .padding(.horizontal)
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
                            if let selected = selectedDay, selected == d {
                                // 当前选中的日期
                                ZStack {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 32, height: 32)
                                    Text("\(d)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            } else if historyDays.contains(d) {
                                // 有CityWalk历史的日期 - 显示太阳图标
                                VStack(spacing: 2) {
                                    Text("🌞")
                                        .font(.system(size: 20))
                                    Text("\(d)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(.label))
                                }
                            } else {
                                // 普通日期 - 只显示数字
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
        let dateComponents = DateComponents(year: year, month: month)
        let date = calendar.date(from: dateComponents)!
        let range = calendar.range(of: .day, in: .month, for: date)!
        let firstWeekday = calendar.component(.weekday, from: date) // 1=周日
        let prefix = Array(repeating: nil as Int?, count: firstWeekday - 1)
        let days = Array(range).map { $0 as Int? }
        return prefix + days
    }
} 