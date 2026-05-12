import SwiftUI

// 聊天气泡视图，负责渲染单条消息内容和时间
struct MessageBubble: View {
    let message: Message
    let userAvatar: Image
    @ObservedObject var viewModel: MessageViewModel
    let onRouteSelected: (RouteVariantDTO) -> Void

    @Environment(\.fontSize) var fontSize
    @Environment(\.language) var language

    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
        let nowComponents = calendar.dateComponents([.year, .month, .day], from: now)

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return timeString
        }

        if calendar.isDateInYesterday(date) {
            return (language == "简体中文" ? "昨天 " : "Yesterday ") + timeString
        }

        let dayDiff = calendar.dateComponents([.day], from: date, to: now).day ?? 0

        if dayDiff < 7 {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.locale = Locale(identifier: language == "简体中文" ? "zh_CN" : "en_US")
            weekdayFormatter.dateFormat = "EEEE"
            return weekdayFormatter.string(from: date) + " " + timeString
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: language == "简体中文" ? "zh_CN" : "en_US")

        if components.year == nowComponents.year {
            dateFormatter.dateFormat = language == "简体中文" ? "M月d日" : "MMM d"
        } else {
            dateFormatter.dateFormat = language == "简体中文" ? "yyyy年M月d日" : "MMM d, yyyy"
        }

        return dateFormatter.string(from: date) + " " + timeString
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if let data = message.imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 240)
                .cornerRadius(18)
                .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        } else {
            if message.isUser {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if message.hasImageFromServer || message.imageData != nil {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: fontSize * 0.85))
                            .foregroundColor(.white.opacity(0.95))
                    }
                    Text(message.content)
                        .font(.system(size: fontSize))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.blue]), startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .foregroundColor(.white)
                .cornerRadius(18, corners: [.topLeft, .topRight, .bottomLeft])
                .shadow(color: .blue.opacity(0.2), radius: 5, y: 2)
            } else {
                Text(message.content)
                    .font(.system(size: fontSize))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .foregroundColor(.primary)
                    .cornerRadius(18, corners: [.topLeft, .topRight, .bottomRight])
                    .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
                    .overlay(
                        RoundedCorner(radius: 18, corners: [.topLeft, .topRight, .bottomRight])
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    bubbleContent
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                userAvatar
                    .resizable()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundColor(.purple)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.purple.opacity(0.1)))

                VStack(alignment: .leading, spacing: 4) {
                    bubbleContent
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
        }

        if !message.isUser, let variants = message.routeVariants, !variants.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("可选路线")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)
                VStack(spacing: 0) {
                    ForEach(Array(variants.enumerated()), id: \.element.id) { idx, v in
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(v.displayLabel)
                                    .font(.subheadline.weight(.bold))
                                Text("\(v.startLabel) → \(v.endLabel)")
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                Text("约 \(v.estimatedDurationSeconds / 60) 分钟 · \(v.estimatedDistanceMeters) m")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                let samples = Array(v.scenicSpotExamples.prefix(3))
                                if !samples.isEmpty {
                                    Text("途经：\(samples.joined(separator: "、"))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Button("确认") {
                                onRouteSelected(v)
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        if idx < variants.count - 1 {
                            Divider().padding(.leading, 8)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )
            }
            .padding(.top, 10)
            .padding(.leading, 40 + 12)
            .padding(.trailing, 12)
        }
    }
}
