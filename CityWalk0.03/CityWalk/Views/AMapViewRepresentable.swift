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
    @StateObject private var walkNavManager = WalkingNavigationManager.shared
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
        
        // 导航UI - 在原地图界面添加导航功能
        addNavigationUI(to: container, coordinator: context.coordinator)
        
        // 添加导航视图到地图容器
        addNavigationViewToMap(container: container, coordinator: context.coordinator)
        
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
        
        // 确保UI面板在最上层
        container.bringSubviewToFront(topInfoView)
        
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
        
        print("✅ [UI调试] 顶部导航面板已添加到容器")
        
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
        
        // 确保UI面板在最上层
        container.bringSubviewToFront(bottomNavView)
        
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
        
        print("✅ [UI调试] 底部导航面板已添加到容器")
        
        coordinator.topInfoView = topInfoView
        coordinator.instructionLabel = instructionLabel
        coordinator.bottomNavView = bottomNavView
        coordinator.exitButton = exitButton
        coordinator.remainLabel = remainLabel
    }

    // MARK: - 在原地图界面添加导航功能
    private func addNavigationViewToMap(container: UIView, coordinator: Coordinator) {
        // 创建高德导航视图，但不立即显示
        let walkView = AMapNaviWalkView()
        walkView.delegate = coordinator
        walkView.showUIElements = true
        walkView.showBrowseRouteButton = true
        walkView.showMoreButton = true
        walkView.showMode = .carPositionLocked
        walkView.trackingMode = .mapNorth
        walkView.isHidden = true // 初始隐藏
        
        // 确保导航视图配置正确
        walkView.backgroundColor = UIColor.clear
        walkView.isOpaque = false
        
        // 添加到地图容器
        container.addSubview(walkView)
        walkView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            walkView.topAnchor.constraint(equalTo: container.topAnchor),
            walkView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            walkView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            walkView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // 保存引用
        coordinator.navigationView = walkView
        
        print("✅ [导航] 导航视图已添加到地图容器")
        print("🔍 [导航] 导航视图配置: showUIElements=\(walkView.showUIElements), showMode=\(walkView.showMode.rawValue)")
    }

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
        
        // 开始步行导航 - 在原地图界面实现导航功能
        func startWalkingNavigation(to destination: CLLocationCoordinate2D) {
            guard !isNavigating else { return }
            
            print("🚶 [步行导航] 开始导航到: \(destination)")
            print("🔍 [调试] 当前地图视图状态: \(mapView != nil ? "已初始化" : "未初始化")")
            print("🔍 [调试] 当前导航视图状态: \(navigationView != nil ? "已初始化" : "未初始化")")
            
            // 确保在主线程上执行
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { 
                    print("❌ [调试] self为nil，退出导航")
                    return 
                }
                
                self.isNavigating = true
                print("✅ [导航] 导航状态已设置为true")
                
                // 隐藏搜索框和信息卡片
                self.hideNonNavigationUI()
                print("✅ [导航] 非导航UI已隐藏")
                
                // 启动WalkingNavigationManager（使用地图API路线规划）
                self.parent.walkNavManager.startWalkingNavigation(to: destination)
                
                // 在原地图界面启用导航视图
                self.enableNavigationOnMap(destination: destination)
                
                // 显示导航信息面板
                self.showNavigationInfoPanel()
                
                // 使用地图API进行路线规划
                self.calculateRouteUsingAMapAPI(to: destination)
                
                // 延迟确保UI在最顶层（给高德导航视图时间初始化）
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.ensureNavigationUIOnTop()
                }
                    
                print("✅ [导航] 导航已在地图界面启动")
                print("🔍 [调试] 导航视图可见性: \(self.navigationView?.isHidden == false ? "可见" : "隐藏")")
                print("🔍 [调试] 地图用户位置: \(self.mapView?.showsUserLocation == true ? "已启用" : "未启用")")
                    
                    self.parent.onNavigationStart?()
                }
            }
        
        // 使用高德地图API进行路线规划，避免导航SDK崩溃
        private func calculateRouteUsingAMapAPI(to destination: CLLocationCoordinate2D) {
            print("🗺️ [地图API] 开始使用高德地图API进行路线规划")
            
            guard let mapView = mapView,
                  let currentLocation = mapView.userLocation?.coordinate else {
                print("❌ [地图API] 无法获取当前位置")
                return
            }
            
            // 检查搜索API是否可用
            guard let searchAPI = search else {
                print("❌ [地图API] 搜索API未初始化")
                return
            }
            
            print("🔍 [地图API] 当前位置: \(currentLocation)")
            print("🔍 [地图API] 目标位置: \(destination)")
            
            // 使用高德地图搜索API进行路线规划
            let request = AMapWalkingRouteSearchRequest()
            request.origin = AMapGeoPoint.location(withLatitude: CGFloat(currentLocation.latitude), 
                                                 longitude: CGFloat(currentLocation.longitude))
            request.destination = AMapGeoPoint.location(withLatitude: CGFloat(destination.latitude), 
                                                        longitude: CGFloat(destination.longitude))
            // 设置返回字段类型，确保返回polyline数据
            request.showFieldsType = AMapWalkingRouteShowFieldType.all
            
            print("🔍 [地图API] 请求起点: \(request.origin?.description ?? "nil")")
            print("🔍 [地图API] 请求终点: \(request.destination?.description ?? "nil")")
            
            // 确保导航UI已初始化
            if self.remainLabel == nil {
                print("⚠️ [地图API] remainLabel未初始化，无法显示距离信息")
                print("🔍 [地图API] 当前remainLabel状态: \(self.remainLabel != nil ? "已初始化" : "未初始化")")
            }
            
            // 立即使用备用方案计算距离（确保有数据显示）
            self.fallbackDistanceCalculation(from: currentLocation, to: destination)
            
            // 同时尝试API调用
            print("🔍 [地图API] 准备发送路线规划请求")
            print("🔍 [地图API] 搜索API状态: \(searchAPI != nil ? "已初始化" : "未初始化")")
            print("🔍 [地图API] 请求对象: \(request)")
            
            searchAPI.aMapWalkingRouteSearch(request)
            print("✅ [地图API] 路线规划请求已发送")
            
            // 添加超时检查
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                print("⏰ [地图API] 路线搜索超时检查（5秒后）")
            }
        }
        
        // 备用距离计算方案 - 当API调用失败时使用
        private func fallbackDistanceCalculation(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) {
            print("🔄 [备用方案] 开始计算直线距离")
            print("🔍 [备用方案] 起点坐标: \(start)")
            print("🔍 [备用方案] 终点坐标: \(end)")
            
            let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
            let endLocation = CLLocation(latitude: end.latitude, longitude: end.longitude)
            
            let distance = startLocation.distance(from: endLocation)
            let walkingTime = Int(distance / 1.4) // 假设步行速度1.4米/秒
            
            print("📏 [备用方案] 直线距离: \(Int(distance))米, 预计步行时间: \(walkingTime)秒")
            print("🔍 [备用方案] remainLabel状态: \(remainLabel != nil ? "已初始化" : "未初始化")")
            
            // 更新UI显示
            DispatchQueue.main.async {
                print("🔍 [备用方案] 开始更新UI显示")
                self.updateNavigationInfoWithRouteData(distance: distance, duration: Double(walkingTime))
                print("🔍 [备用方案] UI更新完成")
            }
        }
        
        // 显示基本导航信息 - 逐步恢复高德导航功能的安全方案
        private func showBasicNavigationInfo(destination: CLLocationCoordinate2D) {
            print("📍 [基本导航] 开始显示基本导航信息（逐步恢复模式）")
            
            // 显示导航UI
            showNavigationUI()
            
            // 第三步：恢复路线绘制功能
            print("🔍 [调试] 开始绘制导航路线")
            drawNavigationRoute(to: destination)
            print("🔍 [调试] 导航路线绘制完成")
            
            print("🔍 [调试] 开始跳转到起始位置")
            jumpToStartLocation()
            print("🔍 [调试] 跳转到起始位置完成")
            
            // 第三步：恢复定时器功能
            print("🔍 [调试] 开始恢复导航定时器（第三步）")
            startNavigationTimer()
            print("🔍 [调试] 导航定时器恢复完成（第三步）")
            
            print("✅ [基本导航] 基本导航信息显示完成（逐步恢复高德导航功能）")
        }
        
        // 在原地图界面启用导航
        private func enableNavigationOnMap(destination: CLLocationCoordinate2D) {
            print("🗺️ [导航] 在原地图界面启用导航")
            
            // 确保导航视图在最上层
            if let navigationView = navigationView {
                navigationView.superview?.bringSubviewToFront(navigationView)
                navigationView.isHidden = false
                print("✅ [导航] 导航视图已显示并置于最上层")
            }
            
            // 确保地图显示用户位置
            mapView?.showsUserLocation = true
            mapView?.userTrackingMode = .followWithHeading
            mapView?.userLocation.title = "我的位置"
            mapView?.userLocation.subtitle = "当前位置"
            print("✅ [导航] 地图用户位置已启用")
            
            // 强制刷新用户位置显示
            mapView?.setNeedsDisplay()
            
            // 延迟添加导航视图到管理器，避免初始化冲突
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let walkManager = self.parent.walkNavManager.getWalkManager(),
                   let navigationView = self.navigationView {
                    walkManager.addDataRepresentative(navigationView)
                    print("✅ [导航] 导航视图已添加到管理器")
                    
                    // 启动GPS导航（不进行路线规划，避免崩溃）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        walkManager.startGPSNavi()
                        print("🚀 [导航] 已启动GPS导航")
                    }
                }
            }
            
            // 设置地图中心位置
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let currentLocation = self.mapView?.userLocation?.coordinate {
                    let centerCoordinate = CLLocationCoordinate2D(
                        latitude: (currentLocation.latitude + destination.latitude) / 2,
                        longitude: (currentLocation.longitude + destination.longitude) / 2
                    )
                    
                    let distance = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
                        .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
                    
                    let latitudinalMeters = max(distance * 1.5, 10000)
                    let longitudinalMeters = max(distance * 1.5, 10000)
                    
                    let region = MACoordinateRegion(
                        center: centerCoordinate,
                        span: MACoordinateSpan(
                            latitudeDelta: latitudinalMeters / 111000,
                            longitudeDelta: longitudinalMeters / 111000
                        )
                    )
                    
                    // 设置地图区域
                    if let mapView = self.findMapView(in: self.navigationView ?? UIView()) {
                        mapView.setRegion(region, animated: true)
                        print("✅ [导航] 地图已跳转到正确位置: \(centerCoordinate)")
                    }
                }
            }
        }
        
        // 确保导航UI在最顶层
        private func ensureNavigationUIOnTop() {
            print("🔍 [UI调试] 确保导航UI在最顶层")
            
            // 确保顶部和底部面板都在最顶层
            if let topView = topInfoView, let bottomView = bottomNavView {
                // 获取共同的父容器
                if let container = topView.superview {
                    container.bringSubviewToFront(topView)
                    container.bringSubviewToFront(bottomView)
                    print("✅ [UI调试] 导航UI已置于最顶层")
                } else {
                    print("❌ [UI调试] 无法找到容器视图")
                }
            } else {
                print("❌ [UI调试] 导航UI视图未初始化")
            }
        }
        
        // 显示导航信息面板
        private func showNavigationInfoPanel() {
            print("📱 [导航] 显示导航信息面板")
            
            // 显示顶部和底部导航面板
            topInfoView?.isHidden = false
            bottomNavView?.isHidden = false
            
            // 添加调试信息
            print("🔍 [UI调试] topInfoView状态: \(topInfoView?.isHidden == false ? "显示" : "隐藏")")
            print("🔍 [UI调试] bottomNavView状态: \(bottomNavView?.isHidden == false ? "显示" : "隐藏")")
            print("🔍 [UI调试] topInfoView父视图: \(topInfoView?.superview != nil ? "存在" : "nil")")
            print("🔍 [UI调试] bottomNavView父视图: \(bottomNavView?.superview != nil ? "存在" : "nil")")
            
            // 确保导航面板在最上层
            topInfoView?.superview?.bringSubviewToFront(topInfoView!)
            bottomNavView?.superview?.bringSubviewToFront(bottomNavView!)
            
            // 强制刷新UI
            topInfoView?.setNeedsLayout()
            bottomNavView?.setNeedsLayout()
            topInfoView?.layoutIfNeeded()
            bottomNavView?.layoutIfNeeded()
            
            // 确保UI面板在最顶层
            if let container = topInfoView?.superview {
                container.bringSubviewToFront(topInfoView!)
                container.bringSubviewToFront(bottomNavView!)
                print("✅ [UI调试] 已将导航面板置于最顶层")
            }
            
            // 额外确保导航UI在最顶层
            ensureNavigationUIOnTop()
            
            // 初始化导航信息显示
            updateNavigationInfo()
            
            // 启动导航信息更新
            startNavigationTimer()
            
            print("✅ [导航] 导航信息面板已显示")
        }
        
        // 显示高德导航界面 - 修复用户位置和路线显示问题
        private func showAMapNavigationView(destination: CLLocationCoordinate2D) {
            print("🗺️ [高德导航] 开始显示高德导航界面")
            
            // 确保在主线程执行
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // 检查是否已经在导航状态
                guard self.isNavigating else {
                    print("⚠️ [高德导航] 不在导航状态，跳过显示")
                    return
                }
                
                // 隐藏原有地图视图，让高德导航界面完全接管
                self.mapView?.isHidden = true
                
                // 创建高德导航视图
                let walkView = AMapNaviWalkView()
                walkView.delegate = self
                walkView.showUIElements = true
                walkView.showBrowseRouteButton = true
                walkView.showMoreButton = true
                walkView.showMode = .carPositionLocked
                walkView.trackingMode = .mapNorth
                
                // 安全检查：确保容器视图存在
                guard let container = self.mapView?.superview else {
                    print("❌ [高德导航] 容器视图不存在")
                    return
                }
                
                // 将导航视图添加到父容器，全屏显示
                container.addSubview(walkView)
                walkView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    walkView.topAnchor.constraint(equalTo: container.topAnchor),
                    walkView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    walkView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    walkView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
                ])
                
                // 设置起点和终点坐标
                if let currentLocation = self.mapView?.userLocation?.coordinate,
                   let startPoint = AMapNaviPoint.location(withLatitude: CGFloat(currentLocation.latitude), 
                                                          longitude: CGFloat(currentLocation.longitude)),
                   let endPoint = AMapNaviPoint.location(withLatitude: CGFloat(destination.latitude), 
                                                        longitude: CGFloat(destination.longitude)) {
                    
                    print("🗺️ [高德导航] 设置起点: \(currentLocation)")
                    print("🗺️ [高德导航] 设置终点: \(destination)")
                    
                    // 延迟添加导航视图到管理器，避免初始化冲突
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let walkManager = self.parent.walkNavManager.getWalkManager() {
                            walkManager.addDataRepresentative(walkView)
                            print("✅ [高德导航] 导航视图已添加到管理器")
                            
                            // 使用高德导航SDK进行路线规划
                            walkManager.calculateWalkRoute(withStart: [startPoint], end: [endPoint])
                            print("🗺️ [高德导航] 开始使用高德导航SDK进行路线规划")
                            
                            // 启动GPS导航
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                walkManager.startGPSNavi()
                                print("🚀 [高德导航] 已启动GPS导航")
                            }
                        }
                    }
                } else {
                    print("⚠️ [高德导航] 无法获取当前位置或创建起终点坐标")
                }
                
                // 设置地图中心位置，确保显示正确位置而不是北京
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if let currentLocation = self.mapView?.userLocation?.coordinate {
                        let centerCoordinate = CLLocationCoordinate2D(
                            latitude: (currentLocation.latitude + destination.latitude) / 2,
                            longitude: (currentLocation.longitude + destination.longitude) / 2
                        )
                        
                        let distance = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
                            .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
                        
                        let latitudinalMeters = max(distance * 1.5, 10000)
                        let longitudinalMeters = max(distance * 1.5, 10000)
                        
                        let region = MACoordinateRegion(
                            center: centerCoordinate,
                            span: MACoordinateSpan(
                                latitudeDelta: latitudinalMeters / 111000, // 转换为度数
                                longitudeDelta: longitudinalMeters / 111000
                            )
                        )
                        
                        // 使用深度搜索方法查找地图视图
                        if let mapView = self.findMapView(in: walkView) {
                            mapView.setRegion(region, animated: true)
                            print("✅ [高德导航] 地图已跳转到正确位置: \(centerCoordinate)")
                            print("🗺️ [高德导航] 显示范围: \(Int(region.span.latitudeDelta * 111000))米 x \(Int(region.span.longitudeDelta * 111000))米")
                        } else {
                            print("⚠️ [高德导航] 未找到地图视图，开始深度搜索...")
                            
                            // 增加延迟时间并添加更多调试信息
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                print("🔍 [调试] 开始深度搜索地图视图...")
                                self.debugViewHierarchy(walkView, level: 0)
                                
                                if let mapView = self.findMapView(in: walkView) {
                                    mapView.setRegion(region, animated: true)
                                    print("✅ [高德导航] 延迟设置地图区域成功")
                                } else {
                                    print("❌ [高德导航] 仍然无法找到地图视图，尝试直接设置AMapNaviWalkView")
                                    // 尝试使用 AMapNaviWalkView 的公共方法
                                    self.tryDirectSetMapCenter(walkView, centerCoordinate: centerCoordinate)
                                }
                            }
                        }
                    } else {
                        print("⚠️ [高德导航] 无法获取当前位置，使用目标位置作为中心")
                        let region = MACoordinateRegion(
                            center: destination,
                            span: MACoordinateSpan(
                                latitudeDelta: 20000 / 111000, // 转换为度数
                                longitudeDelta: 20000 / 111000
                            )
                        )
                        
                        if let mapView = self.findMapView(in: walkView) {
                            mapView.setRegion(region, animated: true)
                            print("✅ [高德导航] 地图已跳转到目标位置: \(destination)")
                        } else {
                            print("⚠️ [高德导航] 无法找到地图视图，使用目标位置作为中心")
                            self.tryDirectSetMapCenter(walkView, centerCoordinate: destination)
                        }
                    }
                }
                
                // 保存导航视图引用，用于后续移除
                self.navigationView = walkView
            }
        }
        
        // 退出导航 - 在原地图界面退出导航
        @objc func exitNavigation() {
            guard isNavigating else { return }
            
            print("🛑 [步行导航] 退出导航")
            
            // 确保在主线程执行
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.isNavigating = false
            
            // 停止导航
                self.parent.walkNavManager.stopNavigation()
                
                // 清除路线数据
                self.currentRouteDistance = nil
                self.currentRouteDuration = nil
                print("🗑️ [导航] 路线数据已清除")
                
                // 隐藏导航视图（不移除，保持在地图容器中）
                self.navigationView?.isHidden = true
                
                // 从管理器中移除导航视图
                if let walkManager = self.parent.walkNavManager.getWalkManager(),
                   let navigationView = self.navigationView {
                    walkManager.removeDataRepresentative(navigationView)
                    print("✅ [导航] 导航视图已从管理器移除")
                }
            
            // 隐藏导航UI
                self.hideNavigationUI()
            
            // 显示搜索框
                self.showNonNavigationUI()
            
                print("✅ [导航] 已退出导航，恢复地图界面")
                
                self.parent.onNavigationStop?()
            }
        }
        
        // 显示导航UI - 暂时禁用高德导航相关功能
        private func showNavigationUI() {
            // 显示基本导航UI
            topInfoView?.isHidden = false
            bottomNavView?.isHidden = false
            
            // 第二步：恢复导航信息更新功能
            print("🔍 [调试] 开始恢复导航信息更新（第二步）")
            updateNavigationInfo()
            print("🔍 [调试] 导航信息更新完成（第二步）")
            
            print("📍 [基本导航] 导航UI已显示（已禁用高德导航信息更新）")
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
        
        // 更新导航信息 - 优先使用WalkingNavigationManager的数据
        private func updateNavigationInfo() {
                DispatchQueue.main.async {
                // 更新导航指令 - 使用WalkingNavigationManager的实时指令
                let instruction = self.parent.walkNavManager.currentInstruction
                self.instructionLabel?.text = instruction
                print("📢 [UI更新] 导航指令: \(instruction)")
                
                // 优先使用保存的总路线距离，如果没有则使用实时距离
                let distance: Double
                let time: String
                
                if let routeDistance = self.currentRouteDistance, routeDistance > 0 {
                    // 使用总路线距离
                    distance = routeDistance
                    if let routeDuration = self.currentRouteDuration, routeDuration > 0 {
                        // 格式化时间显示
                        if routeDuration >= 3600 {
                            let hours = Int(routeDuration) / 3600
                            let minutes = (Int(routeDuration) % 3600) / 60
                            time = "\(hours)小时\(minutes)分钟"
                        } else if routeDuration >= 60 {
                            let minutes = Int(routeDuration) / 60
                            time = "\(minutes)分钟"
                        } else {
                            time = "\(Int(routeDuration))秒"
                        }
                    } else {
                        time = self.parent.walkNavManager.estimatedArrivalTime
                    }
                    print("🔍 [UI更新] 使用总路线距离: \(distance)米")
                } else {
                    // 回退到实时距离
                    distance = self.parent.walkNavManager.distanceToDestination
                    time = self.parent.walkNavManager.estimatedArrivalTime
                    print("🔍 [UI更新] 使用实时距离: \(distance)米")
                }
                    
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
        
        // 启动定时器更新导航信息 - 显示WalkingNavigationManager的实时数据
        private func startNavigationTimer() {
            print("🔍 [调试] 启动UI更新定时器，显示WalkingNavigationManager数据")
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self, self.isNavigating else { return }
                
                DispatchQueue.main.async {
                    self.updateNavigationInfo()
                    // 定期确保UI在最顶层
                    self.ensureNavigationUIOnTop()
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

// MARK: - AMapNaviWalkViewDelegate 实现
extension AMapViewRepresentable.Coordinator {
    
    func walkView(_ walkView: AMapNaviWalkView, didChange showMode: AMapNaviWalkViewShowMode) {
        print("🔄 [高德导航] 显示模式变化: \(showMode.rawValue)")
    }
    
    func walkView(_ walkView: AMapNaviWalkView, didChangeOrientation isLandscape: Bool) {
        print("📱 [高德导航] 屏幕方向变化: \(isLandscape ? "横屏" : "竖屏")")
    }
    
    func walkViewCloseButtonClicked(_ walkView: AMapNaviWalkView) {
        print("❌ [高德导航] 用户点击关闭按钮")
        exitNavigation()
    }
    
    func walkViewMoreButtonClicked(_ walkView: AMapNaviWalkView) {
        print("⚙️ [高德导航] 用户点击更多按钮")
    }
    
    func walkViewBrowseRouteButtonClicked(_ walkView: AMapNaviWalkView) {
        print("🗺️ [高德导航] 用户点击全览按钮")
    }
    
    func walkViewTrafficButtonClicked(_ walkView: AMapNaviWalkView) {
        print("🚦 [高德导航] 用户点击交通按钮")
    }
    
    func walkViewZoomInOutButtonClicked(_ walkView: AMapNaviWalkView) {
        print("🔍 [高德导航] 用户点击缩放按钮")
    }
}

// MARK: - AMapSearchDelegate 路线搜索回调
extension AMapViewRepresentable.Coordinator {
    
    // 步行路线搜索回调 - 添加错误处理和调试信息
    func onRouteSearchDone(_ request: AMapRouteSearchBaseRequest, response: AMapRouteSearchResponse) {
        print("🗺️ [地图API] 路线搜索完成")
        print("🔍 [地图API] 请求类型: \(type(of: request))")
        print("🔍 [地图API] 响应状态: \(response.count)")
        print("🔍 [地图API] 响应对象: \(response)")
        
        if response.count > 0 {
            print("✅ [地图API] 找到 \(response.count) 条路线")
            
            if let route = response.route {
                print("🔍 [地图API] 路线对象: \(route)")
                print("🔍 [地图API] 路线路径数量: \(route.paths?.count ?? 0)")
                
                if let paths = route.paths, paths.count > 0 {
                    guard let path = paths.first else { 
                        print("❌ [地图API] 无法获取第一条路线")
                        return 
                    }
                    
                    print("🔍 [地图API] 路径对象: \(path)")
                    print("🔍 [地图API] 路径步骤数量: \(path.steps?.count ?? 0)")
                    
                    // 计算总距离
                    let totalDistance = path.distance
                    let totalDuration = path.duration
                    
                    print("📏 [地图API] 路线距离: \(totalDistance)米, 预计时间: \(totalDuration)秒")
                    
                    // 更新导航信息
                    DispatchQueue.main.async {
                        self.updateNavigationInfoWithRouteData(distance: Double(totalDistance), duration: Double(totalDuration))
                    }
                    
                    // 在地图上显示详细路线
                    self.displayRouteOnMap(path: path)
                    
                    // 解析路线步骤，生成真实导航指令
                    print("🔍 [地图API] 开始调用路线步骤解析")
                    self.parent.walkNavManager.parseRouteSteps(from: path)
                    print("✅ [地图API] 路线步骤解析调用完成")
                    
                    // 更新WalkingNavigationManager的导航状态
                    DispatchQueue.main.async {
                        self.parent.walkNavManager.distanceToDestination = Double(totalDistance)
                        print("✅ [地图API] WalkingNavigationManager状态已更新")
                    }
                    
                    // 确保导航视图显示路线
                    self.ensureNavigationViewShowsRoute()
                } else {
                    print("❌ [地图API] 路线路径为空")
                }
            } else {
                print("❌ [地图API] 路线对象为空")
            }
        } else {
            print("❌ [地图API] 未找到路线，响应数量: \(response.count)")
        }
    }
    
    // 路线搜索失败回调
    func aMapSearchRequest(_ request: Any, didFailWithError error: Error) {
        print("❌ [地图API] 路线搜索失败: \(error.localizedDescription)")
        print("🔍 [地图API] 错误详情: \(error)")
    }
    
    // 通用搜索回调 - 捕获所有搜索响应
    func aMapSearchRequest(_ request: Any, didFailWithError error: Error?) {
        if let error = error {
            print("❌ [地图API] 通用搜索失败: \(error.localizedDescription)")
        } else {
            print("🔍 [地图API] 通用搜索回调被调用，但无错误信息")
        }
    }
    
    // 尝试其他可能的回调方法名 - 步行路线搜索
    func onWalkingRouteSearchDone(_ request: AMapWalkingRouteSearchRequest, response: AMapRouteSearchResponse) {
        print("🗺️ [地图API] 步行路线搜索完成")
        // 调用主方法
        self.onRouteSearchDone(request, response: response)
    }
    
    // 更新导航信息
    private func updateNavigationInfoWithRouteData(distance: Double, duration: Double) {
        print("🔍 [UI更新] 开始更新导航信息 - 距离: \(distance), 时间: \(duration)")
        
        // 保存路线数据，供定时器使用
        self.currentRouteDistance = distance
        self.currentRouteDuration = duration
        print("💾 [UI更新] 路线数据已保存 - 距离: \(distance), 时间: \(duration)")
        
        // 格式化距离显示
        let distanceText: String
        if distance >= 1000 {
            distanceText = String(format: "%.1f公里", distance / 1000.0)
        } else {
            distanceText = "\(Int(distance))米"
        }
        
        // 格式化时间显示
        let timeText: String
        if duration >= 3600 {
            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60
            timeText = "\(hours)小时\(minutes)分钟"
        } else if duration >= 60 {
            let minutes = Int(duration) / 60
            timeText = "\(minutes)分钟"
        } else {
            timeText = "\(Int(duration))秒"
        }
        
        print("🔍 [UI更新] 格式化后 - 距离: \(distanceText), 时间: \(timeText)")
        
        // 更新底部导航栏
        if let remainLabel = self.remainLabel {
            remainLabel.text = "剩余 \(distanceText) \(timeText)"
            print("✅ [UI更新] remainLabel已更新: \(remainLabel.text ?? "nil")")
        } else {
            print("❌ [UI更新] remainLabel为nil，无法更新UI")
            print("🔍 [UI更新] 尝试强制更新UI状态")
            
            // 尝试强制更新UI - 直接设置到父视图
            if let bottomNavView = self.bottomNavView {
                for subview in bottomNavView.subviews {
                    if let label = subview as? UILabel {
                        label.text = "剩余 \(distanceText) \(timeText)"
                        print("✅ [UI更新] 通过子视图更新成功: \(label.text ?? "nil")")
                        break
                    }
                }
            }
        }
        
        // 更新导航指令
        if let instructionLabel = self.instructionLabel {
            instructionLabel.text = "开始导航，总距离 \(distanceText)"
        }
    }
    
        // 在地图上显示详细路线
        private func displayRouteOnMap(path: AMapPath) {
            guard let mapView = mapView else { 
                print("❌ [路线显示] 地图视图未初始化")
                return 
            }
            
            print("🗺️ [路线显示] 开始在地图上显示路线")
            
            // 移除之前的路线
            mapView.removeOverlays(mapView.overlays)
            
            // 创建路线坐标数组
            var coordinates: [CLLocationCoordinate2D] = []
            if let steps = path.steps {
                for step in steps {
                    if let polyline = step.polyline {
                        let coords = polyline.components(separatedBy: ";")
                        for coordString in coords {
                            let parts = coordString.components(separatedBy: ",")
                            if parts.count >= 2,
                               let lng = Double(parts[0]),
                               let lat = Double(parts[1]) {
                                coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
                            }
                        }
                    }
                }
            }
            
            print("📍 [路线显示] 解析到 \(coordinates.count) 个路线坐标")
            
            if coordinates.count > 0 {
                // 创建路线
                let polyline = MAPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
                
                // 添加路线到地图
                mapView.add(polyline)
                
                // 设置地图区域以显示完整路线
                let region = MACoordinateRegion(center: coordinates[coordinates.count/2], 
                                              span: MACoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                mapView.setRegion(region, animated: true)
                
                print("✅ [路线显示] 路线已添加到地图，坐标数量: \(coordinates.count)")
            } else {
                print("❌ [路线显示] 没有找到路线坐标")
            }
        }
        
        // 确保导航视图显示路线
        private func ensureNavigationViewShowsRoute() {
            print("🗺️ [导航] 确保导航视图显示路线")
            
            // 确保导航视图可见
            navigationView?.isHidden = false
            
            // 确保导航视图在最上层
            navigationView?.superview?.bringSubviewToFront(navigationView!)
            
            // 强制刷新导航视图
            navigationView?.setNeedsDisplay()
            navigationView?.setNeedsLayout()
            
            print("✅ [导航] 导航视图已刷新并确保显示路线")
    }
}