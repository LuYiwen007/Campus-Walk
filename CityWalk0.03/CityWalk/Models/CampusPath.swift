import Foundation
import CoreLocation

// 简化的导航管理器 - 只做基础距离计算
class CampusNavigationManager: ObservableObject {
    static let shared = CampusNavigationManager()
    
    init() {
        // 暂时不需要路径点数据
    }
    
    // 计算两点间距离（米）
    func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
}
