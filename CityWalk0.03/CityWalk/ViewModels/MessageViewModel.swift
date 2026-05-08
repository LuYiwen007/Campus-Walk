import Foundation
import SwiftUI

@MainActor
class MessageViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var showSegmentedRoute: Bool = false
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
            var rows = try await api.listMessages(conversationId: cid).map { Message(dto: $0) }
            if let batch = try await api.latestRouteBatch(conversationId: cid), !batch.variants.isEmpty {
                if let idx = rows.lastIndex(where: { !$0.isUser && $0.messageType == "route_plan" }) {
                    rows[idx].routeVariants = batch.variants
                }
            }
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
            do {
                let res = try await api.sendMessage(conversationId: cid, content: text)
                let u = Message(dto: res.userMessage)
                let a = Message(dto: res.assistantMessage, routeVariants: res.routeBatch.variants)
                messages.append(u)
                messages.append(a)
                maybeOfferSegmentedRoute()
            } catch {
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

    func sendImageMessage(data: Data) {
        /// 后端暂未实现图片理解，仅作为文字占位提交
        inputText = "[用户发送了一张图片，请根据常见校园步行需求给三条路线建议]"
        sendMessage()
        _ = data
    }

    private func maybeOfferSegmentedRoute() {
        guard let last = messages.last, last.isRouteRecommendation else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.showSegmentedRoute = true
        }
    }

    func showSegmentedRouteView() {
        showSegmentedRoute = true
    }

    func hideSegmentedRouteView() {
        showSegmentedRoute = false
    }
}
