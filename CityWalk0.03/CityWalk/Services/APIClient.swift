import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case httpStatus(Int, String?)
    case decode(Error)
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的接口地址"
        case .httpStatus(let code, let body): return "请求失败 (\(code)): \(body ?? "")"
        case .decode(let e): return "数据解析失败: \(e.localizedDescription)"
        case .serverMessage(let m): return m
        }
    }
}

private struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let resultCode: String?
    let message: String?
    let data: T?

    enum CodingKeys: String, CodingKey {
        case success, message, data
        case resultCode = "result_code"
    }
}

/// 流式/历史接口里数字、数组、文案形态不一致时的宽松解码
private enum FlexibleJSON {
    static func intKey<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Int {
        if let i = try? c.decode(Int.self, forKey: key) { return i }
        if let s = try? c.decode(String.self, forKey: key), let i = Int(s) { return i }
        if let d = try? c.decode(Double.self, forKey: key) { return Int(d.rounded()) }
        return 0
    }

    static func stringKey<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> String {
        (try? c.decode(String.self, forKey: key)) ?? ""
    }

    static func stringArrayKey<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> [String] {
        (try? c.decode([String].self, forKey: key)) ?? []
    }

    static func optDouble<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Double? {
        if let x = try? c.decode(Double.self, forKey: key) { return x }
        if let s = try? c.decode(String.self, forKey: key), let x = Double(s) { return x }
        return nil
    }
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    var authToken: String? {
        didSet { UserDefaults.standard.set(authToken, forKey: "campus_walk_token") }
    }

    /// 长连接流式对话（SSE）
    private let streamSession: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        session = URLSession(configuration: config)
        let streamConfig = URLSessionConfiguration.default
        streamConfig.timeoutIntervalForRequest = 120
        streamConfig.timeoutIntervalForResource = 600
        streamSession = URLSession(configuration: streamConfig)
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = f.date(from: str) { return d }
            f.formatOptions = [.withInternetDateTime]
            if let d = f.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(str)")
        }
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        authToken = UserDefaults.standard.string(forKey: "campus_walk_token")
    }

    func clearToken() {
        authToken = nil
        UserDefaults.standard.removeObject(forKey: "campus_walk_token")
    }

    private func makeRequest(path: String, method: String, body: Data? = nil) throws -> URLRequest {
        let base = APIConfiguration.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let p = path.hasPrefix("/") ? path : "/" + path
        guard let url = URL(string: base + p) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = authToken {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
        return req
    }

    private func decodeEnvelope<T: Decodable>(_ data: Data, as: T.Type) throws -> T {
        let env = try decoder.decode(APIEnvelope<T>.self, from: data)
        guard env.success, let payload = env.data else {
            let msg = env.message ?? env.resultCode ?? "请求失败"
            throw APIError.serverMessage(msg)
        }
        return payload
    }

    func login(email: String, password: String) async throws -> LoginResponseDTO {
        struct Body: Encodable { let email: String; let password: String }
        let body = try encoder.encode(Body(email: email, password: password))
        let req = try makeRequest(path: "/api/v1/auth/login", method: "POST", body: body)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.httpStatus(-1, nil) }
        guard (200 ... 299).contains(http.statusCode) else {
            let txt = String(data: data, encoding: .utf8)
            throw APIError.httpStatus(http.statusCode, txt)
        }
        return try decodeEnvelope(data, as: LoginResponseDTO.self)
    }

    func me() async throws -> UserDTO {
        let req = try makeRequest(path: "/api/v1/auth/me", method: "GET")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw APIError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1, String(data: data, encoding: .utf8))
        }
        return try decodeEnvelope(data, as: UserDTO.self)
    }

    func createConversation(title: String = "新对话") async throws -> CreateConversationDTO {
        struct Body: Encodable { let title: String }
        let body = try encoder.encode(Body(title: title))
        let req = try makeRequest(path: "/api/v1/conversations", method: "POST", body: body)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw APIError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1, String(data: data, encoding: .utf8))
        }
        return try decodeEnvelope(data, as: CreateConversationDTO.self)
    }

    func listMessages(conversationId: Int) async throws -> [ChatMessageDTO] {
        let req = try makeRequest(path: "/api/v1/conversations/\(conversationId)/messages", method: "GET")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw APIError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1, String(data: data, encoding: .utf8))
        }
        return try decodeEnvelope(data, as: [ChatMessageDTO].self)
    }

    /// 创建导航会话（途经点与进度由后端持有）
    func createNavigationSession(routeVariantId: Int) async throws -> NavigationSessionDTO {
        struct Body: Encodable {
            let routeVariantId: Int
        }
        let body = try encoder.encode(Body(routeVariantId: routeVariantId))
        let req = try makeRequest(path: "/api/v1/navigation/sessions", method: "POST", body: body)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw APIError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1, String(data: data, encoding: .utf8))
        }
        return try decodeEnvelope(data, as: NavigationSessionDTO.self)
    }

    func patchNavigationSession(sessionId: Int, activeLegIndex: Int?, status: String?) async throws -> NavigationSessionDTO {
        struct Body: Encodable {
            let activeLegIndex: Int?
            let status: String?
        }
        let body = try encoder.encode(Body(activeLegIndex: activeLegIndex, status: status))
        let req = try makeRequest(path: "/api/v1/navigation/sessions/\(sessionId)", method: "PATCH", body: body)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw APIError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1, String(data: data, encoding: .utf8))
        }
        return try decodeEnvelope(data, as: NavigationSessionDTO.self)
    }

    func sendMessage(conversationId: Int, content: String, imageJPEGData: Data? = nil) async throws -> SendMessageResponseDTO {
        struct Body: Encodable {
            let content: String
            let imageBase64: String?
            let imageMimeType: String?
        }
        let b64 = imageJPEGData.map { $0.base64EncodedString() }
        let bodyObj = Body(
            content: content,
            imageBase64: b64,
            imageMimeType: b64 != nil ? "image/jpeg" : nil
        )
        let body = try encoder.encode(bodyObj)
        let req = try makeRequest(path: "/api/v1/conversations/\(conversationId)/messages", method: "POST", body: body)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw APIError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1, String(data: data, encoding: .utf8))
        }
        return try decodeEnvelope(data, as: SendMessageResponseDTO.self)
    }

    /// 流式发送消息：`event:user` → `route_batch` → `delta` → `done`；失败时 `event:error` 或 HTTP 非 2xx。
    func sendMessageStream(
        conversationId: Int,
        content: String,
        imageJPEGData: Data? = nil,
        onUserMessage: (@MainActor (ChatMessageDTO) -> Void)? = nil,
        onRouteBatch: (@MainActor (RouteBatchDTO) -> Void)? = nil,
        onTextDelta: (@MainActor (String) -> Void)? = nil
    ) async throws -> SendMessageResponseDTO {
        struct Body: Encodable {
            let content: String
            let imageBase64: String?
            let imageMimeType: String?
        }
        let b64 = imageJPEGData.map { $0.base64EncodedString() }
        let bodyObj = Body(
            content: content,
            imageBase64: b64,
            imageMimeType: b64 != nil ? "image/jpeg" : nil
        )
        let body = try encoder.encode(bodyObj)
        let req = try makeRequest(path: "/api/v1/conversations/\(conversationId)/messages/stream", method: "POST", body: body)
        let (bytes, resp) = try await streamSession.bytes(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.httpStatus(-1, nil)
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw APIError.httpStatus(http.statusCode, nil)
        }

        var currentEvent = ""
        var dataLines: [String] = []
        var doneResult: SendMessageResponseDTO?

        func flushBlock() async throws {
            guard !dataLines.isEmpty else { return }
            let payload = dataLines.joined(separator: "\n")
            dataLines.removeAll()
            let name = currentEvent.trimmingCharacters(in: .whitespacesAndNewlines)
            currentEvent = ""
            guard let d = payload.data(using: .utf8) else { return }
            switch name {
            case "user":
                let dto = try decodeStreamUserMessage(d)
                await MainActor.run { onUserMessage?(dto) }
            case "route_batch":
                if let batch = try? decoder.decode(RouteBatchDTO.self, from: d) {
                    await MainActor.run { onRouteBatch?(batch) }
                }
            case "delta":
                if let delta = try? decoder.decode(StreamDeltaDTO.self, from: d) {
                    let t = delta.text ?? ""
                    if !t.isEmpty { await MainActor.run { onTextDelta?(t) } }
                } else if let s = try? decoder.decode(String.self, from: d), !s.isEmpty {
                    await MainActor.run { onTextDelta?(s) }
                }
            case "done":
                doneResult = try decodeStreamDonePayload(d)
            case "error":
                let err = try decoder.decode(StreamErrorDTO.self, from: d)
                throw APIError.serverMessage(err.message ?? "流式请求失败")
            default:
                break
            }
        }

        for try await line in bytes.lines {
            let trimmed = String(line).trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                try await flushBlock()
                continue
            }
            if trimmed.hasPrefix("event:") {
                currentEvent = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("data:") {
                dataLines.append(String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }
        try await flushBlock()

        guard let out = doneResult else {
            throw APIError.serverMessage("流式响应未收到 done 事件")
        }
        return out
    }

    func latestRouteBatch(conversationId: Int) async throws -> RouteBatchDTO? {
        struct Envelope: Decodable {
            let success: Bool
            let message: String?
            let data: RouteBatchDTO?
        }
        let req = try makeRequest(path: "/api/v1/conversations/\(conversationId)/route-batches/latest", method: "GET")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw APIError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1, String(data: data, encoding: .utf8))
        }
        let env = try decoder.decode(Envelope.self, from: data)
        guard env.success else {
            throw APIError.serverMessage(env.message ?? "加载失败")
        }
        return env.data
    }

    func communityPosts() async throws -> [CommunityPostDTO] {
        let req = try makeRequest(path: "/api/v1/community/posts", method: "GET")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw APIError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1, String(data: data, encoding: .utf8))
        }
        return try decodeEnvelope(data, as: [CommunityPostDTO].self)
    }

    func arRecognize(latitude: Double, longitude: Double, heading: Double, sessionId: Int?, imageJPEGData: Data? = nil) async throws -> ARRecognizeDTO {
        struct Body: Encodable {
            let sessionId: Int?
            let latitude: Double
            let longitude: Double
            let heading: Double
            let imageBase64: String?
            let imageMimeType: String?
        }
        let b64 = imageJPEGData.map { $0.base64EncodedString() }
        let body = try encoder.encode(Body(
            sessionId: sessionId,
            latitude: latitude,
            longitude: longitude,
            heading: heading,
            imageBase64: b64,
            imageMimeType: b64 != nil ? "image/jpeg" : nil
        ))
        let req = try makeRequest(path: "/api/v1/ar/recognize", method: "POST", body: body)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw APIError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1, String(data: data, encoding: .utf8))
        }
        return try decodeEnvelope(data, as: ARRecognizeDTO.self)
    }

    /// 流式 `done`：根对象、仅 `data` 包裹、或统一 API 信封
    private func decodeStreamDonePayload(_ data: Data) throws -> SendMessageResponseDTO {
        if let r = try? decoder.decode(SendMessageResponseDTO.self, from: data) { return r }
        struct DataShell: Decodable { let data: SendMessageResponseDTO }
        if let s = try? decoder.decode(DataShell.self, from: data) { return s.data }
        if let env = try? decoder.decode(APIEnvelope<SendMessageResponseDTO>.self, from: data), env.success, let p = env.data {
            return p
        }
        let snippet = String(data: data, encoding: .utf8).map { String($0.prefix(320)) } ?? ""
        throw APIError.serverMessage(snippet.isEmpty ? "无法解析流式结束(done)数据" : "无法解析流式结束(done)数据，片段：\(snippet)")
    }

    /// 流式 `user`：`data` 包裹、API 信封、或 `message` 单键
    private func decodeStreamUserMessage(_ data: Data) throws -> ChatMessageDTO {
        if let m = try? decoder.decode(ChatMessageDTO.self, from: data) { return m }
        struct DataShell: Decodable { let data: ChatMessageDTO }
        if let s = try? decoder.decode(DataShell.self, from: data) { return s.data }
        struct MsgShell: Decodable { let message: ChatMessageDTO }
        if let s = try? decoder.decode(MsgShell.self, from: data) { return s.message }
        if let env = try? decoder.decode(APIEnvelope<ChatMessageDTO>.self, from: data), env.success, let m = env.data {
            return m
        }
        let snippet = String(data: data, encoding: .utf8).map { String($0.prefix(320)) } ?? ""
        throw APIError.serverMessage(snippet.isEmpty ? "无法解析流式用户(user)消息" : "无法解析流式用户(user)消息，片段：\(snippet)")
    }
}

// MARK: - DTOs

struct LoginResponseDTO: Decodable {
    let accessToken: String
    let tokenType: String
    let user: UserDTO
}

struct UserDTO: Decodable {
    let id: Int
    let email: String
    let nickname: String
}

struct CreateConversationDTO: Decodable {
    let conversation: ConversationSummaryDTO
    let welcomeMessage: ChatMessageDTO
}

struct ConversationSummaryDTO: Decodable {
    let id: Int
    let title: String
    let createdAt: String
}

struct ChatMessageDTO: Decodable {
    let id: Int
    let conversationId: Int
    let role: String
    let messageType: String?
    let content: String
    /// 部分流式片段或非标响应可能缺省时间戳
    let sentAt: String?
    /// 仅 route_plan 类型消息可能携带，与后端 assistant_message 关联的批次
    let routeBatch: RouteBatchDTO?
    let hasImage: Bool?

    enum CodingKeys: String, CodingKey {
        case id, conversationId, role, messageType, content, sentAt, routeBatch, hasImage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = FlexibleJSON.intKey(c, .id)
        conversationId = FlexibleJSON.intKey(c, .conversationId)
        role = try c.decodeIfPresent(String.self, forKey: .role) ?? "assistant"
        messageType = try c.decodeIfPresent(String.self, forKey: .messageType)
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        sentAt = try c.decodeIfPresent(String.self, forKey: .sentAt)
        routeBatch = try c.decodeIfPresent(RouteBatchDTO.self, forKey: .routeBatch)
        hasImage = try c.decodeIfPresent(Bool.self, forKey: .hasImage)
    }
}

struct NavigationWaypointDTO: Decodable, Equatable, Hashable {
    let order: Int
    let label: String
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey { case order, label, latitude, longitude }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        order = FlexibleJSON.intKey(c, .order)
        label = FlexibleJSON.stringKey(c, .label)
        latitude = FlexibleJSON.optDouble(c, .latitude)
        longitude = FlexibleJSON.optDouble(c, .longitude)
    }
}

struct RouteVariantDTO: Decodable, Equatable, Hashable {
    let id: Int
    let routeNumber: Int
    let displayLabel: String
    let startLabel: String
    let endLabel: String
    let scenicSpotCount: Int
    let scenicSpotExamples: [String]
    let estimatedDurationSeconds: Int
    let estimatedDistanceMeters: Int
    let description: String
    /// 后端持久化途经点（含坐标）；旧数据可能为 nil
    let waypoints: [NavigationWaypointDTO]?

    enum CodingKeys: String, CodingKey {
        case id, routeNumber, displayLabel, startLabel, endLabel, scenicSpotCount
        case scenicSpotExamples, estimatedDurationSeconds, estimatedDistanceMeters, description, waypoints
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = FlexibleJSON.intKey(c, .id)
        routeNumber = FlexibleJSON.intKey(c, .routeNumber)
        displayLabel = FlexibleJSON.stringKey(c, .displayLabel)
        startLabel = FlexibleJSON.stringKey(c, .startLabel)
        endLabel = FlexibleJSON.stringKey(c, .endLabel)
        scenicSpotCount = FlexibleJSON.intKey(c, .scenicSpotCount)
        scenicSpotExamples = FlexibleJSON.stringArrayKey(c, .scenicSpotExamples)
        estimatedDurationSeconds = FlexibleJSON.intKey(c, .estimatedDurationSeconds)
        estimatedDistanceMeters = FlexibleJSON.intKey(c, .estimatedDistanceMeters)
        description = FlexibleJSON.stringKey(c, .description)
        waypoints = try? c.decode([NavigationWaypointDTO].self, forKey: .waypoints)
    }
}

struct NavigationSessionDTO: Decodable, Equatable {
    let id: Int
    let routeVariantId: Int
    let activeLegIndex: Int
    let status: String
    let waypoints: [NavigationWaypointDTO]
}

struct RouteBatchDTO: Decodable {
    let id: Int
    let conversationId: Int
    let createdAt: String
    let variants: [RouteVariantDTO]

    enum CodingKeys: String, CodingKey {
        case id, conversationId, createdAt, variants
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        conversationId = try c.decodeIfPresent(Int.self, forKey: .conversationId) ?? 0
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        variants = try c.decodeIfPresent([RouteVariantDTO].self, forKey: .variants) ?? []
    }
}

struct SendMessageResponseDTO: Decodable {
    /// 流式 done 里可能只回 assistant，不再重复 user
    let userMessage: ChatMessageDTO?
    let assistantMessage: ChatMessageDTO
    /// 无路线规划时后端可能省略
    let routeBatch: RouteBatchDTO?
}

private struct StreamDeltaDTO: Decodable {
    let text: String?

    init(from decoder: Decoder) throws {
        if let svc = try? decoder.singleValueContainer(), let s = try? svc.decode(String.self) {
            text = s
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decodeIfPresent(String.self, forKey: .text)
            ?? c.decodeIfPresent(String.self, forKey: .delta)
            ?? c.decodeIfPresent(String.self, forKey: .content)
    }

    private enum CodingKeys: String, CodingKey { case text, delta, content }
}

private struct StreamErrorDTO: Decodable {
    let code: Int?
    let message: String?
}

struct CommunityPostDTO: Decodable, Identifiable {
    let id: Int
    let title: String
    let body: String
    let coverImageUrl: String
    let authorDisplayName: String
    let authorAvatarUrl: String
    let likesCount: Int
    let createdAt: String
}

struct ARRecognizeDTO: Decodable {
    let building: ARBuildingDTO?
    let confidence: Double
    let matchNote: String
}

struct ARBuildingDTO: Decodable {
    let id: Int
    let name: String
    let description: String
    let coverImageUrl: String
    let galleryUrls: [String]
}
