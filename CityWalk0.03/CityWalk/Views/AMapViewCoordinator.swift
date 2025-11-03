import SwiftUI
import AMapNaviKit
import AMapSearchKit
import CoreLocation
import AMapLocationKit

extension AMapViewRepresentable {
    class Coordinator: NSObject, MAMapViewDelegate, AMapSearchDelegate, CustomSearchBarViewDelegate, AMapLocationManagerDelegate, AMapNaviWalkViewDelegate {
        var parent: AMapViewRepresentable
        var search: AMapSearchAPI?
        var mapView: MAMapView?
        var currentPOI: AMapPOI?
        let infoCardView = InfoCardView()
        var currentDest: CLLocationCoordinate2D? = nil
        var latestUserLocation: CLLocationCoordinate2D?
        var lastRouteStart: CLLocationCoordinate2D? = nil
        var lastRouteDest: CLLocationCoordinate2D? = nil
        var startAnnotation: MAPointAnnotation?
        var endAnnotation: MAPointAnnotation?
        var arButton: UIButton?
        
        // 导航UI
        var topInfoView: UIView?
        var instructionLabel: UILabel?
        var bottomNavView: UIView?
        var exitButton: UIButton?
        var remainLabel: UILabel?
        var isNavigating: Bool = false
        
        // 路线数据存储
        var currentRouteDistance: Double?
        var currentRouteDuration: Double?
        
        // 高德导航视图引用
        var navigationView: AMapNaviWalkView?
        
        init(_ parent: AMapViewRepresentable) {
            self.parent = parent
            super.init()
            self.search = AMapSearchAPI()
            self.search?.delegate = self
            print("🔍 [地图API] 搜索API已初始化，代理已设置")
            infoCardView.isHidden = true
            infoCardView.onRoute = { [weak self] in
                guard let self = self, let dest = self.currentDest else { return }
                print("点击导航按钮，启动步行导航到：\(dest)")
                self.startWalkingNavigation(to: dest)
            }
        }
        
        // 定位按钮
        @objc func locateUser() {
            guard let mapView = mapView else { return }
            
            print("📍 [定位] 用户点击定位按钮")
            
            // 如果已经有位置信息，直接跳转
            if let userLoc = mapView.userLocation.location?.coordinate {
                print("📍 [定位] 使用已有位置: \(userLoc)")
                mapView.setCenter(userLoc, animated: true)
                return
            }
            
            // 如果没有位置信息，主动请求定位
            print("📍 [定位] 主动请求定位...")
            let locationManager = AMapLocationManager()
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.locationTimeout = 10
            
            locationManager.requestLocation(withReGeocode: false) { location, _, error in
                if let error = error {
                    print("❌ [定位] 定位失败: \(error.localizedDescription)")
                    print("🔍 [定位] 错误详情: \(error)")
                    print("🔍 [定位] 错误代码: \(error._code)")
                    return
                }
                
                if let loc = location {
                    print("✅ [定位] 定位成功: \(loc.coordinate)")
                    DispatchQueue.main.async {
                        mapView.setCenter(loc.coordinate, animated: true)
                    }
                }
            }
        }
        
        // 搜索功能
        func didTapSearch(with keyword: String) {
            guard !keyword.isEmpty else { return }
            let request = AMapPOIKeywordsSearchRequest()
            request.keywords = keyword
            request.city = nil
            search?.aMapPOIKeywordsSearch(request)
        }
        
        // POI搜索回调
        func onPOISearchDone(_ request: AMapPOISearchBaseRequest!, response: AMapPOISearchResponse!) {
            guard let mapView = mapView else { return }
            guard let poi = response.pois.first else {
                print("[地图] POI 搜索无结果")
                return
            }
            
            let dest = CLLocationCoordinate2D(latitude: CLLocationDegrees(poi.location.latitude), 
                                            longitude: CLLocationDegrees(poi.location.longitude))
            
            DispatchQueue.main.async {
                mapView.setCenter(dest, animated: true)
                mapView.setZoomLevel(16, animated: true)
            }
            
            // 显示信息卡片
            var distanceText: String? = nil
            if let user = self.latestUserLocation ?? mapView.userLocation.location?.coordinate {
                let u = CLLocation(latitude: user.latitude, longitude: user.longitude)
                let d = CLLocation(latitude: dest.latitude, longitude: dest.longitude)
                let meters = u.distance(from: d)
                if meters >= 1000 {
                    distanceText = String(format: "%.1f km", meters/1000)
                } else {
                    distanceText = String(format: "%.0f m", meters)
                }
            }
            
            DispatchQueue.main.async {
                self.infoCardView.configure(title: poi.name, address: poi.address, distance: distanceText)
                self.infoCardView.isHidden = false
            }
            
            currentDest = dest
        }
        
        // 步行路线规划
        func searchWalkingRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, on mapView: MAMapView) {
            print("[地图] 规划步行路线 from=\(origin), to=\(destination)")
            let request = AMapWalkingRouteSearchRequest()
            request.origin = AMapGeoPoint.location(withLatitude: CGFloat(origin.latitude), longitude: CGFloat(origin.longitude))
            request.destination = AMapGeoPoint.location(withLatitude: CGFloat(destination.latitude), longitude: CGFloat(destination.longitude))
            request.showFieldsType = AMapWalkingRouteShowFieldType.all
            search?.aMapWalkingRouteSearch(request)
        }
        
        // MARK: - 地图视图查找辅助方法
        
        /// 深度搜索地图视图
        func findMapView(in view: UIView) -> MAMapView? {
            // 首先检查当前视图
            if let mapView = view as? MAMapView {
                return mapView
            }
            
            // 递归搜索所有子视图
            for subview in view.subviews {
                if let mapView = findMapView(in: subview) {
                    return mapView
                }
            }
            
            return nil
        }
        
        /// 调试视图层次结构
        func debugViewHierarchy(_ view: UIView, level: Int) {
            let indent = String(repeating: "  ", count: level)
            print("\(indent)\(type(of: view)): \(view.frame)")
            
            for subview in view.subviews {
                debugViewHierarchy(subview, level: level + 1)
            }
        }
        
        /// 尝试直接设置地图中心
        func tryDirectSetMapCenter(_ walkView: AMapNaviWalkView, centerCoordinate: CLLocationCoordinate2D) {
            print("🗺️ [高德导航] 尝试直接设置地图中心: \(centerCoordinate)")
            
            // 由于AMapNaviWalkView没有直接的setCenter方法，我们尝试其他方式
            print("⚠️ [高德导航] AMapNaviWalkView 不支持直接设置中心")
            
            // 尝试使用高德导航管理器的路线规划回调来设置位置
            print("🔄 [高德导航] 尝试通过路线规划回调设置位置")
            self.setMapCenterViaRoutePlanning(centerCoordinate: centerCoordinate)
            
            // 尝试延迟再次搜索地图视图
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                print("🔄 [高德导航] 延迟3秒后再次尝试查找地图视图")
                if let mapView = self.findMapView(in: walkView) {
                    let region = MACoordinateRegion(
                        center: centerCoordinate,
                        span: MACoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    )
                    mapView.setRegion(region, animated: true)
                    print("✅ [高德导航] 延迟设置地图区域成功")
                } else {
                    print("❌ [高德导航] 延迟后仍然无法找到地图视图")
                }
            }
        }
        
        /// 通过路线规划回调设置地图中心
        func setMapCenterViaRoutePlanning(centerCoordinate: CLLocationCoordinate2D) {
            // 这个方法会在路线规划成功后自动调用
            print("🗺️ [高德导航] 将通过路线规划回调设置地图中心: \(centerCoordinate)")
        }
        
        // AR导航
        @objc func openARDirect() {
            guard let dest = currentDest else { return }
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let vc = UIHostingController(rootView: ARNavigationView(destination: dest))
                window.rootViewController?.present(vc, animated: true)
            }
        }
        
        // MARK: - 基础地图代理方法
        
        func mapView(_ mapView: MAMapView!, rendererFor overlay: MAOverlay!) -> MAOverlayRenderer! {
            if let polyline = overlay as? MAPolyline {
                let renderer = MAPolylineRenderer(polyline: polyline)
                renderer?.strokeColor = UIColor.systemBlue
                renderer?.lineWidth = 8.0 // 增加线宽使其更明显
                print("🎨 [路线渲染] 创建路线渲染器，线宽: 8.0，颜色: 蓝色")
                return renderer
            }
            return nil
        }
        
        func mapView(_ mapView: MAMapView!, didUpdate userLocation: MAUserLocation!, updatingLocation: Bool) {
            if updatingLocation, let coord = userLocation.location?.coordinate {
                latestUserLocation = coord
            }
        }
    }
}
