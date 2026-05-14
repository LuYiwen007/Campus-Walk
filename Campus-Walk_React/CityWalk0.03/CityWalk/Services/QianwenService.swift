import Foundation

/// 历史遗留占位：对话与路线已迁移到后端 `POST /api/v1/conversations/.../messages`。
/// 请勿在本文件存放任何 API 密钥；大模型调用在服务端完成。
enum QianwenServiceDeprecated {
    static let note = "请使用 APIClient + MessageViewModel"
}
