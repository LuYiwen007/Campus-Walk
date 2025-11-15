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
        arBtn.setTitleColor(.white.withAlphaComponent(0.6), for: .disabled)
        arBtn.backgroundColor = .systemGray // 初始状态为灰色
        arBtn.layer.cornerRadius = 18
        arBtn.layer.shadowOpacity = 0.12
        arBtn.layer.shadowRadius = 6
        arBtn.translatesAutoresizingMaskIntoConstraints = false
        arBtn.isEnabled = false // 初始状态为禁用
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
        
        // 确保朝向指示器始终启用（除非用户手动改变）
        if mapView.userTrackingMode != .followWithHeading {
            mapView.userTrackingMode = .followWithHeading
        }
        
        // 如果正在导航，不要清除覆盖层（路线已经在 onRouteSearchDone 中绘制）
        if !context.coordinator.isNavigating {
            // 清除现有覆盖层
            mapView.removeOverlays(mapView.overlays)
        }
        
        // 设置中心点
        if let start = startCoordinate {
            mapView.setCenter(start, animated: false)
            // 设置中心点后，重新启用朝向指示器
            mapView.userTrackingMode = .followWithHeading
        }
        
        if let center = centerCoordinate {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                mapView.setCenter(center, animated: true)
                // 设置中心点后，重新启用朝向指示器
                mapView.userTrackingMode = .followWithHeading
            }
        }
        
        // 自动规划路线（仅在非导航状态下，且起终点改变时）
        if !context.coordinator.isNavigating,
           let start = startCoordinate, 
           let dest = destination {
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
        var navigationTimer: Timer? // 保存 Timer 引用，防止内存泄漏
        
        // 路线指引相关
        var routeSteps: [AMapStep] = [] // 保存路线步骤
        var currentStepIndex: Int = 0 // 当前路段索引
        var routeGuidanceView: UIView? // 路线指引视图
        var routeGuidanceScrollView: UIScrollView? // 路线指引滚动视图
        var routeStepCoordinates: [[CLLocationCoordinate2D]] = [] // 每个路段的坐标点数组
        var navigationDestination: CLLocationCoordinate2D? // 保存导航目的地，用于重新规划
        var lastReplanTime: Date? // 上次重新规划的时间，用于防止频繁重新规划
        var isOffRoute: Bool = false // 是否偏离路线
        
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
                // 重新启用朝向指示器
                mapView.userTrackingMode = .followWithHeading
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
                        // 重新启用朝向指示器
                        mapView.userTrackingMode = .followWithHeading
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
            
            // 更新AR按钮状态（只有在导航模式下才启用）
            updateARButtonState()
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
            guard let mapView = mapView else {
                print("❌ [路线规划] mapView 为空")
                DispatchQueue.main.async {
                    if self.isNavigating {
                        self.instructionLabel?.text = "地图视图不可用"
                    }
                }
                return
            }
            
            // ========== 路线解析信息打印开始 ==========
            print("\n" + String(repeating: "=", count: 60))
            print("🗺️ [路线解析] 开始解析路线数据")
            print(String(repeating: "=", count: 60))
            
            // 打印路线基本信息
            print("📍 [路线基本信息]")
            if let origin = response.route.origin {
                print("  起点: (\(origin.latitude), \(origin.longitude))")
            }
            if let destination = response.route.destination {
                print("  终点: (\(destination.latitude), \(destination.longitude))")
            }
            print("  路线方案数量: \(response.route.paths.count)")
            
            // 安全检查：确保 paths 数组不为空
            guard !response.route.paths.isEmpty,
                  let path = response.route.paths.first else {
                print("❌ [路线规划] 路线数据为空")
                DispatchQueue.main.async {
                    if self.isNavigating {
                        self.instructionLabel?.text = "未找到可用路线，请重试"
                    }
                }
                return
            }
            
            // 打印当前使用的路线方案信息
            print("\n📍 [当前路线方案]")
            print("  总距离: \(path.distance) 米 (\(String(format: "%.2f", Double(path.distance) / 1000.0)) 公里)")
            print("  预计时间: \(path.duration) 秒 (\(path.duration / 60) 分钟)")
            if let strategy = path.strategy {
                print("  导航策略: \(strategy)")
            }
            print("  路段数量: \(path.steps?.count ?? 0)")
            
            guard let steps = path.steps, !steps.isEmpty else {
                print("❌ [路线规划] 路线步骤为空")
                DispatchQueue.main.async {
                    if self.isNavigating {
                        self.instructionLabel?.text = "路线数据不完整"
                    }
                }
                return
            }
            
            // 打印每个路段的详细信息
            print("\n📍 [路段详细信息] (共 \(steps.count) 个路段)")
            print(String(repeating: "-", count: 60))
            
            var coordinates: [CLLocationCoordinate2D] = []
            var totalStepDistance = 0
            var totalStepDuration = 0
            
            // 清空之前的坐标数据
            self.routeStepCoordinates = []
            
            for (index, step) in steps.enumerated() {
                let stepDistance = step.distance
                let stepDuration = step.duration
                totalStepDistance += stepDistance
                totalStepDuration += stepDuration
                
                print("\n  [路段 \(index + 1)/\(steps.count)]")
                if let instruction = step.instruction {
                    print("    指令: \(instruction)")
                }
                if let road = step.road {
                    print("    道路: \(road)")
                }
                print("    距离: \(stepDistance) 米")
                print("    时间: \(stepDuration) 秒 (\(stepDuration / 60) 分钟)")
                if let action = step.action {
                    print("    动作: \(action)")
                }
                if let assistantAction = step.assistantAction {
                    print("    辅助动作: \(assistantAction)")
                }
                
                // 解析并保存每个路段的坐标点
                var stepCoordinates: [CLLocationCoordinate2D] = []
                if let polylineStr = step.polyline {
                    let points = polylineStr.split(separator: ";").compactMap { pair -> CLLocationCoordinate2D? in
                        let comps = pair.split(separator: ",")
                        if comps.count == 2, let lon = Double(comps[0]), let lat = Double(comps[1]) {
                            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        }
                        return nil
                    }
                    stepCoordinates = points
                    coordinates.append(contentsOf: points)
                    print("    坐标点数量: \(points.count)")
                    if !points.isEmpty {
                        print("    起点坐标: (\(points.first!.latitude), \(points.first!.longitude))")
                        print("    终点坐标: (\(points.last!.latitude), \(points.last!.longitude))")
                    }
                } else {
                    print("    坐标点: 无")
                }
                
                // 保存该路段的坐标点数组
                self.routeStepCoordinates.append(stepCoordinates)
            }
            
            print("\n" + String(repeating: "-", count: 60))
            print("📍 [路段汇总]")
            print("  路段总距离: \(totalStepDistance) 米")
            print("  路段总时间: \(totalStepDuration) 秒 (\(totalStepDuration / 60) 分钟)")
            print("  路线总坐标点: \(coordinates.count) 个")
            
            // 确保有足够的坐标点
            guard coordinates.count > 1 else {
                print("❌ [路线规划] 坐标点不足，无法绘制路线")
                DispatchQueue.main.async {
                    if self.isNavigating {
                        self.instructionLabel?.text = "路线坐标数据不足"
                    }
                }
                return
            }
            
            // 打印路线边界信息
            let minLat = coordinates.map { $0.latitude }.min() ?? 0
            let maxLat = coordinates.map { $0.latitude }.max() ?? 0
            let minLon = coordinates.map { $0.longitude }.min() ?? 0
            let maxLon = coordinates.map { $0.longitude }.max() ?? 0
            
            print("\n📍 [路线边界]")
            print("  最小纬度: \(minLat)")
            print("  最大纬度: \(maxLat)")
            print("  最小经度: \(minLon)")
            print("  最大经度: \(maxLon)")
            print("  纬度跨度: \(maxLat - minLat)")
            print("  经度跨度: \(maxLon - minLon)")
            
            print("\n" + String(repeating: "=", count: 60))
            print("✅ [路线解析] 路线解析完成，准备绘制")
            print(String(repeating: "=", count: 60) + "\n")
            // ========== 路线解析信息打印结束 ==========
            
            // 保存路线步骤信息
            self.routeSteps = steps
            self.currentStepIndex = 0
            self.isOffRoute = false // 路线重新规划后，重置偏离状态
            print("📍 [路线解析] 已保存 \(self.routeStepCoordinates.count) 个路段的坐标点")
            
            // 绘制路线
            let polyline = MAPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
            mapView.removeOverlays(mapView.overlays)
            mapView.add(polyline)
            
            // 在导航模式下，不自动调整地图区域，保持用户当前位置为中心
            // 只有在非导航模式下，才显示整条路线
            if !isNavigating {
                // 设置地图区域以显示整条路线
                let centerLat = (minLat + maxLat) / 2
                let centerLon = (minLon + maxLon) / 2
                let spanLat = max(maxLat - minLat, 0.01) * 1.5
                let spanLon = max(maxLon - minLon, 0.01) * 1.5
                
                let region = MACoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    span: MACoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
                )
                mapView.setRegion(region, animated: true)
                print("✅ [路线规划] 非导航模式：已设置地图区域显示整条路线")
            } else {
                // 导航模式下，保持用户当前位置为中心，使用合适的缩放级别
                // 地图视角由 jumpToStartLocation 和用户位置跟踪控制
                print("📍 [路线规划] 导航模式下保持用户位置为中心，不调整地图区域")
            }
            
            print("✅ [路线规划] 路线已绘制，坐标点数量: \(coordinates.count)")
            
            // 更新导航信息
            DispatchQueue.main.async {
                if self.isNavigating {
                    // 更新距离信息
                    let distance = path.distance
                    let distanceText: String
                    if distance >= 1000 {
                        distanceText = String(format: "%.1f公里", Double(distance) / 1000.0)
                    } else {
                        distanceText = "\(distance)米"
                    }
                    
                    // 更新预计时间（步行速度按5km/h计算）
                    let walkingSpeed = 5.0 // km/h
                    let timeInHours = Double(distance) / 1000.0 / walkingSpeed
                    let timeInMinutes = Int(timeInHours * 60)
                    let timeText: String
                    if timeInMinutes < 60 {
                        timeText = "\(timeInMinutes)分钟"
                    } else {
                        let hours = timeInMinutes / 60
                        let minutes = timeInMinutes % 60
                        timeText = "\(hours)小时\(minutes)分钟"
                    }
                    
                    // 更新UI
                    self.remainLabel?.text = "剩余 \(distanceText) \(timeText)"
                    
                    // 创建并显示路线指引视图
                    self.createRouteGuidanceView()
                    self.updateCurrentStepGuidance()
                    
                    print("📍 [路线规划] 距离: \(distanceText), 预计时间: \(timeText)")
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
                
                // 先调用路线规划API，而不是直接画直线
                guard let mapView = self.mapView,
                      let currentLocation = mapView.userLocation?.coordinate else {
                    print("❌ [导航] 无法获取当前位置，无法规划路线")
                    DispatchQueue.main.async {
                        self.instructionLabel?.text = "无法获取当前位置，请检查定位权限"
                    }
                    self.isNavigating = false
                    return
                }
                
                // 保存导航目的地，用于重新规划
                self.navigationDestination = destination
                self.isOffRoute = false
                self.lastReplanTime = nil
                
                // 调用路线规划API
                print("🗺️ [导航] 开始规划路线: \(currentLocation) -> \(destination)")
                self.instructionLabel?.text = "正在规划路线..."
                self.searchWalkingRoute(from: currentLocation, to: destination, on: mapView)
                
                // 跳转到起始位置
                self.jumpToStartLocation()
                
                // 启动步行导航 - 添加延迟确保UI更新完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.parent.walkNavManager.startWalkingNavigation(to: destination)
                    
                    // 启动导航信息更新定时器
                    self.startNavigationTimer()
                    
                    // 更新AR按钮状态（导航开始时启用）
                    self.updateARButtonState()
                    
                    self.parent.onNavigationStart?()
                }
            }
        }
        
        // 退出导航
        @objc func exitNavigation() {
            guard isNavigating else { return }
            
            print("🛑 [步行导航] 退出导航")
            
            isNavigating = false
            
            // 停止定时器
            stopNavigationTimer()
            
            // 停止导航
            parent.walkNavManager.stopNavigation()
            
            // 隐藏导航UI
            hideNavigationUI()
            
            // 显示搜索框
            showNonNavigationUI()
            
            // 更新AR按钮状态
            updateARButtonState()
            
            parent.onNavigationStop?()
        }
        
        deinit {
            // 清理所有资源，防止内存泄漏
            stopNavigationTimer()
            search?.delegate = nil
            mapView?.delegate = nil
            print("✅ [Coordinator] 资源已清理")
        }
        
        // 显示导航UI
        private func showNavigationUI() {
            topInfoView?.isHidden = false
            bottomNavView?.isHidden = false
            routeGuidanceView?.isHidden = false
            
            // 更新导航信息
            updateNavigationInfo()
        }
        
        // 隐藏导航UI
        private func hideNavigationUI() {
            topInfoView?.isHidden = true
            bottomNavView?.isHidden = true
            routeGuidanceView?.isHidden = true
        }
        
        // 创建路线指引视图（只显示当前路段）
        private func createRouteGuidanceView() {
            guard let mapView = mapView, !routeSteps.isEmpty, currentStepIndex < routeSteps.count else { return }
            
            // 移除旧的指引视图
            routeGuidanceView?.removeFromSuperview()
            
            // 创建指引视图容器
            let guidanceView = UIView()
            guidanceView.backgroundColor = UIColor.black.withAlphaComponent(0.85)
            guidanceView.layer.cornerRadius = 12
            guidanceView.translatesAutoresizingMaskIntoConstraints = false
            guidanceView.isHidden = !isNavigating
            
            // 创建内容视图（垂直布局）
            let contentView = UIStackView()
            contentView.axis = .vertical
            contentView.spacing = 10
            contentView.translatesAutoresizingMaskIntoConstraints = false
            guidanceView.addSubview(contentView)
            
            // 只显示当前路段
            let currentStep = routeSteps[currentStepIndex]
            
            // 计算实时距离信息
            var distanceToStepEnd = Double(currentStep.distance)
            var distanceToDestination = distanceToStepEnd
            
            if let userLocation = mapView.userLocation?.coordinate {
                let userLocationPoint = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                
                // 计算到当前路段终点的距离
                if currentStepIndex < routeStepCoordinates.count {
                    let stepCoords = routeStepCoordinates[currentStepIndex]
                    if !stepCoords.isEmpty {
                        let endCoord = stepCoords.last!
                        let endLocation = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)
                        distanceToStepEnd = userLocationPoint.distance(from: endLocation)
                    }
                }
                
                // 计算到目的地的总距离
                if currentStepIndex < routeSteps.count - 1 {
                    for index in (currentStepIndex + 1)..<routeSteps.count {
                        distanceToDestination += Double(routeSteps[index].distance)
                    }
                }
                distanceToDestination = distanceToStepEnd + (distanceToDestination - Double(currentStep.distance))
            } else {
                // 如果没有位置信息，计算后续路段总距离
                if currentStepIndex < routeSteps.count - 1 {
                    for index in (currentStepIndex + 1)..<routeSteps.count {
                        distanceToDestination += Double(routeSteps[index].distance)
                    }
                }
            }
            
            // 创建当前路段卡片（显示实时距离信息）
            let stepCard = createStepCard(
                step: currentStep, 
                index: currentStepIndex, 
                isCurrent: true,
                distanceToStepEnd: distanceToStepEnd,
                distanceToDestination: distanceToDestination
            )
            contentView.addArrangedSubview(stepCard)
            
            // 设置约束
            NSLayoutConstraint.activate([
                contentView.topAnchor.constraint(equalTo: guidanceView.topAnchor, constant: 16),
                contentView.leadingAnchor.constraint(equalTo: guidanceView.leadingAnchor, constant: 16),
                contentView.trailingAnchor.constraint(equalTo: guidanceView.trailingAnchor, constant: -16),
                contentView.bottomAnchor.constraint(equalTo: guidanceView.bottomAnchor, constant: -16)
            ])
            
            // 添加到地图视图
            mapView.addSubview(guidanceView)
            NSLayoutConstraint.activate([
                guidanceView.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -16),
                guidanceView.topAnchor.constraint(equalTo: mapView.safeAreaLayoutGuide.topAnchor, constant: 80),
                guidanceView.widthAnchor.constraint(equalToConstant: 280),
                guidanceView.heightAnchor.constraint(lessThanOrEqualToConstant: 200) // 只显示一个路段，高度更小
            ])
            
            routeGuidanceView = guidanceView
        }
        
        // 创建路段卡片
        private func createStepCard(step: AMapStep, index: Int, isCurrent: Bool, distanceToStepEnd: Double? = nil, distanceToDestination: Double? = nil) -> UIView {
            let card = UIView()
            card.backgroundColor = isCurrent ? UIColor.systemBlue.withAlphaComponent(0.3) : UIColor.white.withAlphaComponent(0.1)
            card.layer.cornerRadius = 8
            card.translatesAutoresizingMaskIntoConstraints = false
            
            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.spacing = 6
            stackView.translatesAutoresizingMaskIntoConstraints = false
            
            // 路段序号和状态
            let headerLabel = UILabel()
            headerLabel.text = "\(index + 1). \(isCurrent ? "📍 当前路段" : "")"
            headerLabel.textColor = .white
            headerLabel.font = UIFont.boldSystemFont(ofSize: 14)
            stackView.addArrangedSubview(headerLabel)
            
            // 导航指令
            if let instruction = step.instruction {
                let instructionLabel = UILabel()
                instructionLabel.text = instruction
                instructionLabel.textColor = .white
                instructionLabel.font = UIFont.systemFont(ofSize: 14)
                instructionLabel.numberOfLines = 0
                stackView.addArrangedSubview(instructionLabel)
            }
            
            // 道路名称
            if let road = step.road {
                let roadLabel = UILabel()
                roadLabel.text = "道路: \(road)"
                roadLabel.textColor = UIColor.white.withAlphaComponent(0.8)
                roadLabel.font = UIFont.systemFont(ofSize: 12)
                stackView.addArrangedSubview(roadLabel)
            }
            
            // 距离信息（优先显示实时距离）
            let infoLabel = UILabel()
            infoLabel.tag = 9999 // 添加标签以便后续更新
            if let realDistanceToEnd = distanceToStepEnd, isCurrent {
                // 显示实时距离
                let distanceText = realDistanceToEnd >= 1000 ? 
                    String(format: "%.1f公里", realDistanceToEnd / 1000.0) : 
                    "\(Int(realDistanceToEnd))米"
                
                // 如果有到目的地的距离，也显示
                if let destDistance = distanceToDestination {
                    let destText = destDistance >= 1000 ? 
                        String(format: "%.1f公里", destDistance / 1000.0) : 
                        "\(Int(destDistance))米"
                    infoLabel.text = "剩余: \(distanceText) | 到目的地: \(destText)"
                } else {
                    infoLabel.text = "剩余: \(distanceText)"
                }
            } else {
                // 显示路段原始距离
                infoLabel.text = "距离: \(step.distance)米 | 时间: \(step.duration / 60)分钟"
            }
            infoLabel.textColor = UIColor.white.withAlphaComponent(0.7)
            infoLabel.font = UIFont.systemFont(ofSize: 12)
            infoLabel.numberOfLines = 0
            stackView.addArrangedSubview(infoLabel)
            
            card.addSubview(stackView)
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
                stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
                stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
                stackView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
            ])
            
            return card
        }
        
        // 根据用户位置判断当前路段，并检测是否偏离路线
        private func updateCurrentStepBasedOnLocation() {
            guard let mapView = mapView,
                  let userLocation = mapView.userLocation?.coordinate,
                  !routeSteps.isEmpty,
                  !routeStepCoordinates.isEmpty,
                  isNavigating else {
                return
            }
            
            let userLocationPoint = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            var newStepIndex = currentStepIndex
            var minDistance = Double.infinity
            var closestStepIndex = currentStepIndex
            
            // 检查所有路段，找到最近的路段（用于偏离检测）
            var globalMinDistance = Double.infinity
            for (index, stepCoordinates) in routeStepCoordinates.enumerated() {
                if stepCoordinates.isEmpty { continue }
                
                var stepMinDistance = Double.infinity
                for coord in stepCoordinates {
                    let coordLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    let distance = userLocationPoint.distance(from: coordLocation)
                    stepMinDistance = min(stepMinDistance, distance)
                }
                
                if stepMinDistance < globalMinDistance {
                    globalMinDistance = stepMinDistance
                }
            }
            
            // 偏离检测：如果用户距离所有路段都超过200米，判定为偏离路线
            let offRouteThreshold: Double = 200.0
            if globalMinDistance > offRouteThreshold {
                if !isOffRoute {
                    print("⚠️ [偏离检测] 用户已偏离路线，距离最近路段: \(Int(globalMinDistance))米")
                    isOffRoute = true
                    // 触发重新规划
                    replanRouteIfNeeded()
                }
                return // 偏离路线时，不更新路段索引
            } else {
                // 用户回到路线上
                if isOffRoute {
                    print("✅ [偏离检测] 用户已回到路线上")
                    isOffRoute = false
                }
            }
            
            // 从当前路段开始检查，向前查找（最多检查当前路段和接下来3个路段）
            let searchEndIndex = min(currentStepIndex + 4, routeSteps.count)
            
            for index in currentStepIndex..<searchEndIndex {
                let stepCoordinates = routeStepCoordinates[index]
                if stepCoordinates.isEmpty { continue }
                
                // 计算用户位置到该路段最近点的距离
                var stepMinDistance = Double.infinity
                for coord in stepCoordinates {
                    let coordLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    let distance = userLocationPoint.distance(from: coordLocation)
                    stepMinDistance = min(stepMinDistance, distance)
                }
                
                // 记录最近的路段
                if stepMinDistance < minDistance {
                    minDistance = stepMinDistance
                    closestStepIndex = index
                }
                
                // 如果距离小于50米，认为用户在该路段上
                if stepMinDistance < 50 {
                    newStepIndex = index
                    break
                }
            }
            
            // 如果当前路段距离太远（>100米），切换到最近的路段
            if minDistance > 100 && closestStepIndex != currentStepIndex {
                newStepIndex = closestStepIndex
            }
            
            // 如果用户已经超过当前路段，检查是否应该进入下一路段
            if newStepIndex == currentStepIndex && currentStepIndex < routeSteps.count - 1 {
                let currentStepCoords = routeStepCoordinates[currentStepIndex]
                if !currentStepCoords.isEmpty {
                    // 检查用户是否接近当前路段的终点
                    let endCoord = currentStepCoords.last!
                    let endLocation = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)
                    let distanceToEnd = userLocationPoint.distance(from: endLocation)
                    
                    // 如果距离终点小于30米，进入下一路段
                    if distanceToEnd < 30 {
                        newStepIndex = min(currentStepIndex + 1, routeSteps.count - 1)
                    }
                }
            }
            
            // 如果路段索引发生变化，更新指引
            if newStepIndex != currentStepIndex {
                print("📍 [导航指引] 路段更新: \(currentStepIndex + 1) -> \(newStepIndex + 1), 距离: \(Int(minDistance))米")
                currentStepIndex = newStepIndex
                updateCurrentStepGuidance()
            }
        }
        
        // 重新规划路线（如果用户偏离路线）
        private func replanRouteIfNeeded() {
            guard let mapView = mapView,
                  let userLocation = mapView.userLocation?.coordinate,
                  let destination = navigationDestination,
                  isNavigating else {
                return
            }
            
            // 防止频繁重新规划：距离上次重新规划至少10秒
            if let lastReplan = lastReplanTime {
                let timeSinceLastReplan = Date().timeIntervalSince(lastReplan)
                if timeSinceLastReplan < 10.0 {
                    print("⏱️ [重新规划] 距离上次重新规划仅 \(Int(timeSinceLastReplan)) 秒，跳过")
                    return
                }
            }
            
            print("🔄 [重新规划] 开始从当前位置重新规划路线")
            print("   当前位置: \(userLocation)")
            print("   目的地: \(destination)")
            
            // 更新UI提示
            DispatchQueue.main.async {
                self.instructionLabel?.text = "已偏离路线，正在重新规划..."
            }
            
            // 记录重新规划时间
            lastReplanTime = Date()
            
            // 从当前位置重新规划到目的地
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.searchWalkingRoute(from: userLocation, to: destination, on: mapView)
            }
        }
        
        // 更新当前路段指引
        private func updateCurrentStepGuidance() {
            guard currentStepIndex < routeSteps.count else { return }
            
            let currentStep = routeSteps[currentStepIndex]
            
            // 获取用户当前位置
            guard let mapView = mapView,
                  let userLocation = mapView.userLocation?.coordinate else {
                // 如果没有位置信息，显示基本指引
                var guidanceText = ""
                if let instruction = currentStep.instruction {
                    guidanceText = instruction
                }
                if let road = currentStep.road {
                    if !guidanceText.isEmpty {
                        guidanceText += " - \(road)"
                    } else {
                        guidanceText = road
                    }
                }
                if guidanceText.isEmpty {
                    guidanceText = "继续前行 \(currentStep.distance)米"
                }
                instructionLabel?.text = guidanceText
                return
            }
            
            let userLocationPoint = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            
            // 计算到当前路段终点的实时距离
            var distanceToStepEnd = Double(currentStep.distance)
            if currentStepIndex < routeStepCoordinates.count {
                let stepCoords = routeStepCoordinates[currentStepIndex]
                if !stepCoords.isEmpty {
                    let endCoord = stepCoords.last!
                    let endLocation = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)
                    distanceToStepEnd = userLocationPoint.distance(from: endLocation)
                }
            }
            
            // 构建导航指引文本（包含实时距离）
            var guidanceText = ""
            
            // 如果即将到达当前路段终点，显示下一路段的指引
            if distanceToStepEnd < 30 && currentStepIndex < routeSteps.count - 1 {
                let nextStep = routeSteps[currentStepIndex + 1]
                if let nextInstruction = nextStep.instruction {
                    guidanceText = "\(Int(distanceToStepEnd))米后\(nextInstruction)"
                } else {
                    guidanceText = "\(Int(distanceToStepEnd))米后进入下一段"
                }
            } else {
                // 显示当前路段指引和实时剩余距离
                if let instruction = currentStep.instruction {
                    guidanceText = "\(instruction)，剩余 \(Int(distanceToStepEnd))米"
                } else {
                    guidanceText = "继续前行，剩余 \(Int(distanceToStepEnd))米"
                }
            }
            
            // 添加道路名称
            if let road = currentStep.road {
                if !guidanceText.contains(road) {
                    guidanceText += " - \(road)"
                }
            }
            
            instructionLabel?.text = guidanceText
            
            // 重新创建指引视图以显示当前路段（距离会在 updateGuidanceViewDistance 中实时更新）
            createRouteGuidanceView()
        }
        
        // 实时更新指引视图中的距离信息（不重新创建视图，只更新文本）
        private func updateGuidanceViewDistance() {
            guard currentStepIndex < routeSteps.count,
                  let mapView = mapView,
                  let userLocation = mapView.userLocation?.coordinate,
                  let guidanceView = routeGuidanceView else {
                return
            }
            
            let currentStep = routeSteps[currentStepIndex]
            let userLocationPoint = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            
            // 计算到当前路段终点的实时距离
            var distanceToStepEnd = Double(currentStep.distance)
            if currentStepIndex < routeStepCoordinates.count {
                let stepCoords = routeStepCoordinates[currentStepIndex]
                if !stepCoords.isEmpty {
                    let endCoord = stepCoords.last!
                    let endLocation = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)
                    distanceToStepEnd = userLocationPoint.distance(from: endLocation)
                }
            }
            
            // 计算到目的地的总距离
            var distanceToDestination = distanceToStepEnd
            if currentStepIndex < routeSteps.count - 1 {
                for index in (currentStepIndex + 1)..<routeSteps.count {
                    distanceToDestination += Double(routeSteps[index].distance)
                }
            }
            
            // 使用 tag 查找距离标签并更新
            if let distanceLabel = findLabelWithTag(in: guidanceView, tag: 9999) {
                let distanceText = distanceToStepEnd >= 1000 ? 
                    String(format: "%.1f公里", distanceToStepEnd / 1000.0) : 
                    "\(Int(distanceToStepEnd))米"
                let destText = distanceToDestination >= 1000 ? 
                    String(format: "%.1f公里", distanceToDestination / 1000.0) : 
                    "\(Int(distanceToDestination))米"
                distanceLabel.text = "剩余: \(distanceText) | 到目的地: \(destText)"
            }
        }
        
        // 递归查找指定 tag 的标签
        private func findLabelWithTag(in view: UIView, tag: Int) -> UILabel? {
            if let label = view as? UILabel, label.tag == tag {
                return label
            }
            for subview in view.subviews {
                if let found = findLabelWithTag(in: subview, tag: tag) {
                    return found
                }
            }
            return nil
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
                // 根据用户位置更新当前路段
                self.updateCurrentStepBasedOnLocation()
                
                // 更新导航指令（这会根据当前路段和实时位置更新）
                self.updateCurrentStepGuidance()
                
                // 实时更新指引视图中的距离信息
                self.updateGuidanceViewDistance()
                
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
                }
            }
        }
        
        // 启动定时器更新导航信息
        private func startNavigationTimer() {
            // 先取消之前的 Timer
            navigationTimer?.invalidate()
            navigationTimer = nil
            
            // 创建新的 Timer 并保存引用
            navigationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self, self.isNavigating else { return }
                
                DispatchQueue.main.async {
                    self.updateNavigationInfo()
                }
            }
        }
        
        // 停止定时器
        private func stopNavigationTimer() {
            navigationTimer?.invalidate()
            navigationTimer = nil
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
            
            // 在导航模式下，不自动调整地图区域，保持用户当前位置为中心
            if !isNavigating {
                // 设置地图区域以显示整条路线（仅非导航模式）
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
                print("✅ [导航] 非导航模式：已设置地图区域显示整条路线")
            } else {
                print("📍 [导航] 导航模式下保持用户位置为中心，不调整地图区域")
            }
            
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
        
        // 更新AR按钮状态
        private func updateARButtonState() {
            DispatchQueue.main.async {
                guard let arButton = self.arButton else { return }
                
                // 只有在导航模式下才启用AR按钮
                let shouldEnable = self.isNavigating && self.currentDest != nil
                
                arButton.isEnabled = shouldEnable
                arButton.backgroundColor = shouldEnable ? .systemBlue : .systemGray
                
                print("🔘 [AR按钮] 状态更新: \(shouldEnable ? "启用(蓝色)" : "禁用(灰色)"), 导航中: \(self.isNavigating), 有目的地: \(self.currentDest != nil)")
            }
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
                
                // 如果正在导航，根据位置更新当前路段和距离
                if isNavigating {
                    updateCurrentStepBasedOnLocation()
                    updateGuidanceViewDistance()
                }
            }
        }
        
        func aMapSearchRequest(_ request: Any!, didFailWithError error: Error!) {
            print("❌ [路线规划] 搜索请求失败：\(error.localizedDescription)")
            
            // 显示错误信息给用户
            DispatchQueue.main.async {
                if self.isNavigating {
                    var errorMessage = "路线规划失败"
                    
                    // 根据错误类型提供更友好的错误信息
                    let errorDescription = error.localizedDescription.lowercased()
                    if errorDescription.contains("network") || errorDescription.contains("网络") {
                        errorMessage = "网络连接失败，请检查网络设置"
                    } else if errorDescription.contains("timeout") || errorDescription.contains("超时") {
                        errorMessage = "请求超时，请重试"
                    } else if errorDescription.contains("key") || errorDescription.contains("密钥") {
                        errorMessage = "API密钥无效，请联系开发者"
                    } else if errorDescription.contains("permission") || errorDescription.contains("权限") {
                        errorMessage = "权限不足，请检查应用权限设置"
                    } else {
                        errorMessage = "路线规划失败：\(error.localizedDescription)"
                    }
                    
                    self.instructionLabel?.text = errorMessage
                    self.remainLabel?.text = "路线规划失败"
                    
                    // 如果正在导航，停止导航状态
                    self.isNavigating = false
                    self.hideNavigationUI()
                    self.showNonNavigationUI()
                }
            }
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