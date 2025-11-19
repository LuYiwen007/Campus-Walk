//
//  POICache.swift
//  CityWalk
//
//  Created on 2025/1/20.
//

import Foundation
import SwiftData
import CoreLocation

/// POI查询缓存模型
/// 对应后端MySQL数据库的poi_caches表
/// 用于缓存附近POI查询结果，减少重复API调用
@Model
final class POICache {
    /// 缓存中心点纬度
    var latitude: Double
    
    /// 缓存中心点经度
    var longitude: Double
    
    /// 缓存半径（米）
    var radius: Double
    
    /// 朝向（用于缓存键，可选）
    var heading: Double?
    
    /// 视野角度（用于缓存键，可选）
    var fov: Double?
    
    /// 缓存键（基于位置和参数生成的唯一键）
    var cacheKey: String
    
    /// 缓存的POI数据（JSON字符串格式）
    var cacheDataJSON: String
    
    /// 命中次数
    var hitCount: Int
    
    /// 创建时间
    var createdAt: Date
    
    /// 过期时间
    var expiresAt: Date
    
    /// 初始化POI缓存
    /// - Parameters:
    ///   - latitude: 缓存中心点纬度
    ///   - longitude: 缓存中心点经度
    ///   - radius: 缓存半径（米）
    ///   - heading: 朝向（可选）
    ///   - fov: 视野角度（可选）
    ///   - cacheKey: 缓存键（如果提供则使用，否则自动生成）
    init(
        latitude: Double,
        longitude: Double,
        radius: Double,
        heading: Double? = nil,
        fov: Double? = nil,
        cacheKey: String? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.heading = heading
        self.fov = fov
        self.hitCount = 0
        self.createdAt = Date()
        
        // 生成缓存键
        if let key = cacheKey {
            self.cacheKey = key
        } else {
            self.cacheKey = POICache.generateCacheKey(
                latitude: latitude,
                longitude: longitude,
                radius: radius,
                heading: heading,
                fov: fov
            )
        }
        
        // 设置默认过期时间（30分钟后）
        self.expiresAt = Date().addingTimeInterval(1800)
        self.cacheDataJSON = "[]"  // 默认空数组
    }
    
    /// 获取缓存中心点坐标
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// 检查缓存是否过期
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    /// 检查缓存是否有效（未过期）
    var isValid: Bool {
        !isExpired
    }
    
    /// 获取剩余有效时间（秒）
    var remainingTime: TimeInterval {
        max(0, expiresAt.timeIntervalSinceNow)
    }
    
    /// 设置过期时间
    /// - Parameter timeInterval: 过期时间间隔（秒），默认1800秒（30分钟）
    func setExpiration(timeInterval: TimeInterval = 1800) {
        self.expiresAt = Date().addingTimeInterval(timeInterval)
    }
    
    /// 增加命中次数
    func incrementHitCount() {
        self.hitCount += 1
    }
    
    /// 获取缓存的POI数据（解析JSON）
    var cacheData: [[String: Any]] {
        get {
            guard let data = cacheDataJSON.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }
            return json
        }
        set {
            if let data = try? JSONSerialization.data(withJSONObject: newValue),
               let json = String(data: data, encoding: .utf8) {
                self.cacheDataJSON = json
            }
        }
    }
    
    /// 检查位置是否在缓存范围内
    /// - Parameter coordinate: 要检查的坐标
    /// - Returns: 是否在缓存范围内
    func contains(coordinate: CLLocationCoordinate2D) -> Bool {
        let cacheLocation = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = cacheLocation.distance(from: targetLocation)
        return distance <= radius
    }
}

// MARK: - 扩展：缓存键生成
extension POICache {
    /// 生成缓存键
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    ///   - radius: 半径
    ///   - heading: 朝向（可选）
    ///   - fov: 视野角度（可选）
    /// - Returns: 缓存键字符串
    static func generateCacheKey(
        latitude: Double,
        longitude: Double,
        radius: Double,
        heading: Double? = nil,
        fov: Double? = nil
    ) -> String {
        // 将位置四舍五入到50米精度（减少缓存碎片）
        let latRounded = round(latitude * 1000) / 1000  // 约111米精度
        let lonRounded = round(longitude * 1000) / 1000
        
        // 半径四舍五入到50米
        let radiusRounded = round(radius / 50) * 50
        
        var key = "poi_\(latRounded)_\(lonRounded)_\(radiusRounded)"
        
        // 如果提供了朝向，四舍五入到10度
        if let heading = heading {
            let headingRounded = round(heading / 10) * 10
            key += "_h\(Int(headingRounded))"
        }
        
        // 如果提供了视野角度
        if let fov = fov {
            key += "_f\(Int(fov))"
        }
        
        return key
    }
}

// MARK: - 扩展：从字典创建POICache
extension POICache {
    /// 从字典创建POICache（用于解析后端API返回）
    /// - Parameter dict: 包含缓存信息的字典
    /// - Returns: POICache对象，如果数据无效则返回nil
    static func from(dict: [String: Any]) -> POICache? {
        guard let lat = dict["latitude"] as? Double ?? (dict["lat"] as? String).flatMap(Double.init),
              let lon = dict["longitude"] as? Double ?? (dict["lon"] as? String).flatMap(Double.init),
              let radius = dict["radius"] as? Double ?? (dict["radius"] as? String).flatMap(Double.init),
              let cacheKey = dict["cache_key"] as? String ?? dict["cacheKey"] as? String else {
            return nil
        }
        
        let cache = POICache(
            latitude: lat,
            longitude: lon,
            radius: radius,
            heading: dict["heading"] as? Double ?? (dict["heading"] as? String).flatMap(Double.init),
            fov: dict["fov"] as? Double ?? (dict["fov"] as? String).flatMap(Double.init),
            cacheKey: cacheKey
        )
        
        // 设置缓存数据
        if let cacheData = dict["cache_data"] as? [[String: Any]] ?? dict["cacheData"] as? [[String: Any]] {
            cache.cacheData = cacheData
        }
        
        // 设置命中次数
        if let hitCount = dict["hit_count"] as? Int ?? dict["hitCount"] as? Int {
            cache.hitCount = hitCount
        }
        
        // 处理时间戳
        if let expiresAtStr = dict["expires_at"] as? String ?? dict["expiresAt"] as? String {
            let formatter = ISO8601DateFormatter()
            if let expiresAt = formatter.date(from: expiresAtStr) {
                cache.expiresAt = expiresAt
            }
        }
        
        if let createdAtStr = dict["created_at"] as? String ?? dict["createdAt"] as? String {
            let formatter = ISO8601DateFormatter()
            if let createdAt = formatter.date(from: createdAtStr) {
                cache.createdAt = createdAt
            }
        }
        
        return cache
    }
}

