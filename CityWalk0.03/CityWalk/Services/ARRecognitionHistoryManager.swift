//
//  ARRecognitionHistoryManager.swift
//  CityWalk
//
//  Created on 2025/1/20.
//

import Foundation
import SwiftData
import CoreLocation
import UIKit

/// AR识别历史记录管理器
/// 负责识别历史记录的本地存储、查询、统计等操作
@MainActor
class ARRecognitionHistoryManager: ObservableObject {
    static let shared = ARRecognitionHistoryManager()
    
    private var modelContext: ModelContext?
    
    private init() {}
    
    /// 设置ModelContext（需要在应用启动时调用）
    /// - Parameter context: SwiftData的ModelContext
    func setup(context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - 保存识别历史
    
    /// 保存识别历史记录
    /// - Parameter history: 要保存的识别历史记录
    /// - Returns: 是否保存成功
    @discardableResult
    func saveRecognitionHistory(_ history: ARRecognitionHistory) -> Bool {
        guard let context = modelContext else {
            print("❌ [ARRecognitionHistoryManager] ModelContext未设置")
            return false
        }
        
        context.insert(history)
        
        do {
            try context.save()
            print("✅ [ARRecognitionHistoryManager] 保存识别历史: \(history.detectedPOI?.name ?? "未知")")
            return true
        } catch {
            print("❌ [ARRecognitionHistoryManager] 保存识别历史失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 创建并保存识别历史记录
    /// - Parameters:
    ///   - coordinate: 识别位置坐标
    ///   - heading: 设备朝向
    ///   - fov: 视野角度
    ///   - radius: 搜索半径
    ///   - detectedPOI: 识别到的POI
    ///   - confidence: 置信度
    ///   - userId: 用户ID
    ///   - sessionId: 会话ID
    /// - Returns: 创建的识别历史记录
    @discardableResult
    func createAndSaveRecognitionHistory(
        coordinate: CLLocationCoordinate2D,
        heading: Double? = nil,
        fov: Double? = nil,
        radius: Double? = nil,
        detectedPOI: POI? = nil,
        confidence: Double? = nil,
        userId: String? = nil,
        sessionId: String? = nil
    ) -> ARRecognitionHistory? {
        let history = ARRecognitionHistory(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            heading: heading,
            fov: fov,
            radius: radius
        )
        
        history.updateRecognitionResult(poi: detectedPOI, confidence: confidence)
        history.setUserInfo(userId: userId, sessionId: sessionId)
        
        // 设置设备信息
        let deviceModel = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        history.setDeviceInfo(
            deviceInfo: "\(deviceModel) iOS \(systemVersion)",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        )
        
        if saveRecognitionHistory(history) {
            return history
        }
        
        return nil
    }
    
    // MARK: - 查询识别历史
    
    /// 查询所有识别历史记录
    /// - Parameter limit: 返回数量限制
    /// - Returns: 识别历史记录数组，按时间倒序
    func fetchAllHistories(limit: Int? = nil) -> [ARRecognitionHistory] {
        guard let context = modelContext else {
            print("❌ [ARRecognitionHistoryManager] ModelContext未设置")
            return []
        }
        
        var descriptor = FetchDescriptor<ARRecognitionHistory>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        if let limit = limit {
            descriptor.fetchLimit = limit
        }
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ [ARRecognitionHistoryManager] 查询识别历史失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 根据会话ID查询识别历史
    /// - Parameters:
    ///   - sessionId: 会话ID
    ///   - limit: 返回数量限制
    /// - Returns: 识别历史记录数组
    func fetchHistoriesBySession(sessionId: String, limit: Int? = nil) -> [ARRecognitionHistory] {
        guard let context = modelContext else {
            print("❌ [ARRecognitionHistoryManager] ModelContext未设置")
            return []
        }
        
        var descriptor = FetchDescriptor<ARRecognitionHistory>(
            predicate: #Predicate { $0.sessionId == sessionId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        if let limit = limit {
            descriptor.fetchLimit = limit
        }
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ [ARRecognitionHistoryManager] 按会话查询识别历史失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 根据用户ID查询识别历史
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - limit: 返回数量限制
    /// - Returns: 识别历史记录数组
    func fetchHistoriesByUser(userId: String, limit: Int? = nil) -> [ARRecognitionHistory] {
        guard let context = modelContext else {
            print("❌ [ARRecognitionHistoryManager] ModelContext未设置")
            return []
        }
        
        var descriptor = FetchDescriptor<ARRecognitionHistory>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        if let limit = limit {
            descriptor.fetchLimit = limit
        }
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ [ARRecognitionHistoryManager] 按用户查询识别历史失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 根据POI查询识别历史
    /// - Parameters:
    ///   - poiId: POI ID
    ///   - limit: 返回数量限制
    /// - Returns: 识别历史记录数组
    func fetchHistoriesByPOI(poiId: String, limit: Int? = nil) -> [ARRecognitionHistory] {
        guard let context = modelContext else {
            print("❌ [ARRecognitionHistoryManager] ModelContext未设置")
            return []
        }
        
        var descriptor = FetchDescriptor<ARRecognitionHistory>(
            predicate: #Predicate { $0.detectedPOI?.poiId == poiId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        if let limit = limit {
            descriptor.fetchLimit = limit
        }
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ [ARRecognitionHistoryManager] 按POI查询识别历史失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 查询指定日期范围内的识别历史
    /// - Parameters:
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    ///   - limit: 返回数量限制
    /// - Returns: 识别历史记录数组
    func fetchHistoriesByDateRange(
        startDate: Date,
        endDate: Date,
        limit: Int? = nil
    ) -> [ARRecognitionHistory] {
        guard let context = modelContext else {
            print("❌ [ARRecognitionHistoryManager] ModelContext未设置")
            return []
        }
        
        var descriptor = FetchDescriptor<ARRecognitionHistory>(
            predicate: #Predicate { history in
                history.createdAt >= startDate && history.createdAt <= endDate
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        if let limit = limit {
            descriptor.fetchLimit = limit
        }
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ [ARRecognitionHistoryManager] 按日期范围查询识别历史失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 查询今天的识别历史
    /// - Returns: 识别历史记录数组
    func fetchTodayHistories() -> [ARRecognitionHistory] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return fetchHistoriesByDateRange(startDate: startOfDay, endDate: endOfDay)
    }
    
    /// 查询最近的识别历史
    /// - Parameter count: 返回数量
    /// - Returns: 识别历史记录数组
    func fetchRecentHistories(count: Int = 10) -> [ARRecognitionHistory] {
        return fetchAllHistories(limit: count)
    }
    
    // MARK: - 删除识别历史
    
    /// 删除识别历史记录
    /// - Parameter history: 要删除的识别历史记录
    /// - Returns: 是否删除成功
    @discardableResult
    func deleteRecognitionHistory(_ history: ARRecognitionHistory) -> Bool {
        guard let context = modelContext else {
            print("❌ [ARRecognitionHistoryManager] ModelContext未设置")
            return false
        }
        
        context.delete(history)
        
        do {
            try context.save()
            print("✅ [ARRecognitionHistoryManager] 删除识别历史")
            return true
        } catch {
            print("❌ [ARRecognitionHistoryManager] 删除识别历史失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 删除指定日期之前的识别历史
    /// - Parameter date: 截止日期
    /// - Returns: 删除的数量
    @discardableResult
    func deleteHistoriesBefore(date: Date) -> Int {
        let histories = fetchHistoriesByDateRange(
            startDate: Date.distantPast,
            endDate: date
        )
        
        var deletedCount = 0
        for history in histories {
            if deleteRecognitionHistory(history) {
                deletedCount += 1
            }
        }
        
        print("✅ [ARRecognitionHistoryManager] 删除 \(deletedCount) 条历史记录")
        return deletedCount
    }
    
    /// 删除所有识别历史
    /// - Returns: 删除的数量
    @discardableResult
    func deleteAllHistories() -> Int {
        let allHistories = fetchAllHistories()
        var deletedCount = 0
        
        for history in allHistories {
            if deleteRecognitionHistory(history) {
                deletedCount += 1
            }
        }
        
        print("✅ [ARRecognitionHistoryManager] 删除所有识别历史: \(deletedCount)条")
        return deletedCount
    }
    
    // MARK: - 统计信息
    
    /// 获取识别历史总数
    /// - Returns: 总数
    func getHistoryCount() -> Int {
        guard let context = modelContext else {
            return 0
        }
        
        let descriptor = FetchDescriptor<ARRecognitionHistory>()
        
        do {
            return try context.fetchCount(descriptor)
        } catch {
            print("❌ [ARRecognitionHistoryManager] 获取识别历史数量失败: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// 获取今天识别次数
    /// - Returns: 识别次数
    func getTodayCount() -> Int {
        return fetchTodayHistories().count
    }
    
    /// 获取识别到的唯一POI数量
    /// - Returns: POI数量
    func getUniquePOICount() -> Int {
        let allHistories = fetchAllHistories()
        let uniquePOIIds = Set(allHistories.compactMap { $0.detectedPOI?.poiId })
        return uniquePOIIds.count
    }
    
    /// 获取最常识别的POI
    /// - Parameter limit: 返回数量限制
    /// - Returns: POI和识别次数的元组数组
    func getMostRecognizedPOIs(limit: Int = 10) -> [(POI, Int)] {
        let allHistories = fetchAllHistories()
        var poiCountDict: [String: (POI, Int)] = [:]
        
        for history in allHistories {
            guard let poi = history.detectedPOI else { continue }
            let poiId = poi.poiId
            
            if let existing = poiCountDict[poiId] {
                poiCountDict[poiId] = (poi, existing.1 + 1)
            } else {
                poiCountDict[poiId] = (poi, 1)
            }
        }
        
        return Array(poiCountDict.values)
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { ($0.0, $0.1) }
    }
    
    /// 获取平均置信度
    /// - Returns: 平均置信度，如果没有数据则返回nil
    func getAverageConfidence() -> Double? {
        let allHistories = fetchAllHistories()
        let confidences = allHistories.compactMap { $0.confidence }
        
        guard !confidences.isEmpty else {
            return nil
        }
        
        let sum = confidences.reduce(0, +)
        return sum / Double(confidences.count)
    }
}

