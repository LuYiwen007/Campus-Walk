//
//  POI.swift
//  CityWalk
//
//  Created on 2025/1/20.
//

import Foundation
import SwiftData
import CoreLocation

/// POI（建筑/地点）数据模型
/// 对应后端MySQL数据库的pois表
@Model
final class POI {
    /// POI唯一标识（高德地图的uid）
    var poiId: String
    
    /// 建筑/地点名称
    var name: String
    
    /// 纬度
    var latitude: Double
    
    /// 经度
    var longitude: Double
    
    /// 详细地址
    var address: String?
    
    /// 描述信息
    var description: String?
    
    /// 类型：building, landmark, restaurant等
    var poiType: String?
    
    /// 高德地图类型编码
    var typeCode: String?
    
    /// 距离（米）
    var distance: Double?
    
    /// 联系电话
    var phone: String?
    
    /// 网址
    var website: String?
    
    /// 所属商圈
    var businessArea: String?
    
    /// 省份
    var province: String?
    
    /// 城市
    var city: String?
    
    /// 区县
    var district: String?
    
    /// 区域编码
    var adcode: String?
    
    /// 评分（0-5）
    var rating: Double?
    
    /// 图片URL列表（JSON字符串，存储为String）
    var imagesJSON: String?
    
    /// 创建时间
    var createdAt: Date
    
    /// 更新时间
    var updatedAt: Date
    
    /// 初始化POI模型
    /// - Parameters:
    ///   - poiId: POI唯一标识（必填）
    ///   - name: 名称（必填）
    ///   - latitude: 纬度（必填）
    ///   - longitude: 经度（必填）
    ///   - address: 地址（可选）
    ///   - description: 描述（可选）
    init(
        poiId: String,
        name: String,
        latitude: Double,
        longitude: Double,
        address: String? = nil,
        description: String? = nil
    ) {
        self.poiId = poiId
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.description = description
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// 获取坐标
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// 获取图片URL列表
    var images: [String] {
        get {
            guard let json = imagesJSON,
                  let data = json.data(using: .utf8),
                  let urls = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return urls
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                imagesJSON = json
            }
        }
    }
    
    /// 计算到指定位置的距离（米）
    /// - Parameter coordinate: 目标坐标
    /// - Returns: 距离（米）
    func distance(to coordinate: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location1.distance(from: location2)
    }
    
    /// 更新POI信息
    /// - Parameter other: 包含更新信息的POI对象
    func update(from other: POI) {
        self.name = other.name
        self.address = other.address
        self.description = other.description
        self.poiType = other.poiType
        self.typeCode = other.typeCode
        self.distance = other.distance
        self.phone = other.phone
        self.website = other.website
        self.businessArea = other.businessArea
        self.province = other.province
        self.city = other.city
        self.district = other.district
        self.adcode = other.adcode
        self.rating = other.rating
        self.imagesJSON = other.imagesJSON
        self.updatedAt = Date()
    }
}

// MARK: - 扩展：从后端API数据创建POI
extension POI {
    /// 从字典创建POI（用于解析后端API返回）
    /// - Parameter dict: 包含POI信息的字典
    /// - Returns: POI对象，如果数据无效则返回nil
    static func from(dict: [String: Any]) -> POI? {
        guard let poiId = dict["poi_id"] as? String ?? dict["poiId"] as? String,
              let name = dict["name"] as? String,
              let lat = dict["latitude"] as? Double ?? (dict["lat"] as? String).flatMap(Double.init),
              let lon = dict["longitude"] as? Double ?? (dict["lon"] as? String).flatMap(Double.init) else {
            return nil
        }
        
        let poi = POI(
            poiId: poiId,
            name: name,
            latitude: lat,
            longitude: lon,
            address: dict["address"] as? String,
            description: dict["description"] as? String
        )
        
        // 设置可选字段
        poi.poiType = dict["poi_type"] as? String ?? dict["poiType"] as? String ?? dict["type"] as? String
        poi.typeCode = dict["type_code"] as? String ?? dict["typeCode"] as? String
        poi.distance = dict["distance"] as? Double ?? (dict["distance"] as? String).flatMap(Double.init)
        poi.phone = dict["phone"] as? String ?? dict["tel"] as? String
        poi.website = dict["website"] as? String
        poi.businessArea = dict["business_area"] as? String ?? dict["businessArea"] as? String
        poi.province = dict["province"] as? String
        poi.city = dict["city"] as? String
        poi.district = dict["district"] as? String
        poi.adcode = dict["adcode"] as? String
        poi.rating = dict["rating"] as? Double ?? (dict["rating"] as? String).flatMap(Double.init)
        
        // 处理图片列表
        if let images = dict["images"] as? [String] {
            poi.images = images
        } else if let images = dict["images"] as? [[String: Any]] {
            // 如果是对象数组，提取URL
            poi.images = images.compactMap { $0["url"] as? String }
        }
        
        return poi
    }
}

