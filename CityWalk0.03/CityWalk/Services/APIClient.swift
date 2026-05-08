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

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    var authToken: String? {
        didSet { UserDefaults.standard.set(authToken, forKey: "campus_walk_token") }
    }

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        session = URLSession(configuration: config)
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

    func sendMessage(conversationId: Int, content: String) async throws -> SendMessageResponseDTO {
        struct Body: Encodable { let content: String }
        let body = try encoder.encode(Body(content: content))
        let req = try makeRequest(path: "/api/v1/conversations/\(conversationId)/messages", method: "POST", body: body)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw APIError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1, String(data: data, encoding: .utf8))
        }
        return try decodeEnvelope(data, as: SendMessageResponseDTO.self)
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

    func arRecognize(latitude: Double, longitude: Double, heading: Double, sessionId: Int?) async throws -> ARRecognizeDTO {
        struct Body: Encodable {
            let sessionId: Int?
            let latitude: Double
            let longitude: Double
            let heading: Double
        }
        let body = try encoder.encode(Body(sessionId: sessionId, latitude: latitude, longitude: longitude, heading: heading))
        let req = try makeRequest(path: "/api/v1/ar/recognize", method: "POST", body: body)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw APIError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1, String(data: data, encoding: .utf8))
        }
        return try decodeEnvelope(data, as: ARRecognizeDTO.self)
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
    let messageType: String
    let content: String
    let sentAt: String
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
}

struct RouteBatchDTO: Decodable {
    let id: Int
    let conversationId: Int
    let createdAt: String
    let variants: [RouteVariantDTO]
}

struct SendMessageResponseDTO: Decodable {
    let userMessage: ChatMessageDTO
    let assistantMessage: ChatMessageDTO
    let routeBatch: RouteBatchDTO
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
