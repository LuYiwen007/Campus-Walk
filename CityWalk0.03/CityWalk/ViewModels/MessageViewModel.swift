import Foundation
import SwiftUI

@MainActor
class MessageViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var showSegmentedRoute: Bool = false
    @Published var currentConversationId: Int = 0
    
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
        
        // 设置会话创建回调
        qianwenService.onConversationCreated = { [weak self] conversationId in
            DispatchQueue.main.async {
                self?.currentConversationId = conversationId
            }
        }
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
        // 移除越秀公园路线推荐
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
                    } else {
                        // 成功完成，检查是否需要显示分段路线
                        self.checkAndShowSegmentedRoute()
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
    
    // 检查并显示分段路线
    private func checkAndShowSegmentedRoute() {
        // 检查最后一条AI消息是否包含路线推荐
        guard let lastMessage = messages.last,
              !lastMessage.isUser,
              lastMessage.content.contains("路线") else {
            return
        }
        
        // 延迟一点时间让用户看到完整回复，然后显示分段路线选项
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.showSegmentedRoute = true
        }
    }
    
    // 显示分段路线
    func showSegmentedRouteView() {
        showSegmentedRoute = true
    }
    
    // 隐藏分段路线
    func hideSegmentedRouteView() {
        showSegmentedRoute = false
    }
} 
