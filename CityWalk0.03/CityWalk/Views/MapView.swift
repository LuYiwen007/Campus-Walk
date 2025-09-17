import SwiftUI
import CoreLocation
// import MapKit // 注释掉原有MapKit

// 地图视图组件，支持缩放、定位、用户标注等功能
struct MapView: View {
    @Binding var isExpanded: Bool // 控制地图是否展开
    @Binding var isShowingProfile: Bool // 控制是否显示用户资料
    var sharedMapState: SharedMapState? = nil // 可选的地图状态共享对象
    var routeInfo: String?
    @Binding var destinationLocation: CLLocationCoordinate2D?
    var routeCoordinates: [CLLocationCoordinate2D]? = nil // polyline
    var centerCoordinate: CLLocationCoordinate2D? = nil // 新增地图中心
    @State private var showRouteSheet: Bool = false
    @State private var mapViewId = UUID()
    // 新增：支持外部切换Place
    @Binding var selectedPlaceIndex: Int
    @Binding var startCoordinateBinding: CLLocationCoordinate2D?
    
    // 已切换为高德地图，不再需要MapCameraPosition
    var body: some View {
        let _ = print("[MapView] startCoordinateBinding=\(String(describing: startCoordinateBinding)), destinationLocation=\(String(describing: destinationLocation))")
        let _ = print("[MapView] 渲染，startCoordinate=\(String(describing: startCoordinateBinding))")
        return GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 用高德地图替换原有MapKit地图
                AMapViewRepresentable(routeCoordinates: routeCoordinates, startCoordinate: startCoordinateBinding, destination: destinationLocation, centerCoordinate: centerCoordinate)
                    .id(mapViewId)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                // 右上角自定义定位按钮和底部分界线等UI保留
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.systemGray4))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $showRouteSheet) {
            if let routeInfo = routeInfo {
                RouteDetailView(route: RouteDetailView_Previews.mockRoute, selectedPlaceIndex: $selectedPlaceIndex, onPlaceChange: { idx, coord in
                    startCoordinateBinding = coord
                    // 新增：同步设置destinationLocation为当前Place的nextCoordinate
                    if let route = RouteDetailView_Previews.mockRoute as? Route, idx < route.places.count {
                        destinationLocation = route.places[idx].nextCoordinate
                    }
                })
                    .presentationDetents([.height(UIScreen.main.bounds.height * 0.6), .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            if routeInfo != nil {
                showRouteSheet = true
            }
            // 监听“ShowRouteDetailSheet”通知
            NotificationCenter.default.addObserver(forName: NSNotification.Name("ShowRouteDetailSheet"), object: nil, queue: .main) { _ in
                showRouteSheet = true
            }
        }
        .onChange(of: centerCoordinate?.latitude) { _ in mapViewId = UUID() }
        .onChange(of: centerCoordinate?.longitude) { _ in mapViewId = UUID() }
        .onChange(of: routeCoordinates?.first?.latitude) { _ in mapViewId = UUID() }
        .onChange(of: routeCoordinates?.last?.longitude) { _ in mapViewId = UUID() }
        .onChange(of: routeInfo) { newValue in
            showRouteSheet = newValue != nil
        }
        .onChange(of: startCoordinateBinding) { _ in mapViewId = UUID() }
        .onChange(of: destinationLocation) { _ in mapViewId = UUID() }
    }
} 
