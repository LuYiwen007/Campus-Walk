import SwiftUI
import CoreLocation

struct TripStatsView: View {
    // 轨迹坐标
    var routeCoordinates: [CLLocationCoordinate2D] = []
    // 统计数据
    var duration: TimeInterval = 3600 // 秒
    var distance: Double = 5.2 // 公里
    var calories: Double = 320 // 千卡
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 上部地图
                AMapViewRepresentable(startCoordinate: nil, destination: nil, showSearchBar: false)
                    .frame(height: geometry.size.height * 0.45)
                    .clipped()
                // 下部统计信息
                VStack(spacing: 24) {
                    Text("旅程统计")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top, 24)
                    HStack(spacing: 32) {
                        VStack {
                            Text("用时")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(timeString)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        VStack {
                            Text("路程")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f km", distance))
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        VStack {
                            Text("卡路里")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.0f kcal", calories))
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                    // Spacer()
                    // 心率卡片样式
                    HeartRateCardView()
                        .padding(.top, 5)

                }
                .frame(maxWidth: .infinity)
                .background(Color.white)
            }
            .edgesIgnoringSafeArea(.top)
            .overlay(
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .padding()
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                .padding(.leading, 16)
                .padding(.top, 40)
                , alignment: .topLeading
            )
        }
    }
    // 用时格式化
    var timeString: String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        let s = Int(duration) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}

// 新增：心率卡片组件
struct HeartRateCardView: View {
    // mock 数据
    let heartRates: [Int] = [55, 58, 60, 62, 65, 64, 61, 59]
    let current: Int = 59
    let status: String = "正常"
    let statusColor: Color = .green
    let diff: Int = -3

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.pink)
                        .font(.title3)
                    Text("运动心率")
                        .font(.headline)
                        .foregroundColor(Color(.label))
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(current)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Color(.label))
                    Text("bpm")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(statusColor)
                        .font(.subheadline)
                    Text(status)
                        .foregroundColor(statusColor)
                        .font(.subheadline)
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .foregroundColor(.purple)
                        .font(.subheadline)
                    Text("\(diff) bpm 和昨天比较")
                        .foregroundColor(.purple)
                        .font(.subheadline)
                }
            }
            Spacer()
            HeartRateMiniChart(heartRates: heartRates)
                .frame(width: 120, height: 60)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color(.black).opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

struct HeartRateMiniChart: View {
    let heartRates: [Int]
    var body: some View {
        GeometryReader { geo in
            let maxRate = (heartRates.max() ?? 120)
            let minRate = (heartRates.min() ?? 60)
            let points = heartRates.enumerated().map { (i, rate) in
                CGPoint(
                    x: geo.size.width * CGFloat(i) / CGFloat(max(heartRates.count - 1, 1)),
                    y: geo.size.height * (1 - CGFloat(rate - minRate) / CGFloat(maxRate - minRate == 0 ? 1 : maxRate - minRate))
                )
            }
            // 背景带透明色
            if let first = points.first, let last = points.last {
                Path { path in
                    path.move(to: CGPoint(x: first.x, y: geo.size.height * 0.7))
                    for pt in points {
                        path.addLine(to: pt)
                    }
                    path.addLine(to: CGPoint(x: last.x, y: geo.size.height * 0.7))
                    path.closeSubpath()
                }
                .fill(Color.red.opacity(0.12))
            }
            // 折线
            Path { path in
                if let first = points.first {
                    path.move(to: first)
                    for pt in points.dropFirst() {
                        path.addLine(to: pt)
                    }
                }
            }
            .stroke(Color.red, lineWidth: 2)
            // 圆点
            ForEach(points.indices, id: \.self) { i in
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.red, lineWidth: 3)
                    )
                    .position(points[i])
            }
        }
    }
}

// 预览
struct TripStatsView_Previews: PreviewProvider {
    static var previews: some View {
        TripStatsView()
    }
} 