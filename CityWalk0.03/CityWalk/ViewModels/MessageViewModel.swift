import Foundation
import SwiftUI

@MainActor
class MessageViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    
    private let qianwenService: QianwenService
    private var lastBotText: String = ""
    private var currentBotText: String = ""
    private var hasWelcomed: Bool = false // 标记是否已显示欢迎语
    private var hasMocked: Bool = false   // 标记是否已显示mock推荐
    
    init(qianwenService: QianwenService = .shared) {
        self.qianwenService = qianwenService
        // 初次进入只显示欢迎语
        messages = [
            Message(content: "你好，我是你的AI助手，有什么可以帮你的吗？", isUser: false, timestamp: Date())
        ]
        hasWelcomed = true
        hasMocked = false
    }
    
    func sendMessage() {
        print("💬💬💬 sendMessage called with inputText: \(inputText) 💬💬💬")
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            print("⚠️⚠️⚠️ Input text is empty, returning ⚠️⚠️⚠️")
            return 
        }
        let userMessage = Message(content: inputText, isUser: true, timestamp: Date())
        messages.append(userMessage)
        print("📝📝📝 User message added to messages array 📝📝📝")
        let lower = inputText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // 只mock一次推荐
        if !hasMocked && (lower.contains("40分钟的散步") || lower.contains("推荐几条路线") || lower.contains("40分钟") || lower.contains("散步")) {
            let mockReply = Message(content: "当然可以！以下是为你在广州精心挑选的三条适合四十分钟左右散步的路线，每条路线都有不同的风格，适合不同心情和喜好：\n\n⸻\n\n🌿 路线一：越秀山-中山纪念堂文化散步线\n\n适合喜欢历史文化与自然风光的人\n    • 起点：越秀公园东门\n    • 路线：越秀公园 → 五羊雕像 → 镇海楼 → 下山 → 中山纪念堂外环\n    • 终点：中山纪念堂地铁站\n    • 总时长：约40分钟\n    • 亮点：\n    • 青山绿水，风景优美\n    • 可观广州古城墙遗址、镇海楼\n    • 历史文化氛围浓厚\n\n⸻\n\n🏙 路线二：珠江新城滨江夜景线\n\n适合晚上散步，享受城市灯光和江景\n    • 起点：花城广场\n    • 路线：花城广场 → 广州塔方向江边 → 海心沙 → 珠江边亲水平台散步\n    • 终点：猎德桥附近\n    • 总时长：约40分钟\n    • 亮点：\n    • 城市夜景极美，适合拍照\n    • 风大凉爽，适合夏季夜晚\n    • 途经广州塔、IFC、珠江新城灯光带\n\n⸻\n\n🌳 路线三：华南植物园绿意生态线\n\n适合清晨或周末放松身心，远离喧嚣\n    • 起点：华南植物园正门\n    • 路线：棕榈园 → 荷花池 → 竹园 → 热带温室外围步道\n    • 终点：回到正门（环线）\n    • 总时长：约40-50分钟（视步速而定）\n    • 亮点：\n    • 植被丰富，空气清新\n    • 四季花开，适合慢步调\n    • 收费入园（票价约20元）\n\n⸻\n\n你想要选择哪条路线呢？", isUser: false, timestamp: Date(), options: ["路线一：文化散步", "路线二：滨江夜景", "路线三：生态绿意"])
            messages.append(mockReply)
            hasMocked = true
            inputText = ""
            return
        }
        // 之后的对话都走大模型
        let botMessage = Message(content: "", isUser: false, timestamp: Date())
        messages.append(botMessage)
        let userInput = inputText
        DispatchQueue.main.async { self.inputText = "" }
        isLoading = true
        lastBotText = ""
        currentBotText = ""
        print("🤖🤖🤖 Calling qianwenService.streamMessage with: \(userInput) 🤖🤖🤖")
        qianwenService.streamMessage(
            query: userInput,
            onReceive: { [weak self] text in
                print("📨📨📨 onReceive called with text: \(text) 📨📨📨")
                Task { @MainActor in
                    guard let self = self else { return }
                    self.currentBotText += text
                    if let lastMessage = self.messages.last {
                        var updatedMessage = lastMessage
                        updatedMessage.content = self.currentBotText
                        if let index = self.messages.lastIndex(where: { $0.id == lastMessage.id }) {
                            self.messages[index] = updatedMessage
                        }
                    }
                    // 新增：流式输出时通知界面滚动到底部
                    if let lastMessage = self.messages.last {
                        NotificationCenter.default.post(name: NSNotification.Name("StreamScrollToBottom"), object: lastMessage.id)
                    }
                }
            },
            onComplete: { [weak self] error in
                print("🏁🏁🏁 sendMessage onComplete called with error: \(String(describing: error)) 🏁🏁🏁")
                Task { @MainActor in
                    guard let self = self else { return }
                    self.isLoading = false
                    self.lastBotText = ""
                    self.currentBotText = ""
                    if let error = error {
                        let errorMessage: String
                        switch error {
                        case QianwenError.invalidURL:
                            errorMessage = "无效的服务器地址"
                        case QianwenError.networkError(let underlyingError):
                            errorMessage = "网络错误: \(underlyingError.localizedDescription)"
                        case QianwenError.invalidResponse:
                            errorMessage = "服务器响应无效"
                        case QianwenError.unauthorized:
                            errorMessage = "API密钥无效或已过期"
                        case QianwenError.unknown:
                            errorMessage = "未知错误"
                        default:
                            errorMessage = "发生错误: \(error.localizedDescription)"
                        }
                        let errorMsg = Message(content: errorMessage, isUser: false, timestamp: Date())
                        self.messages.append(errorMsg)
                    }
                }
            }
        )
    }
    
    func sendImageMessage(data: Data) {
        // 1. 先将图片以base64编码
        let base64String = data.base64EncodedString()
        // 2. 构造图片消息内容（可根据大模型API要求调整）
        let imagePrompt = "[图片]" // 可自定义提示词
        let userMessage = Message(content: imagePrompt, isUser: true, timestamp: Date(), imageData: data)
        messages.append(userMessage)
        let botMessage = Message(content: "", isUser: false, timestamp: Date())
        messages.append(botMessage)
        isLoading = true
        lastBotText = ""
        currentBotText = ""
        // 3. 发送图片base64字符串给大模型（如API支持图片，可直接传递base64，否则可自定义协议）
        qianwenService.streamMessage(
            query: "用户发送了一张图片，base64内容如下：\n" + base64String,
            onReceive: { [weak self] text in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.currentBotText += text
                    if let lastMessage = self.messages.last {
                        var updatedMessage = lastMessage
                        updatedMessage.content = self.currentBotText
                        if let index = self.messages.lastIndex(where: { $0.id == lastMessage.id }) {
                            self.messages[index] = updatedMessage
                        }
                    }
                }
            },
            onComplete: { [weak self] error in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.isLoading = false
                    self.lastBotText = ""
                    self.currentBotText = ""
                    if let error = error {
                        let errorMessage: String
                        switch error {
                        case QianwenError.invalidURL:
                            errorMessage = "无效的服务器地址"
                        case QianwenError.networkError(let underlyingError):
                            errorMessage = "网络错误: \(underlyingError.localizedDescription)"
                        case QianwenError.invalidResponse:
                            errorMessage = "服务器响应无效"
                        case QianwenError.unauthorized:
                            errorMessage = "API密钥无效或已过期"
                        case QianwenError.unknown:
                            errorMessage = "未知错误"
                        default:
                            errorMessage = "发生错误: \(error.localizedDescription)"
                        }
                        let errorMsg = Message(content: errorMessage, isUser: false, timestamp: Date())
                        self.messages.append(errorMsg)
                    }
                }
            }
        )
    }
} 
