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
    // showRouteSheet 已移除
    @State private var mapViewId = UUID()
    // 新增：支持外部切换Place
    @Binding var selectedPlaceIndex: Int
    @Binding var startCoordinateBinding: CLLocationCoordinate2D?
    // 新增：导航模式
    @Binding var isNavigationMode: Bool
    
    // 高德导航相关状态
    @StateObject private var walkNavManager = WalkingNavigationManager.shared
    @State private var showAMapNavigation = false
    @State private var navigationDestination: CLLocationCoordinate2D? = nil
    
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
                    showSearchBar: true
                )
                    .id(mapViewId)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                // 导航模式切换按钮
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            if isNavigationMode {
                                // 如果已经在导航模式，启动高德导航
                                if let destination = destinationLocation {
                                    navigationDestination = destination
                                    showAMapNavigation = true
                                    walkNavManager.startWalkingNavigation(to: destination)
                                }
                            } else {
                                // 切换导航模式
                                isNavigationMode.toggle()
                            }
                        }) {
                            Image(systemName: isNavigationMode ? "location.fill" : "location")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(isNavigationMode ? Color.blue : Color.gray.opacity(0.7))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                    }
                    Spacer()
                }
                
                // 右上角自定义定位按钮和底部分界线等UI保留
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.systemGray4))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $showAMapNavigation) {
            if let destination = navigationDestination {
                AMapNaviWalkViewRepresentable(
                    isNavigating: $walkNavManager.isNavigating,
                    destination: destination,
                    onNavigationStart: {
                        print("🚀 [MapView] 高德导航开始")
                    },
                    onNavigationStop: {
                        print("🛑 [MapView] 高德导航停止")
                        showAMapNavigation = false
                        isNavigationMode = false
                    }
                )
                .ignoresSafeArea()
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
