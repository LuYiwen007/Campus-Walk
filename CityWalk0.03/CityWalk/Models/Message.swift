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
        imageData: Data? = nil
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.messageType = messageType
        self.routeVariants = routeVariants
        self.imageData = imageData
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
        timestamp = Self.parseApiDate(dto.sentAt)
        messageType = dto.messageType
        routeVariants = nil
        imageData = nil
    }

    init(dto: ChatMessageDTO, routeVariants: [RouteVariantDTO]?) {
        id = "\(dto.id)"
        content = dto.content
        isUser = dto.role == "user"
        timestamp = Self.parseApiDate(dto.sentAt)
        messageType = dto.messageType
        self.routeVariants = routeVariants
        imageData = nil
    }
}
