//
//  ARRecognitionService.swift
//  CityWalk
//
//  Created on 2025/1/20.
//

import Foundation
import CoreLocation

/// AR识别服务错误类型
enum ARRecognitionError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case noData
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "无效的响应"
        case .apiError(let message):
            return "API错误: \(message)"
        case .noData:
            return "没有数据"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        }
    }
}

/// AR识别服务
/// 负责与后端API进行通信，获取附近POI和保存识别记录
@MainActor
class ARRecognitionService {
    static let shared = ARRecognitionService()
    
    // MARK: - 配置
    
    /// 后端服务器地址
    private let baseURL = "http://192.168.3.39:8000"
    
    /// 请求超时时间（秒）
    private let timeoutInterval: TimeInterval = 10.0
    
    /// 最大重试次数
    private let maxRetryCount = 2
    
    /// URLSession配置
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeoutInterval
        configuration.timeoutIntervalForResource = timeoutInterval * 2
        return URLSession(configuration: configuration)
    }()
    
    private init() {}
    
    // MARK: - 获取附近POI
    
    /// 获取附近的POI
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    ///   - heading: 设备朝向（0-360度）
    ///   - radius: 搜索半径（米），默认150，最大500
    ///   - fov: 视野角度（度），默认60
    ///   - useCache: 是否使用缓存，默认true
    ///   - completion: 完成回调，返回POI数组或错误
    func fetchNearbyPOI(
        latitude: Double,
        longitude: Double,
        heading: Double = 0.0,
        radius: Int = 150,
        fov: Double = 60.0,
        useCache: Bool = true,
        completion: @escaping (Result<[POI], ARRecognitionError>) -> Void
    ) {
        // 1. 检查缓存（如果启用）
        if useCache {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            if let cache = POIManager.shared.checkCache(
                coordinate: coordinate,
                radius: Double(radius),
                heading: heading,
                fov: fov
            ) {
                // 缓存命中，从缓存数据创建POI对象
                if let cachedPOIs = parsePOIsFromCache(cache.cacheData) {
                    print("✅ [ARRecognitionService] 使用缓存数据，返回\(cachedPOIs.count)个POI")
                    completion(.success(cachedPOIs))
                    return
                }
            }
        }
        
        // 2. 构建API请求URL
        guard let url = buildNearbyPOIURL(
            latitude: latitude,
            longitude: longitude,
            heading: heading,
            radius: radius,
            fov: fov
        ) else {
            completion(.failure(.invalidURL))
            return
        }
        
        // 3. 调用API（带重试机制）
        performRequest(
            url: url,
            method: "GET",
            body: nil,
            retryCount: 0
        ) { [weak self] result in
            switch result {
            case .success(let data):
                // 4. 解析返回数据
                self?.parseNearbyPOIResponse(data: data) { parseResult in
                    switch parseResult {
                    case .success(let pois):
                        // 5. 更新缓存
                        if useCache {
                            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                            let cacheData = pois.map { $0.toDictionary() }
                            _ = POIManager.shared.saveCache(
                                coordinate: coordinate,
                                radius: Double(radius),
                                cacheData: cacheData,
                                heading: heading,
                                fov: fov
                            )
                        }
                        completion(.success(pois))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 构建获取附近POI的URL
    private func buildNearbyPOIURL(
        latitude: Double,
        longitude: Double,
        heading: Double,
        radius: Int,
        fov: Double
    ) -> URL? {
        var components = URLComponents(string: "\(baseURL)/poi/nearby")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "heading", value: String(heading)),
            URLQueryItem(name: "radius", value: String(radius)),
            URLQueryItem(name: "fov", value: String(fov))
        ]
        return components?.url
    }
    
    /// 解析获取附近POI的响应数据
    private func parseNearbyPOIResponse(
        data: Data,
        completion: @escaping (Result<[POI], ARRecognitionError>) -> Void
    ) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(.invalidResponse))
                return
            }
            
            // 检查API返回的success字段
            let success = json["success"] as? Bool ?? false
            if !success {
                let message = json["message"] as? String ?? "未知错误"
                completion(.failure(.apiError(message)))
                return
            }
            
            // 解析data字段
            guard let dataValue = json["data"] else {
                completion(.failure(.noData))
                return
            }
            
            var pois: [POI] = []
            
            // 处理单个POI对象
            if let poiDict = dataValue as? [String: Any] {
                if let poi = POI.from(dict: poiDict) {
                    pois.append(poi)
                }
            }
            // 处理POI数组
            else if let poiArray = dataValue as? [[String: Any]] {
                for poiDict in poiArray {
                    if let poi = POI.from(dict: poiDict) {
                        pois.append(poi)
                    }
                }
            }
            
            if pois.isEmpty {
                completion(.failure(.noData))
            } else {
                print("✅ [ARRecognitionService] 解析成功，获取\(pois.count)个POI")
                completion(.success(pois))
            }
        } catch {
            completion(.failure(.decodingError(error)))
        }
    }
    
    /// 从缓存数据解析POI数组
    private func parsePOIsFromCache(_ cacheData: [[String: Any]]) -> [POI]? {
        var pois: [POI] = []
        for dict in cacheData {
            if let poi = POI.from(dict: dict) {
                // 如果缓存中有id字段，尝试设置（虽然SwiftData会自动生成，但保留用于兼容）
                pois.append(poi)
            }
        }
        return pois.isEmpty ? nil : pois
    }
    
    // MARK: - 保存识别记录（可选）
    
    /// 保存AR识别记录到后端
    /// - Parameters:
    ///   - latitude: 识别时的纬度
    ///   - longitude: 识别时的经度
    ///   - heading: 设备朝向
    ///   - fov: 视野角度
    ///   - radius: 搜索半径
    ///   - detectedPOIId: 识别到的POI ID（数据库主键）
    ///   - confidence: 识别置信度（0-1）
    ///   - sessionId: 会话ID（可选）
    ///   - userId: 用户ID（可选）
    ///   - recognitionMode: 识别模式，默认"auto"
    ///   - completion: 完成回调
    func saveRecognitionRecord(
        latitude: Double,
        longitude: Double,
        heading: Double? = nil,
        fov: Double? = nil,
        radius: Double? = nil,
        detectedPOIId: Int? = nil,
        confidence: Double? = nil,
        sessionId: String? = nil,
        userId: String? = nil,
        recognitionMode: String = "auto",
        completion: @escaping (Result<Bool, ARRecognitionError>) -> Void
    ) {
        // 构建请求URL
        guard let url = URL(string: "\(baseURL)/ar-recognition/save") else {
            completion(.failure(.invalidURL))
            return
        }
        
        // 构建请求体
        var body: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude,
            "recognition_mode": recognitionMode
        ]
        
        if let heading = heading {
            body["heading"] = heading
        }
        if let fov = fov {
            body["fov"] = fov
        }
        if let radius = radius {
            body["radius"] = radius
        }
        if let detectedPOIId = detectedPOIId {
            body["detected_poi_id"] = detectedPOIId
        }
        if let confidence = confidence {
            body["confidence"] = confidence
        }
        if let sessionId = sessionId {
            body["session_id"] = sessionId
        }
        if let userId = userId {
            body["user_id"] = userId
        }
        
        // 发送请求
        performRequest(
            url: url,
            method: "POST",
            body: body,
            retryCount: 0
        ) { result in
            switch result {
            case .success(let data):
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let success = json["success"] as? Bool, success else {
                        let message = (json as? [String: Any])?["message"] as? String ?? "保存失败"
                        completion(.failure(.apiError(message)))
                        return
                    }
                    print("✅ [ARRecognitionService] 识别记录保存成功")
                    completion(.success(true))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 网络请求封装
    
    /// 执行网络请求（带重试机制）
    private func performRequest(
        url: URL,
        method: String,
        body: [String: Any]?,
        retryCount: Int,
        completion: @escaping (Result<Data, ARRecognitionError>) -> Void
    ) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutInterval
        
        // 设置请求体
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(.failure(.decodingError(error)))
                return
            }
        }
        
        print("🌐 [ARRecognitionService] 请求: \(method) \(url.absoluteString)")
        
        let task = session.dataTask(with: request) { data, response, error in
            // 处理错误
            if let error = error {
                print("❌ [ARRecognitionService] 网络错误: \(error.localizedDescription)")
                
                // 重试机制
                if retryCount < self.maxRetryCount {
                    print("🔄 [ARRecognitionService] 重试请求 (\(retryCount + 1)/\(self.maxRetryCount))")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.performRequest(
                            url: url,
                            method: method,
                            body: body,
                            retryCount: retryCount + 1,
                            completion: completion
                        )
                    }
                } else {
                    completion(.failure(.networkError(error)))
                }
                return
            }
            
            // 检查响应
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            
            // 检查状态码
            guard (200...299).contains(httpResponse.statusCode) else {
                let statusCode = httpResponse.statusCode
                print("❌ [ARRecognitionService] HTTP错误: \(statusCode)")
                
                // 重试机制（仅对5xx错误重试）
                if (500...599).contains(statusCode) && retryCount < self.maxRetryCount {
                    print("🔄 [ARRecognitionService] 重试请求 (\(retryCount + 1)/\(self.maxRetryCount))")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.performRequest(
                            url: url,
                            method: method,
                            body: body,
                            retryCount: retryCount + 1,
                            completion: completion
                        )
                    }
                } else {
                    completion(.failure(.apiError("HTTP \(statusCode)")))
                }
                return
            }
            
            // 检查数据
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            print("✅ [ARRecognitionService] 请求成功")
            completion(.success(data))
        }
        
        task.resume()
    }
}

// MARK: - POI扩展：转换为字典

extension POI {
    /// 将POI对象转换为字典（用于缓存）
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "poi_id": poiId,
            "name": name,
            "latitude": latitude,
            "longitude": longitude
        ]
        
        if let address = address {
            dict["address"] = address
        }
        if let description = description {
            dict["description"] = description
        }
        if let poiType = poiType {
            dict["poi_type"] = poiType
        }
        if let typeCode = typeCode {
            dict["type_code"] = typeCode
        }
        if let distance = distance {
            dict["distance"] = distance
        }
        if let phone = phone {
            dict["phone"] = phone
        }
        if let website = website {
            dict["website"] = website
        }
        if let businessArea = businessArea {
            dict["business_area"] = businessArea
        }
        if let province = province {
            dict["province"] = province
        }
        if let city = city {
            dict["city"] = city
        }
        if let district = district {
            dict["district"] = district
        }
        if let rating = rating {
            dict["rating"] = rating
        }
        if let images = images {
            dict["images"] = images
        }
        
        return dict
    }
}

