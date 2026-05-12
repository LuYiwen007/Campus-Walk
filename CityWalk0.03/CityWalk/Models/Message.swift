import Foundation

struct Message: Identifiable, Equatable {
    let id: String
    var content: String
    let isUser: Bool
    let timestamp: Date
    /// 后端 message_type：text / route_plan 等
    var messageType: String?
    /// 路线一、二、三（来自后端 route_batch）
    var routeVariants: [RouteVariantDTO]? = nil
    var imageData: Data?
    /// 后端标记该条用户消息是否带图（模型已按图规划）
    var hasImageFromServer: Bool = false

    var isRouteRecommendation: Bool {
        routeVariants != nil && !(routeVariants?.isEmpty ?? true)
    }

    init(
        id: String,
        content: String,
        isUser: Bool,
        timestamp: Date,
        messageType: String? = nil,
        routeVariants: [RouteVariantDTO]? = nil,
        imageData: Data? = nil,
        hasImageFromServer: Bool = false
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.messageType = messageType
        self.routeVariants = routeVariants
        self.imageData = imageData
        self.hasImageFromServer = hasImageFromServer
    }

    private static func parseApiDate(_ s: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s) ?? Date()
    }

    init(dto: ChatMessageDTO) {
        id = "\(dto.id)"
        content = dto.content
        isUser = dto.role == "user"
        timestamp = Self.parseApiDate(dto.sentAt ?? "")
        messageType = dto.messageType
        routeVariants = dto.routeBatch?.variants
        imageData = nil
        hasImageFromServer = dto.hasImage ?? false
    }

    init(dto: ChatMessageDTO, routeVariants: [RouteVariantDTO]?) {
        id = "\(dto.id)"
        content = dto.content
        isUser = dto.role == "user"
        timestamp = Self.parseApiDate(dto.sentAt ?? "")
        messageType = dto.messageType
        self.routeVariants = routeVariants
        imageData = nil
        hasImageFromServer = dto.hasImage ?? false
    }
}
