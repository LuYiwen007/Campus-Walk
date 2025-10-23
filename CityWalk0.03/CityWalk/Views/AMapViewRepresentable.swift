import SwiftUI
import AMapNaviKit
import AMapSearchKit
import CoreLocation
import AMapLocationKit
import AMapFoundationKit

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct AMapViewRepresentable: UIViewRepresentable {
    // 基本属性
    let startCoordinate: CLLocationCoordinate2D?
    let destination: CLLocationCoordinate2D?
    var centerCoordinate: CLLocationCoordinate2D? = nil
    var showSearchBar: Bool = true
    
    // 导航相关
    @StateObject private var walkNavManager = SimpleNavigationManager.shared
    var onNavigationStart: (() -> Void)? = nil
    var onNavigationStop: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIView {
        print("[AMapViewRepresentable] 创建地图视图")
        let container = UIView(frame: .zero)
        let mapView = MAMapView(frame: .zero)
        
        // 基本地图设置
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .followWithHeading // 启用朝向指示器
        mapView.delegate = context.coordinator
        mapView.zoomLevel = 16
        mapView.isShowTraffic = false
        mapView.isRotateEnabled = false
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true
        
        // 确保用户位置始终可见
        mapView.userLocation.title = "我的位置"
        mapView.userLocation.subtitle = "当前位置"
        
        context.coordinator.mapView = mapView
        
        // 申请位置权限并定位到用户位置
        let locationManager = AMapLocationManager()
        locationManager.delegate = context.coordinator
        
        // 设置定位精度
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.locationTimeout = 10
        locationManager.reGeocodeTimeout = 5
        
        // 申请位置权限
        locationManager.requestLocation(withReGeocode: false) { location, _, error in
            if let error = error {
                print("❌ [定位] 定位失败: \(error.localizedDescription)")
                return
            }
            
            if let loc = location {
                print("✅ [定位] 定位到当前位置：\(loc.coordinate)")
                DispatchQueue.main.async {
                    mapView.setCenter(loc.coordinate, animated: false)
                }
            }
        }
        
        // 设置中心点
        if let start = startCoordinate {
            mapView.setCenter(start, animated: false)
        } else if let dest = destination {
            mapView.setCenter(dest, animated: false)
        }
        
        mapView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: container.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        // 搜索框
        if showSearchBar {
            let searchView = CustomSearchBarView()
            searchView.delegate = context.coordinator
            searchView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(searchView)
            NSLayoutConstraint.activate([
                searchView.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 12),
                searchView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
                searchView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
                searchView.heightAnchor.constraint(equalToConstant: 52)
            ])
        }
        
        // 定位按钮
        let locateBtn = UIButton(type: .custom)
        locateBtn.setImage(UIImage(systemName: "location.fill"), for: .normal)
        locateBtn.backgroundColor = .white
        locateBtn.layer.cornerRadius = 24
        locateBtn.layer.shadowColor = UIColor.black.cgColor
        locateBtn.layer.shadowOpacity = 0.12
        locateBtn.layer.shadowOffset = CGSize(width: 0, height: 2)
        locateBtn.layer.shadowRadius = 6
        locateBtn.translatesAutoresizingMaskIntoConstraints = false
        locateBtn.addTarget(context.coordinator, action: #selector(Coordinator.locateUser), for: .touchUpInside)
        container.addSubview(locateBtn)
        NSLayoutConstraint.activate([
            locateBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            locateBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -90),
            locateBtn.widthAnchor.constraint(equalToConstant: 48),
            locateBtn.heightAnchor.constraint(equalToConstant: 48)
        ])
        
        // AR按钮
        let arBtn = UIButton(type: .custom)
        arBtn.setTitle("AR", for: .normal)
        arBtn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        arBtn.setTitleColor(.white, for: .normal)
        arBtn.backgroundColor = .systemBlue
        arBtn.layer.cornerRadius = 18
        arBtn.layer.shadowOpacity = 0.12
        arBtn.layer.shadowRadius = 6
        arBtn.translatesAutoresizingMaskIntoConstraints = false
        arBtn.addTarget(context.coordinator, action: #selector(Coordinator.openARDirect), for: .touchUpInside)
        container.addSubview(arBtn)
        context.coordinator.arButton = arBtn
        NSLayoutConstraint.activate([
            arBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            arBtn.bottomAnchor.constraint(equalTo: locateBtn.topAnchor, constant: -12),
            arBtn.widthAnchor.constraint(equalToConstant: 48),
            arBtn.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        // 信息卡片
        let infoCard = context.coordinator.infoCardView
        infoCard.isHidden = true
        infoCard.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(infoCard)
        NSLayoutConstraint.activate([
            infoCard.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            infoCard.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            infoCard.bottomAnchor.constraint(equalTo: container.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        
        // 导航UI
        addNavigationUI(to: container, coordinator: context.coordinator)
        
        return container
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let mapView = context.coordinator.mapView else { return }
        
        // 清除现有覆盖层
        mapView.removeOverlays(mapView.overlays)
        
        // 设置中心点
        if let start = startCoordinate {
            mapView.setCenter(start, animated: false)
        }
        
        if let center = centerCoordinate {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                mapView.setCenter(center, animated: true)
            }
        }
        
        // 自动规划路线
        if let start = startCoordinate, let dest = destination {
            if context.coordinator.lastRouteStart != start || context.coordinator.lastRouteDest != dest {
                context.coordinator.lastRouteStart = start
                context.coordinator.lastRouteDest = dest
                context.coordinator.searchWalkingRoute(from: start, to: dest, on: mapView)
            }
        }
    }
    
    // MARK: - 导航UI - 按照高德官方样式
    private func addNavigationUI(to container: UIView, coordinator: Coordinator) {
        // 顶部导航信息栏 - 深色背景，紧贴顶部
        let topInfoView = UIView()
        topInfoView.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        topInfoView.translatesAutoresizingMaskIntoConstraints = false
        topInfoView.isHidden = true
        
        // 转向图标
        let turnIconView = UIImageView()
        turnIconView.contentMode = .scaleAspectFit
        turnIconView.image = UIImage(systemName: "arrow.right")
        turnIconView.tintColor = .white
        turnIconView.translatesAutoresizingMaskIntoConstraints = false
        topInfoView.addSubview(turnIconView)
        
        // 导航指令 - 合并距离和道路名称
        let instructionLabel = UILabel()
        instructionLabel.text = "200米后进入天府大道"
        instructionLabel.textColor = .white
        instructionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        instructionLabel.numberOfLines = 1
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        topInfoView.addSubview(instructionLabel)
        
        container.addSubview(topInfoView)
        
        NSLayoutConstraint.activate([
            // 顶部信息栏 - 紧贴顶部
            topInfoView.topAnchor.constraint(equalTo: container.topAnchor, constant: 0),
            topInfoView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 0),
            topInfoView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: 0),
            topInfoView.heightAnchor.constraint(equalToConstant: 60),
            
            // 转向图标
            turnIconView.leadingAnchor.constraint(equalTo: topInfoView.leadingAnchor, constant: 16),
            turnIconView.centerYAnchor.constraint(equalTo: topInfoView.centerYAnchor),
            turnIconView.widthAnchor.constraint(equalToConstant: 24),
            turnIconView.heightAnchor.constraint(equalToConstant: 24),
            
            // 导航指令
            instructionLabel.leadingAnchor.constraint(equalTo: turnIconView.trailingAnchor, constant: 12),
            instructionLabel.centerYAnchor.constraint(equalTo: topInfoView.centerYAnchor),
            instructionLabel.trailingAnchor.constraint(equalTo: topInfoView.trailingAnchor, constant: -16)
        ])
        
        // 底部导航控制栏 - 深色背景，按照高德官方样式
        let bottomNavView = UIView()
        bottomNavView.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        bottomNavView.translatesAutoresizingMaskIntoConstraints = false
        bottomNavView.isHidden = true
        
        // 退出按钮
        let exitButton = UIButton(type: .system)
        exitButton.setTitle("退出", for: .normal)
        exitButton.setTitleColor(.white, for: .normal)
        exitButton.backgroundColor = UIColor.red.withAlphaComponent(0.8)
        exitButton.layer.cornerRadius = 8
        exitButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        exitButton.translatesAutoresizingMaskIntoConstraints = false
        exitButton.addTarget(coordinator, action: #selector(coordinator.exitNavigation), for: .touchUpInside)
        
        // 剩余距离和时间
        let remainLabel = UILabel()
        remainLabel.text = "剩余 1.2公里 15分钟"
        remainLabel.textColor = .white
        remainLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        remainLabel.textAlignment = .center
        remainLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 设置按钮
        let settingsButton = UIButton(type: .system)
        settingsButton.setTitle("设置", for: .normal)
        settingsButton.setTitleColor(.white, for: .normal)
        settingsButton.backgroundColor = UIColor.gray.withAlphaComponent(0.6)
        settingsButton.layer.cornerRadius = 8
        settingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        
        bottomNavView.addSubview(exitButton)
        bottomNavView.addSubview(remainLabel)
        bottomNavView.addSubview(settingsButton)
        container.addSubview(bottomNavView)
        
        NSLayoutConstraint.activate([
            // 底部信息栏 - 紧贴底部
            bottomNavView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 0),
            bottomNavView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: 0),
            bottomNavView.bottomAnchor.constraint(equalTo: container.safeAreaLayoutGuide.bottomAnchor, constant: 0),
            bottomNavView.heightAnchor.constraint(equalToConstant: 60),
            
            // 退出按钮
            exitButton.leadingAnchor.constraint(equalTo: bottomNavView.leadingAnchor, constant: 16),
            exitButton.centerYAnchor.constraint(equalTo: bottomNavView.centerYAnchor),
            exitButton.widthAnchor.constraint(equalToConstant: 60),
            exitButton.heightAnchor.constraint(equalToConstant: 36),
            
            // 剩余信息
            remainLabel.centerXAnchor.constraint(equalTo: bottomNavView.centerXAnchor),
            remainLabel.centerYAnchor.constraint(equalTo: bottomNavView.centerYAnchor),
            
            // 设置按钮
            settingsButton.trailingAnchor.constraint(equalTo: bottomNavView.trailingAnchor, constant: -16),
            settingsButton.centerYAnchor.constraint(equalTo: bottomNavView.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 60),
            settingsButton.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        coordinator.topInfoView = topInfoView
        coordinator.instructionLabel = instructionLabel
        coordinator.bottomNavView = bottomNavView
        coordinator.exitButton = exitButton
        coordinator.remainLabel = remainLabel
    }

    class Coordinator: NSObject, MAMapViewDelegate, AMapSearchDelegate, CustomSearchBarViewDelegate, AMapLocationManagerDelegate {
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
        
        init(_ parent: AMapViewRepresentable) {
            self.parent = parent
            super.init()
            self.search = AMapSearchAPI()
            self.search?.delegate = self
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
        
        // 路线规划回调
        func onRouteSearchDone(_ request: AMapRouteSearchBaseRequest!, response: AMapRouteSearchResponse!) {
            guard let path = response.route.paths.first, let mapView = mapView else { return }
            
            if let steps = path.steps {
                var coordinates: [CLLocationCoordinate2D] = []
                for step in steps {
                    let polylineStr = step.polyline
                    let points = polylineStr?.split(separator: ";").compactMap { pair -> CLLocationCoordinate2D? in
                        let comps = pair.split(separator: ",")
                        if comps.count == 2, let lon = Double(comps[0]), let lat = Double(comps[1]) {
                            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        }
                        return nil
                    } ?? []
                    coordinates.append(contentsOf: points)
                }
                
                let polyline = MAPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
                mapView.removeOverlays(mapView.overlays)
                mapView.add(polyline)
                
                // 设置地图中心
                if coordinates.count > 0 {
                    let centerCoordinate = coordinates[coordinates.count / 2]
                    mapView.setCenter(centerCoordinate, animated: true)
                }
            }
        }
        
        // 开始步行导航
        func startWalkingNavigation(to destination: CLLocationCoordinate2D) {
            guard !isNavigating else { return }
            
            print("🚶 [步行导航] 开始导航到: \(destination)")
            
            // 确保在主线程上执行
            DispatchQueue.main.async {
                self.isNavigating = true
                
                // 隐藏搜索框和信息卡片
                self.hideNonNavigationUI()
                
                // 显示导航UI
                self.showNavigationUI()
                
                // 绘制导航路线
                self.drawNavigationRoute(to: destination)
                
                // 跳转到起始位置
                self.jumpToStartLocation()
                
                // 启动步行导航 - 添加延迟确保UI更新完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.parent.walkNavManager.startWalkingNavigation(to: destination)
                    
                    // 启动导航信息更新定时器
                    self.startNavigationTimer()
                    
                    self.parent.onNavigationStart?()
                }
            }
        }
        
        // 退出导航
        @objc func exitNavigation() {
            guard isNavigating else { return }
            
            print("🛑 [步行导航] 退出导航")
            
            isNavigating = false
            
            // 停止导航
            parent.walkNavManager.stopNavigation()
            
            // 隐藏导航UI
            hideNavigationUI()
            
            // 显示搜索框
            showNonNavigationUI()
            
            parent.onNavigationStop?()
        }
        
        // 显示导航UI
        private func showNavigationUI() {
            topInfoView?.isHidden = false
            bottomNavView?.isHidden = false
            
            // 更新导航信息
            updateNavigationInfo()
        }
        
        // 隐藏导航UI
        private func hideNavigationUI() {
            topInfoView?.isHidden = true
            bottomNavView?.isHidden = true
        }
        
        // 隐藏非导航UI
        private func hideNonNavigationUI() {
            infoCardView.isHidden = true
            // 隐藏搜索框
            for subview in mapView?.subviews ?? [] {
                if subview is CustomSearchBarView {
                    subview.isHidden = true
                    print("🔍 [UI] 隐藏搜索栏")
                }
            }
        }
        
        // 显示非导航UI
        private func showNonNavigationUI() {
            // 显示搜索框
            for subview in mapView?.subviews ?? [] {
                if subview is CustomSearchBarView {
                    subview.isHidden = false
                    print("🔍 [UI] 显示搜索栏")
                }
            }
        }
        
        // 更新导航信息
        private func updateNavigationInfo() {
                DispatchQueue.main.async {
                    // 更新导航指令
                    self.instructionLabel?.text = self.parent.walkNavManager.currentInstruction
                    
                    // 更新剩余距离和时间
                    let distance = self.parent.walkNavManager.distanceToDestination
                    let time = self.parent.walkNavManager.estimatedArrivalTime
                    
                    // 格式化距离显示
                    let distanceText: String
                    if distance >= 1000 {
                        distanceText = String(format: "%.1f公里", distance / 1000.0)
                    } else {
                        distanceText = "\(Int(distance))米"
                    }
                    
                    // 更新底部导航栏
                    if let remainLabel = self.remainLabel {
                        remainLabel.text = "剩余 \(distanceText) \(time)"
                        print("📍 [UI更新] 剩余距离: \(distanceText), 时间: \(time)")
                    }
                }
        }
        
        // 启动定时器更新导航信息
        private func startNavigationTimer() {
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self, self.isNavigating else { return }
                
                DispatchQueue.main.async {
                    self.updateNavigationInfo()
                }
            }
        }
        
        // 绘制导航路线
        private func drawNavigationRoute(to destination: CLLocationCoordinate2D) {
            guard let mapView = mapView,
                  let currentLocation = mapView.userLocation?.coordinate else {
                print("❌ [导航] 无法获取当前位置，无法绘制路线")
                return
            }
            
            print("🗺️ [导航] 绘制路线: \(currentLocation) -> \(destination)")
            
            // 清除之前的路线
            mapView.removeOverlays(mapView.overlays)
            
            // 创建路线坐标数组
            var coordinates = [currentLocation, destination]
            
            // 创建折线
            let polyline = MAPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
            polyline?.title = "导航路线"
            
            // 添加到地图
            mapView.add(polyline)
            
            // 强制刷新地图
            mapView.setNeedsDisplay()
            
            print("✅ [导航] 路线已添加到地图，坐标数量: \(coordinates.count)")
            print("📍 [导航] 起点: \(currentLocation)")
            print("📍 [导航] 终点: \(destination)")
            
            // 设置地图区域以显示整条路线
            let minLat = min(currentLocation.latitude, destination.latitude)
            let maxLat = max(currentLocation.latitude, destination.latitude)
            let minLon = min(currentLocation.longitude, destination.longitude)
            let maxLon = max(currentLocation.longitude, destination.longitude)
            
            let centerLat = (minLat + maxLat) / 2
            let centerLon = (minLon + maxLon) / 2
            let spanLat = max(maxLat - minLat, 0.01) * 1.2 // 添加一些边距
            let spanLon = max(maxLon - minLon, 0.01) * 1.2
            
            let region = MACoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MACoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
            )
            mapView.setRegion(region, animated: true)
            
            print("✅ [导航] 路线绘制完成")
        }
        
        // 跳转到起始位置
        private func jumpToStartLocation() {
            guard let mapView = mapView,
                  let currentLocation = mapView.userLocation?.coordinate else {
                print("❌ [导航] 无法获取当前位置，无法跳转")
                return
            }
            
            print("📍 [导航] 跳转到起始位置: \(currentLocation)")
            
            // 确保用户位置显示
            mapView.showsUserLocation = true
            
            // 设置地图中心为当前位置
            mapView.setCenter(currentLocation, animated: true)
            
            // 设置合适的缩放级别
            mapView.setZoomLevel(16, animated: true)
            
            // 启用用户位置跟踪和朝向指示器
            mapView.userTrackingMode = .followWithHeading // 启用朝向指示器
            
            print("✅ [导航] 已跳转到起始位置")
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
        
        // 地图代理方法
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
        
        func aMapSearchRequest(_ request: Any!, didFailWithError error: Error!) {
            print("搜索请求失败：\(error.localizedDescription)")
        }
    }
}

// 自定义搜索框
protocol CustomSearchBarViewDelegate: AnyObject {
    func didTapSearch(with keyword: String)
}

class CustomSearchBarView: UIView, UITextFieldDelegate {
    weak var delegate: CustomSearchBarViewDelegate?
    private let iconView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
    private let textField = UITextField()
    private let micView = UIImageView(image: UIImage(systemName: "mic.fill"))
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.white.withAlphaComponent(0.95)
        layer.cornerRadius = 26
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        
        iconView.tintColor = .gray
        micView.tintColor = .gray
        textField.placeholder = "搜索地点/POI"
        textField.font = UIFont.boldSystemFont(ofSize: 18)
        textField.textColor = .darkGray
        textField.delegate = self
        textField.returnKeyType = .search
        
        let stack = UIStackView(arrangedSubviews: [iconView, textField, micView])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            micView.widthAnchor.constraint(equalToConstant: 28),
            micView.heightAnchor.constraint(equalToConstant: 28),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let text = textField.text {
            delegate?.didTapSearch(with: text)
        }
        textField.resignFirstResponder()
        return true
    }
}

// 信息卡片视图
class InfoCardView: UIView {
    private let titleLabel = UILabel()
    private let addressLabel = UILabel()
    private let distanceLabel = UILabel()
    private let routeButton = UIButton(type: .system)
    var onRoute: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 6
        
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = .black
        addressLabel.font = UIFont.systemFont(ofSize: 14)
        addressLabel.textColor = .darkGray
        addressLabel.numberOfLines = 2
        distanceLabel.font = UIFont.systemFont(ofSize: 13)
        distanceLabel.textColor = .gray
        distanceLabel.numberOfLines = 1
        
        routeButton.setTitle("路线/导航", for: .normal)
        routeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        routeButton.backgroundColor = UIColor.systemBlue
        routeButton.setTitleColor(.white, for: .normal)
        routeButton.layer.cornerRadius = 8
        routeButton.addTarget(self, action: #selector(routeTapped), for: .touchUpInside)
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, distanceLabel, addressLabel, routeButton])
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            routeButton.heightAnchor.constraint(equalToConstant: 40),
            routeButton.widthAnchor.constraint(equalToConstant: 120)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func configure(title: String, address: String, distance: String? = nil) {
        titleLabel.text = title
        addressLabel.text = address
        distanceLabel.text = distance
        distanceLabel.isHidden = (distance == nil)
    }
    
    @objc private func routeTapped() {
        onRoute?()
    }
}