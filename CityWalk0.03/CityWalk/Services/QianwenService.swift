import Foundation

// 通义千问相关错误类型定义
enum QianwenError: Error {
    case invalidURL // URL无效
    case networkError(Error) // 网络错误
    case invalidResponse // 响应无效
    case unauthorized // 未授权
    case unknown // 未知错误
}

// 通义千问服务，负责与阿里云通义千问API进行网络通信
class QianwenService: NSObject, URLSessionDataDelegate {
    static let shared = QianwenService() // 单例
    
    private var receivedData: Data = Data()
    private var dataTask: URLSessionDataTask?
    private var onReceive: ((String) -> Void)?
    private var onComplete: ((Error?) -> Void)?
    private var currentQuery: String = ""
    private var currentConversationId: Int = 0
    
    private override init() {}
    
    private let apiKey = "sk-7c54a7c880bc41c29bb571fd2c348488" // API密钥
    private let baseURL = "http://192.168.3.39:8000" // 你的电脑IP地址
    
    // 测试网络连接
    func testConnection() {
        print("🔍🔍🔍 Testing connection to: \(baseURL) 🔍🔍🔍")
        guard let url = URL(string: "\(baseURL)/health") else {
            print("❌❌❌ Invalid health check URL ❌❌❌")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌❌❌ Health check failed: \(error) ❌❌❌")
            } else if let httpResponse = response as? HTTPURLResponse {
                print("✅✅✅ Health check success: \(httpResponse.statusCode) ✅✅✅")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("📄📄📄 Health response: \(responseString) 📄📄📄")
                }
            }
        }
        task.resume()
    }
    private let appId = "7188b1ce823343f9b919d61f0a5f7d59" // 用户阿里云应用ID

    // 调用通义千问API获取AI回复
    private func callQianwenAPI(_ text: String) async throws -> String {
        print("=== callQianwenAPI called with: \(text) ===")
        print("=== API Key: \(apiKey) ===")
        let endpoint = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation"
        guard let url = URL(string: endpoint) else {
            print("=== Invalid URL: \(endpoint) ===")
            throw QianwenError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "qwen-turbo",
            "input": [
                "messages": [
                    [
                        "role": "user",
                        "content": text
                    ]
                ]
            ],
            "parameters": [
                "result_format": "message"
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        print("=== Request body: \(body) ===")

        print("=== Making request to: \(endpoint) ===")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("=== Invalid HTTP response ===")
            throw QianwenError.invalidResponse
        }

        print("=== HTTP Status Code: \(httpResponse.statusCode) ===")
        if let responseString = String(data: data, encoding: .utf8) {
            print("=== Response data: \(responseString) ===")
        }

        if httpResponse.statusCode != 200 {
            print("=== HTTP error: \(httpResponse.statusCode) ===")
            print("=== Response headers: \(httpResponse.allHeaderFields) ===")
            throw QianwenError.invalidResponse
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [String: Any],
              let choices = output["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            print("=== Failed to parse response JSON ===")
            throw QianwenError.invalidResponse
        }

        print("=== Extracted content: \(content) ===")
        return content
    }
    
    // 创建会话
    private func createConversation(title: String) async throws -> Int {
        print("🔧🔧🔧 createConversation called with title: \(title) 🔧🔧🔧")
        let endpoint = "\(baseURL)/conversations/add.json"
        print("🌐🌐🌐 Creating conversation at: \(endpoint) 🌐🌐🌐")
        guard let url = URL(string: endpoint) else {
            print("❌❌❌ Invalid URL: \(endpoint) ❌❌❌")
            throw QianwenError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "title": title,
            "llmModel": "defaultModel"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        print("📦📦📦 Request body: \(body) 📦📦📦")

        print("🚀🚀🚀 Making request to create conversation 🚀🚀🚀")
        
        // 添加超时配置
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 30.0
        let session = URLSession(configuration: config)
        
        do {
            let (data, response) = try await session.data(for: request)
            print("📡📡📡 Received response from server 📡📡📡")

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌❌❌ Invalid HTTP response ❌❌❌")
                throw QianwenError.invalidResponse
            }

            print("📊📊📊 HTTP Status Code: \(httpResponse.statusCode) 📊📊📊")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄📄📄 Response data: \(responseString) 📄📄📄")
            }

            if httpResponse.statusCode != 200 {
                print("❌❌❌ HTTP error: \(httpResponse.statusCode) ❌❌❌")
                throw QianwenError.invalidResponse
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataDict = json["data"] as? [String: Any],
                  let id = dataDict["id"] as? Int else {
                print("❌❌❌ Failed to parse response JSON ❌❌❌")
                print("📄📄📄 Raw response: \(String(data: data, encoding: .utf8) ?? "nil") 📄📄📄")
                throw QianwenError.invalidResponse
            }

            print("✅✅✅ Successfully created conversation with ID: \(id) ✅✅✅")
            return id
        } catch {
            print("💥💥💥 Network error in createConversation: \(error) 💥💥💥")
            throw error
        }
    }
    
    // 根据用户输入生成会话标题 - 用户消息格式
    private func generateConversationTitle(from query: String) -> String {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 获取当前时间
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        let timeString = formatter.string(from: Date())
        
        // 如果输入很短，直接使用
        if trimmedQuery.count <= 12 {
            return "[用户] \(trimmedQuery) (\(timeString))"
        }
        
        // 如果输入较长，截取前12个字符并添加省略号
        let index = trimmedQuery.index(trimmedQuery.startIndex, offsetBy: 12)
        let truncated = String(trimmedQuery[..<index])
        return "[用户] \(truncated)... (\(timeString))"
    }
    
    // 保存AI回复到数据库 - 创建单独的AI会话
    private func saveAIReply(conversationId: Int, content: String) {
        Task {
            do {
                // 为AI回复创建单独的会话
                let aiTitle = generateAITitle(from: content)
                let aiConversationId = try await createConversation(title: aiTitle)
                
                // 保存AI回复到新的会话中
                let endpoint = "\(baseURL)/conversations/addChat.json"
                guard let url = URL(string: endpoint) else { return }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let body: [String: Any] = [
                    "content": content,
                    "conversationId": aiConversationId,
                    "type": "TEXT",
                    "role": "assistant"
                ]
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
                    request.httpBody = jsonData
                    
                    print("Saving AI reply to new conversation: \(aiTitle)")
                    
                    let task = URLSession.shared.dataTask(with: request) { data, response, error in
                        if let error = error {
                            print("Error saving AI reply: \(error)")
                        } else if let data = data, let responseString = String(data: data, encoding: .utf8) {
                            print("AI reply saved: \(responseString)")
                        }
                    }
                    task.resume()
                    
                } catch {
                    print("Error serializing AI reply: \(error)")
                }
            } catch {
                print("Error creating AI conversation: \(error)")
            }
        }
    }
    
    // 生成AI回复的标题
    private func generateAITitle(from content: String) -> String {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 获取当前时间
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        let timeString = formatter.string(from: Date())
        
        // 如果内容很短，直接使用
        if trimmedContent.count <= 12 {
            return "[AI] \(trimmedContent) (\(timeString))"
        }
        
        // 如果内容较长，截取前12个字符并添加省略号
        let index = trimmedContent.index(trimmedContent.startIndex, offsetBy: 12)
        let truncated = String(trimmedContent[..<index])
        return "[AI] \(truncated)... (\(timeString))"
    }

    // 以流式方式发送消息，逐步回调onReceive，结束时回调onComplete
    func streamMessage(
        query: String,
        onReceive: @escaping (String) -> Void,
        onComplete: @escaping (Error?) -> Void
    ) {
        print("🚀🚀🚀 streamMessage called with query: \(query) 🚀🚀🚀")
        
        // 先测试网络连接
        testConnection()
        
        self.onReceive = onReceive
        self.onComplete = onComplete
        self.receivedData = Data()
        self.currentQuery = query

        // 先创建会话，然后发送消息
        Task {
            do {
                // 根据用户输入生成更有意义的标题
                let title = generateConversationTitle(from: query)
                print("🎯🎯🎯 Creating conversation with title: \(title) 🎯🎯🎯")
                let conversationId = try await createConversation(title: title)
                self.currentConversationId = conversationId
                print("✅✅✅ Conversation created with ID: \(conversationId) ✅✅✅")
                
                // 发送消息到我们的后端
                let endpoint = "\(baseURL)/conversations/addChat.json"
                print("📤📤📤 Sending message to backend: \(endpoint) 📤📤📤")
                guard let url = URL(string: endpoint) else {
                    print("❌❌❌ Invalid URL: \(endpoint) ❌❌❌")
                    onComplete(QianwenError.invalidURL)
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let body: [String: Any] = [
                    "content": query,
                    "conversationId": conversationId,
                    "type": "TEXT",
                    "role": "user"
                ]
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
                    request.httpBody = jsonData
                    
                    print("Request URL: \(endpoint)")
                    print("Request Headers: \(request.allHTTPHeaderFields ?? [:])")
                    print("Request Body: \(String(data: jsonData, encoding: .utf8) ?? "")")
                    
                    let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
                    dataTask = session.dataTask(with: request)
                    dataTask?.resume()
                    
                } catch {
                    print("JSON serialization error: \(error)")
                    onComplete(error)
                }
            } catch {
                print("💥💥💥 Error in streamMessage Task: \(error) 💥💥💥")
                onComplete(error)
            }
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
        print("=== Received data chunk, total size: \(receivedData.count) ===")
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("=== Network error: \(error) ===")
            self.onComplete?(QianwenError.networkError(error))
        } else {
            print("=== Request completed successfully ===")
            print("=== Total received data size: \(receivedData.count) ===")
            
            // 处理完整的响应数据
            if let string = String(data: receivedData, encoding: .utf8) {
                print("=== Complete response: \(string) ===")
                
                // 解析JSON响应
                if let jsonData = string.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    
                    print("=== Parsed JSON: \(json) ===")
                    
                    // 检查是否成功
                    if let success = json["success"] as? Bool, success {
                        print("=== Success: true, calling AI API ===")
                        print("=== Current Query: \(self.currentQuery) ===")
                        // 调用通义千问API
                        Task {
                            do {
                                print("=== Starting Qianwen API call ===")
                                let aiResponse = try await self.callQianwenAPI(self.currentQuery)
                                print("=== Qianwen API response received: \(aiResponse) ===")
                                
                                DispatchQueue.main.async {
                                    print("=== Calling onReceive with: \(aiResponse) ===")
                                    self.onReceive?(aiResponse)
                                    print("=== onReceive called successfully ===")
                                    
                                    // 调用完成回调
                                    self.onComplete?(nil)
                                }
                                
                                // 将AI回复存储到数据库
                                self.saveAIReply(conversationId: self.currentConversationId, content: aiResponse)
                            } catch {
                                print("=== Qianwen API error: \(error) ===")
                                DispatchQueue.main.async {
                                    self.onReceive?("AI调用失败：\(error.localizedDescription)")
                                    self.onComplete?(error)
                                }
                            }
                        }
                    } else {
                        print("=== Success: false ===")
                        // 处理错误
                        let errorMessage = json["resultCode"] as? String ?? "未知错误"
                        DispatchQueue.main.async {
                            self.onReceive?("错误：\(errorMessage)")
                            self.onComplete?(QianwenError.invalidResponse)
                        }
                    }
                } else {
                    print("=== Failed to parse JSON ===")
                    DispatchQueue.main.async {
                        self.onReceive?("服务器响应格式错误")
                        self.onComplete?(QianwenError.invalidResponse)
                    }
                }
            } else {
                print("=== Failed to convert data to string ===")
                DispatchQueue.main.async {
                    self.onReceive?("服务器响应数据错误")
                    self.onComplete?(QianwenError.invalidResponse)
                }
            }
        }
        
        // 清理资源
        self.receivedData = Data()
        self.dataTask = nil
    }
} 
