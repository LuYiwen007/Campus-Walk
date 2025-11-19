import SwiftUI

// 聊天气泡视图，负责渲染单条消息内容和时间
struct MessageBubble: View {
    let message: Message
    let userAvatar: Image
    @ObservedObject var viewModel: MessageViewModel
    let onOptionClick: (String) -> Void
    
    @Environment(\.fontSize) var fontSize
    @Environment(\.language) var language
    
    // 格式化时间显示，支持今天、昨天、周几、日期等多种格式
    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
        let nowComponents = calendar.dateComponents([.year, .month, .day], from: now)
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: date)
        
        // 如果是今天
        if calendar.isDateInToday(date) {
            return timeString
        }
        
        // 如果是昨天
        if calendar.isDateInYesterday(date) {
            return (language == "简体中文" ? "昨天 " : "Yesterday ") + timeString
        }
        
        // 计算日期差
        let dayDiff = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        
        // 如果在一周内
        if dayDiff < 7 {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.locale = Locale(identifier: language == "简体中文" ? "zh_CN" : "en_US")
            weekdayFormatter.dateFormat = "EEEE"
            return weekdayFormatter.string(from: date) + " " + timeString
        }
        
        // 其他情况显示年月
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: language == "简体中文" ? "zh_CN" : "en_US")
        
        // 如果是今年
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
                Text(message.content)
                    .font(.system(size: fontSize))
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
    
    // 渲染单条消息气泡及时间
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
                Image(systemName: "sparkles") // AI助手头像
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
        
        if !message.isUser, let options = message.options {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        onOptionClick(option)
                    }) {
                        Text(option)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.top, 8)
            .padding(.leading, 40 + 12) // 头像宽度加间距
            .padding(.trailing, 12)
        }
    }
} 