import SwiftUI
import CoreLocation
// import MapKit // 注释掉原有MapKit

// 地图视图组件，支持缩放、定位、用户标注等功能
struct MapView: View {
    @Binding var isExpanded: Bool // 控制地图是否展开
    @Binding var isShowingProfile: Bool // 控制是否显示用户资料
    var routeInfo: String?
    @Binding var destinationLocation: CLLocationCoordinate2D?
    var routeCoordinates: [CLLocationCoordinate2D]? = nil // polyline
    var centerCoordinate: CLLocationCoordinate2D? = nil // 新增地图中心
    // showRouteSheet 已移除
    @State private var mapViewId = UUID()
    // 新增：支持外部切换Place
    @Binding var selectedPlaceIndex: Int
    @Binding var startCoordinateBinding: CLLocationCoordinate2D?
    // 新增：导航模式
    @Binding var isNavigationMode: Bool
    /// 由聊天确认路线注入：地名顺序链，地图侧依次 POI 检索后按段请求高德步行路径
    var pendingWalkLegPlaceNames: [String]? = nil
    var onConsumePendingWalkLeg: (() -> Void)? = nil

    // 已切换为高德地图，不再需要MapCameraPosition
    var body: some View {
        let _ = print("[MapView] startCoordinateBinding=\(String(describing: startCoordinateBinding)), destinationLocation=\(String(describing: destinationLocation))")
        let _ = print("[MapView] 渲染，startCoordinate=\(String(describing: startCoordinateBinding))")
        return GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 用高德地图替换原有MapKit地图
                AMapViewRepresentable(
                    startCoordinate: startCoordinateBinding,
                    destination: destinationLocation,
                    centerCoordinate: centerCoordinate,
                    showSearchBar: true,
                    pendingWalkLegPlaceNames: pendingWalkLegPlaceNames,
                    onConsumePendingWalkLeg: onConsumePendingWalkLeg
                )
                    .id(mapViewId)
                    .frame(width: geometry.size.width, height: geometry.size.height)

                // 底部分隔线（不参与点击）
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.systemGray4))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            // 路线详情功能已移除
        }
        .onChange(of: centerCoordinate?.latitude) { _ in mapViewId = UUID() }
        .onChange(of: centerCoordinate?.longitude) { _ in mapViewId = UUID() }
        .onChange(of: routeCoordinates?.first?.latitude) { _ in mapViewId = UUID() }
        .onChange(of: routeCoordinates?.last?.longitude) { _ in mapViewId = UUID() }
        .onChange(of: routeInfo) { newValue in
            // 路线详情功能已移除
        }
        .onChange(of: startCoordinateBinding) { _ in mapViewId = UUID() }
        .onChange(of: destinationLocation) { _ in mapViewId = UUID() }
    }
} 
