//
//  POIManager.swift
//  CityWalk
//
//  Created on 2025/1/20.
//

import Foundation
import SwiftData
import CoreLocation

/// POI数据管理器
/// 负责POI数据的本地存储、查询、更新等操作
@MainActor
class POIManager: ObservableObject {
    static let shared = POIManager()
    
    private var modelContext: ModelContext?
    
    private init() {}
    
    /// 设置ModelContext（需要在应用启动时调用）
    /// - Parameter context: SwiftData的ModelContext
    func setup(context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - 保存POI
    
    /// 保存POI到本地数据库
    /// - Parameter poi: 要保存的POI对象
    /// - Returns: 是否保存成功
    @discardableResult
    func savePOI(_ poi: POI) -> Bool {
        guard let context = modelContext else {
            print("❌ [POIManager] ModelContext未设置")
            return false
        }
        
        // 检查是否已存在相同poiId的POI
        if let existingPOI = fetchPOI(poiId: poi.poiId) {
            // 更新现有POI
            existingPOI.update(from: poi)
            print("✅ [POIManager] 更新POI: \(poi.name) (ID: \(poi.poiId))")
        } else {
            // 插入新POI
            context.insert(poi)
            print("✅ [POIManager] 保存新POI: \(poi.name) (ID: \(poi.poiId))")
        }
        
        do {
            try context.save()
            return true
        } catch {
            print("❌ [POIManager] 保存POI失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 批量保存POI
    /// - Parameter pois: POI数组
    /// - Returns: 成功保存的数量
    @discardableResult
    func savePOIs(_ pois: [POI]) -> Int {
        var successCount = 0
        for poi in pois {
            if savePOI(poi) {
                successCount += 1
            }
        }
        print("✅ [POIManager] 批量保存: \(successCount)/\(pois.count)")
        return successCount
    }
    
    // MARK: - 查询POI
    
    /// 根据POI ID查询
    /// - Parameter poiId: POI唯一标识
    /// - Returns: POI对象，如果不存在则返回nil
    func fetchPOI(poiId: String) -> POI? {
        guard let context = modelContext else {
            print("❌ [POIManager] ModelContext未设置")
            return nil
        }
        
        let descriptor = FetchDescriptor<POI>(
            predicate: #Predicate { $0.poiId == poiId }
        )
        
        do {
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            print("❌ [POIManager] 查询POI失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 检查POI是否存在
    /// - Parameter poiId: POI唯一标识
    /// - Returns: 是否存在
    func hasPOI(poiId: String) -> Bool {
        return fetchPOI(poiId: poiId) != nil
    }
    
    /// 查询所有POI
    /// - Returns: POI数组
    func fetchAllPOIs() -> [POI] {
        guard let context = modelContext else {
            print("❌ [POIManager] ModelContext未设置")
            return []
        }
        
        let descriptor = FetchDescriptor<POI>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ [POIManager] 查询所有POI失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 根据位置查询附近的POI
    /// - Parameters:
    ///   - coordinate: 中心坐标
    ///   - radius: 搜索半径（米）
    ///   - limit: 返回数量限制
    /// - Returns: 附近的POI数组，按距离排序
    func fetchNearbyPOIs(
        coordinate: CLLocationCoordinate2D,
        radius: Double = 1000,
        limit: Int = 20
    ) -> [POI] {
        guard let context = modelContext else {
            print("❌ [POIManager] ModelContext未设置")
            return []
        }
        
        let centerLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        let descriptor = FetchDescriptor<POI>()
        
        do {
            let allPOIs = try context.fetch(descriptor)
            
            // 计算距离并筛选
            let nearbyPOIs = allPOIs
                .map { poi -> (POI, Double) in
                    let poiLocation = CLLocation(latitude: poi.latitude, longitude: poi.longitude)
                    let distance = centerLocation.distance(from: poiLocation)
                    return (poi, distance)
                }
                .filter { $0.1 <= radius }  // 筛选在半径内的
                .sorted { $0.1 < $1.1 }     // 按距离排序
                .prefix(limit)               // 限制数量
                .map { $0.0 }               // 提取POI
            
            return Array(nearbyPOIs)
        } catch {
            print("❌ [POIManager] 查询附近POI失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 根据类型查询POI
    /// - Parameter type: POI类型
    /// - Returns: POI数组
    func fetchPOIsByType(_ type: String) -> [POI] {
        guard let context = modelContext else {
            print("❌ [POIManager] ModelContext未设置")
            return []
        }
        
        let descriptor = FetchDescriptor<POI>(
            predicate: #Predicate { $0.poiType == type },
            sortBy: [SortDescriptor(\.name)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ [POIManager] 按类型查询POI失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 根据城市查询POI
    /// - Parameter city: 城市名称
    /// - Returns: POI数组
    func fetchPOIsByCity(_ city: String) -> [POI] {
        guard let context = modelContext else {
            print("❌ [POIManager] ModelContext未设置")
            return []
        }
        
        let descriptor = FetchDescriptor<POI>(
            predicate: #Predicate { $0.city == city },
            sortBy: [SortDescriptor(\.name)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ [POIManager] 按城市查询POI失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 搜索POI（根据名称）
    /// - Parameter keyword: 搜索关键词
    /// - Returns: POI数组
    func searchPOIs(keyword: String) -> [POI] {
        guard let context = modelContext else {
            print("❌ [POIManager] ModelContext未设置")
            return []
        }
        
        let lowerKeyword = keyword.lowercased()
        let descriptor = FetchDescriptor<POI>()
        
        do {
            let allPOIs = try context.fetch(descriptor)
            return allPOIs.filter { poi in
                poi.name.lowercased().contains(lowerKeyword) ||
                (poi.address?.lowercased().contains(lowerKeyword) ?? false) ||
                (poi.description?.lowercased().contains(lowerKeyword) ?? false)
            }
        } catch {
            print("❌ [POIManager] 搜索POI失败: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - 删除POI
    
    /// 删除POI
    /// - Parameter poi: 要删除的POI对象
    /// - Returns: 是否删除成功
    @discardableResult
    func deletePOI(_ poi: POI) -> Bool {
        guard let context = modelContext else {
            print("❌ [POIManager] ModelContext未设置")
            return false
        }
        
        context.delete(poi)
        
        do {
            try context.save()
            print("✅ [POIManager] 删除POI: \(poi.name)")
            return true
        } catch {
            print("❌ [POIManager] 删除POI失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 根据POI ID删除
    /// - Parameter poiId: POI唯一标识
    /// - Returns: 是否删除成功
    @discardableResult
    func deletePOI(poiId: String) -> Bool {
        guard let poi = fetchPOI(poiId: poiId) else {
            return false
        }
        return deletePOI(poi)
    }
    
    /// 删除所有POI
    /// - Returns: 删除的数量
    @discardableResult
    func deleteAllPOIs() -> Int {
        let allPOIs = fetchAllPOIs()
        var deletedCount = 0
        
        for poi in allPOIs {
            if deletePOI(poi) {
                deletedCount += 1
            }
        }
        
        print("✅ [POIManager] 删除所有POI: \(deletedCount)个")
        return deletedCount
    }
    
    // MARK: - 统计信息
    
    /// 获取POI总数
    /// - Returns: POI数量
    func getPOICount() -> Int {
        guard let context = modelContext else {
            return 0
        }
        
        let descriptor = FetchDescriptor<POI>()
        
        do {
            return try context.fetchCount(descriptor)
        } catch {
            print("❌ [POIManager] 获取POI数量失败: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// 获取按类型分组的POI数量
    /// - Returns: 类型和数量的字典
    func getPOICountByType() -> [String: Int] {
        let allPOIs = fetchAllPOIs()
        var countDict: [String: Int] = [:]
        
        for poi in allPOIs {
            let type = poi.poiType ?? "未知"
            countDict[type, default: 0] += 1
        }
        
        return countDict
    }
    
    // MARK: - 缓存管理
    
    /// 检查缓存是否存在且有效
    /// - Parameters:
    ///   - coordinate: 查询位置坐标
    ///   - radius: 搜索半径
    ///   - heading: 朝向（可选）
    ///   - fov: 视野角度（可选）
    /// - Returns: 有效的缓存对象，如果不存在或已过期则返回nil
    func checkCache(
        coordinate: CLLocationCoordinate2D,
        radius: Double,
        heading: Double? = nil,
        fov: Double? = nil
    ) -> POICache? {
        guard let context = modelContext else {
            print("❌ [POIManager] ModelContext未设置")
            return nil
        }
        
        let cacheKey = POICache.generateCacheKey(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radius: radius,
            heading: heading,
            fov: fov
        )
        
        let descriptor = FetchDescriptor<POICache>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        
        do {
            let caches = try context.fetch(descriptor)
            if let cache = caches.first, cache.isValid {
                // 增加命中次数
                cache.incrementHitCount()
                try context.save()
                print("✅ [POIManager] 缓存命中: \(cacheKey)")
                return cache
            } else if let cache = caches.first {
                // 缓存已过期，删除
                context.delete(cache)
                try context.save()
                print("⚠️ [POIManager] 缓存已过期，已删除: \(cacheKey)")
            }
        } catch {
            print("❌ [POIManager] 检查缓存失败: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// 保存缓存
    /// - Parameters:
    ///   - coordinate: 缓存中心点坐标
    ///   - radius: 缓存半径
    ///   - cacheData: 要缓存的POI数据（字典数组）
    ///   - heading: 朝向（可选）
    ///   - fov: 视野角度（可选）
    ///   - expirationTime: 过期时间间隔（秒），默认1800秒（30分钟）
    /// - Returns: 是否保存成功
    @discardableResult
    func saveCache(
        coordinate: CLLocationCoordinate2D,
        radius: Double,
        cacheData: [[String: Any]],
        heading: Double? = nil,
        fov: Double? = nil,
        expirationTime: TimeInterval = 1800
    ) -> Bool {
        guard let context = modelContext else {
            print("❌ [POIManager] ModelContext未设置")
            return false
        }
        
        let cacheKey = POICache.generateCacheKey(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radius: radius,
            heading: heading,
            fov: fov
        )
        
        // 检查是否已存在相同键的缓存
        let descriptor = FetchDescriptor<POICache>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        
        do {
            let existingCaches = try context.fetch(descriptor)
            
            if let existingCache = existingCaches.first {
                // 更新现有缓存
                existingCache.cacheData = cacheData
                existingCache.setExpiration(timeInterval: expirationTime)
                existingCache.hitCount = 0  // 重置命中次数
                print("✅ [POIManager] 更新缓存: \(cacheKey)")
            } else {
                // 创建新缓存
                let cache = POICache(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    radius: radius,
                    heading: heading,
                    fov: fov,
                    cacheKey: cacheKey
                )
                cache.cacheData = cacheData
                cache.setExpiration(timeInterval: expirationTime)
                context.insert(cache)
                print("✅ [POIManager] 保存新缓存: \(cacheKey)")
            }
            
            try context.save()
            return true
        } catch {
            print("❌ [POIManager] 保存缓存失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 清理过期的缓存
    /// - Returns: 清理的数量
    @discardableResult
    func clearExpiredCache() -> Int {
        guard let context = modelContext else {
            print("❌ [POIManager] ModelContext未设置")
            return 0
        }
        
        let descriptor = FetchDescriptor<POICache>()
        
        do {
            let allCaches = try context.fetch(descriptor)
            let expiredCaches = allCaches.filter { $0.isExpired }
            
            for cache in expiredCaches {
                context.delete(cache)
            }
            
            if !expiredCaches.isEmpty {
                try context.save()
                print("✅ [POIManager] 清理过期缓存: \(expiredCaches.count)个")
            }
            
            return expiredCaches.count
        } catch {
            print("❌ [POIManager] 清理过期缓存失败: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// 删除所有缓存
    /// - Returns: 删除的数量
    @discardableResult
    func clearAllCache() -> Int {
        guard let context = modelContext else {
            print("❌ [POIManager] ModelContext未设置")
            return 0
        }
        
        let descriptor = FetchDescriptor<POICache>()
        
        do {
            let allCaches = try context.fetch(descriptor)
            
            for cache in allCaches {
                context.delete(cache)
            }
            
            if !allCaches.isEmpty {
                try context.save()
                print("✅ [POIManager] 删除所有缓存: \(allCaches.count)个")
            }
            
            return allCaches.count
        } catch {
            print("❌ [POIManager] 删除所有缓存失败: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// 获取缓存统计信息
    /// - Returns: 包含缓存总数、有效缓存数、过期缓存数的元组
    func getCacheStats() -> (total: Int, valid: Int, expired: Int) {
        guard let context = modelContext else {
            return (0, 0, 0)
        }
        
        let descriptor = FetchDescriptor<POICache>()
        
        do {
            let allCaches = try context.fetch(descriptor)
            let validCaches = allCaches.filter { $0.isValid }
            let expiredCaches = allCaches.filter { $0.isExpired }
            
            return (allCaches.count, validCaches.count, expiredCaches.count)
        } catch {
            print("❌ [POIManager] 获取缓存统计失败: \(error.localizedDescription)")
            return (0, 0, 0)
        }
    }
    
    /// 获取缓存命中率最高的缓存（用于分析）
    /// - Parameter limit: 返回数量限制
    /// - Returns: 缓存和命中次数的元组数组
    func getMostHitCaches(limit: Int = 10) -> [(POICache, Int)] {
        guard let context = modelContext else {
            return []
        }
        
        let descriptor = FetchDescriptor<POICache>(
            sortBy: [SortDescriptor(\.hitCount, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            let caches = try context.fetch(descriptor)
            return caches.map { ($0, $0.hitCount) }
        } catch {
            print("❌ [POIManager] 获取高命中缓存失败: \(error.localizedDescription)")
            return []
        }
    }
}

