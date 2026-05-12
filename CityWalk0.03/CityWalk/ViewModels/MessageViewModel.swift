import Foundation
import SwiftUI

@MainActor
class MessageViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    /// 当前会话 ID（后端）
    @Published var conversationId: Int?

    var currentConversationId: Int { conversationId ?? 0 }

    private let api = APIClient.shared

    func bootstrapConversation() async {
        guard conversationId == nil else {
            await loadMessages()
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let created = try await api.createConversation(title: "新对话")
            conversationId = created.conversation.id
            await loadMessages()
        } catch {
            messages = [
                Message(
                    id: "local-error",
                    content: "无法创建会话：\(error.localizedDescription)",
                    isUser: false,
                    timestamp: Date()
                )
            ]
        }
    }

    func loadMessages() async {
        guard let cid = conversationId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            // 路线卡片数据以每条消息的 route_batch 为准（后端 messageToVo 已嵌入），不再用 latestRouteBatch 客户端拼接，避免误挂批次
            let rows = try await api.listMessages(conversationId: cid).map { Message(dto: $0) }
            messages = rows
        } catch {
            messages.append(
                Message(
                    id: "load-err-\(UUID().uuidString)",
                    content: "加载消息失败：\(error.localizedDescription)",
                    isUser: false,
                    timestamp: Date()
                )
            )
        }
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let cid = conversationId else { return }
        inputText = ""
        isLoading = true
        Task {
            defer { isLoading = false }
            await appendSendResult(conversationId: cid, content: text, imageJPEGData: nil)
        }
    }

    func sendImageMessage(data: Data) {
        let caption = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        guard let cid = conversationId else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            await appendSendResult(conversationId: cid, content: caption, imageJPEGData: data)
        }
    }

    private func appendSendResult(conversationId cid: Int, content: String, imageJPEGData: Data?) async {
        let insertAt = messages.count
        let tempAsstId = "stream-\(UUID().uuidString)"
        do {
            let res = try await api.sendMessageStream(
                conversationId: cid,
                content: content,
                imageJPEGData: imageJPEGData,
                onUserMessage: { [weak self] dto in
                    guard let self else { return }
                    var m = Message(dto: dto)
                    if let img = imageJPEGData { m.imageData = img }
                    self.messages.append(m)
                },
                onRouteBatch: { [weak self] batch in
                    guard let self else { return }
                    self.messages.append(
                        Message(
                            id: tempAsstId,
                            content: "",
                            isUser: false,
                            timestamp: Date(),
                            messageType: "route_plan",
                            routeVariants: batch.variants,
                            imageData: nil,
                            hasImageFromServer: false
                        )
                    )
                },
                onTextDelta: { [weak self] piece in
                    guard let self else { return }
                    guard let idx = self.messages.firstIndex(where: { $0.id == tempAsstId }) else { return }
                    self.messages[idx].content += piece
                }
            )
            if let userDto = res.userMessage, insertAt < messages.count, messages[insertAt].isUser {
                var um = Message(dto: userDto)
                if let img = imageJPEGData { um.imageData = img }
                messages[insertAt] = um
            }
            if let idx = messages.firstIndex(where: { $0.id == tempAsstId }) {
                let merged = res.routeBatch?.variants ?? res.assistantMessage.routeBatch?.variants
                messages[idx] = Message(dto: res.assistantMessage, routeVariants: merged)
            } else {
                let merged = res.routeBatch?.variants ?? res.assistantMessage.routeBatch?.variants
                messages.append(Message(dto: res.assistantMessage, routeVariants: merged))
            }
        } catch {
            if messages.count > insertAt {
                messages.removeSubrange(insertAt...)
            }
            messages.append(
                Message(
                    id: "err-\(UUID().uuidString)",
                    content: "发送失败：\(error.localizedDescription)",
                    isUser: false,
                    timestamp: Date()
                )
            )
        }
    }

}
