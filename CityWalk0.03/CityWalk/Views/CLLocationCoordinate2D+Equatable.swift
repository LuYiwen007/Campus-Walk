import CoreLocation

// 注意：这是一个临时扩展，直到 CoreLocation 框架正式支持 Equatable
// 如果未来框架版本添加了 Equatable 支持，此扩展可能会产生冲突
@available(iOS 13.0, *)
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
