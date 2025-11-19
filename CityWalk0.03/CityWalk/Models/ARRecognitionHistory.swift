//
//  ARRecognitionHistory.swift
//  CityWalk
//
//  Created on 2025/1/20.
//

import Foundation
import SwiftData
import CoreLocation

/// AR识别历史记录模型
/// 对应后端MySQL数据库的ar_recognition_records表
@Model
final class ARRecognitionHistory {
    /// 用户ID（如果有用户系统）
    var userId: String?
    
    /// 会话ID
    var sessionId: String?
    
    /// 识别时的纬度
    var latitude: Double
    
    /// 识别时的经度
    var longitude: Double
    
    /// 设备朝向（0-360度）
    var heading: Double?
    
    /// 视野角度（度）
    var fov: Double?
    
    /// 搜索半径（米）
    var radius: Double?
    
    /// 识别到的POI（关联关系）
    var detectedPOI: POI?
    
    /// 识别置信度（0-1）
    var confidence: Double?
    
    /// 识别模式：auto/manual
    var recognitionMode: String
    
    /// 设备信息
    var deviceInfo: String?
    
    /// 应用版本
    var appVersion: String?
    
    /// 创建时间
    var createdAt: Date
    
    /// 初始化AR识别历史记录
    /// - Parameters:
    ///   - latitude: 识别时的纬度（必填）
    ///   - longitude: 识别时的经度（必填）
    ///   - heading: 设备朝向（可选）
    ///   - fov: 视野角度（可选）
    ///   - radius: 搜索半径（可选）
    init(
        latitude: Double,
        longitude: Double,
        heading: Double? = nil,
        fov: Double? = nil,
        radius: Double? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.heading = heading
        self.fov = fov
        self.radius = radius
        self.recognitionMode = "auto"
        self.createdAt = Date()
    }
    
    /// 获取识别位置坐标
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// 获取识别位置
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    /// 更新识别结果
    /// - Parameters:
    ///   - poi: 识别到的POI
    ///   - confidence: 置信度
    func updateRecognitionResult(poi: POI?, confidence: Double?) {
        self.detectedPOI = poi
        self.confidence = confidence
    }
    
    /// 设置用户信息
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - sessionId: 会话ID
    func setUserInfo(userId: String?, sessionId: String?) {
        self.userId = userId
        self.sessionId = sessionId
    }
    
    /// 设置设备信息
    /// - Parameters:
    ///   - deviceInfo: 设备信息
    ///   - appVersion: 应用版本
    func setDeviceInfo(deviceInfo: String?, appVersion: String?) {
        self.deviceInfo = deviceInfo
        self.appVersion = appVersion
    }
}

// MARK: - 扩展：从字典创建ARRecognitionHistory
extension ARRecognitionHistory {
    /// 从字典创建ARRecognitionHistory（用于解析后端API返回）
    /// - Parameter dict: 包含识别记录信息的字典
    /// - Returns: ARRecognitionHistory对象，如果数据无效则返回nil
    static func from(dict: [String: Any]) -> ARRecognitionHistory? {
        guard let lat = dict["latitude"] as? Double ?? (dict["lat"] as? String).flatMap(Double.init),
              let lon = dict["longitude"] as? Double ?? (dict["lon"] as? String).flatMap(Double.init) else {
            return nil
        }
        
        let history = ARRecognitionHistory(
            latitude: lat,
            longitude: lon,
            heading: dict["heading"] as? Double ?? (dict["heading"] as? String).flatMap(Double.init),
            fov: dict["fov"] as? Double ?? (dict["fov"] as? String).flatMap(Double.init),
            radius: dict["radius"] as? Double ?? (dict["radius"] as? String).flatMap(Double.init)
        )
        
        // 设置可选字段
        history.userId = dict["user_id"] as? String ?? dict["userId"] as? String
        history.sessionId = dict["session_id"] as? String ?? dict["sessionId"] as? String
        history.confidence = dict["confidence"] as? Double ?? (dict["confidence"] as? String).flatMap(Double.init)
        history.recognitionMode = dict["recognition_mode"] as? String ?? dict["recognitionMode"] as? String ?? "auto"
        history.deviceInfo = dict["device_info"] as? String ?? dict["deviceInfo"] as? String
        history.appVersion = dict["app_version"] as? String ?? dict["appVersion"] as? String
        
        // 处理时间戳
        if let timestamp = dict["created_at"] as? String ?? dict["createdAt"] as? String {
            let formatter = ISO8601DateFormatter()
            history.createdAt = formatter.date(from: timestamp) ?? Date()
        }
        
        return history
    }
}

