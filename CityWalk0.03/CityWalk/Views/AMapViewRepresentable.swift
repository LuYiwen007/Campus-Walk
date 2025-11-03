import SwiftUI
import AMapNaviKit
import AMapSearchKit
import CoreLocation
import AMapLocationKit
import AMapFoundationKit

struct AMapViewRepresentable: UIViewRepresentable {
    // 基本属性
    let startCoordinate: CLLocationCoordinate2D?
    let destination: CLLocationCoordinate2D?
    var centerCoordinate: CLLocationCoordinate2D? = nil
    var showSearchBar: Bool = true
    
    // 导航相关
    @StateObject var walkNavManager = WalkingNavigationManager.shared
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
        
        // 检测导航状态：如果导航管理器已启动导航，且 Coordinator 尚未处于导航状态，则启动原地图导航
        if let dest = destination, walkNavManager.isNavigating, !context.coordinator.isNavigating {
            print("🚀 [AMapViewRepresentable] 检测到导航管理器已启动，触发原地图导航")
            context.coordinator.startWalkingNavigation(to: dest)
        }
        
        // 自动规划路线（非导航模式）
        if let start = startCoordinate, let dest = destination, !walkNavManager.isNavigating {
            if context.coordinator.lastRouteStart != start || context.coordinator.lastRouteDest != dest {
                context.coordinator.lastRouteStart = start
                context.coordinator.lastRouteDest = dest
                context.coordinator.searchWalkingRoute(from: start, to: dest, on: mapView)
            }
        }
    }
    
    // MARK: - 导航UI - 按照高德官方样式
    private func addNavigationUI(to container: UIView, coordinator: Coordinator) {
        // 顶部导航信息栏 - 深色背景，考虑安全区域（避免被状态栏遮挡）
        let topInfoView = UIView()
        topInfoView.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        topInfoView.translatesAutoresizingMaskIntoConstraints = false
        topInfoView.isHidden = true
        
        // 🔧 确保顶部导航信息栏在最上层且可见
        topInfoView.layer.zPosition = 1000
        
        // 转向图标
        let turnIconView = UIImageView()
        turnIconView.contentMode = .scaleAspectFit
        turnIconView.image = UIImage(systemName: "arrow.right")
        turnIconView.tintColor = .white
        turnIconView.translatesAutoresizingMaskIntoConstraints = false
        topInfoView.addSubview(turnIconView)
        
        // 导航指令 - 合并距离和道路名称
        let instructionLabel = UILabel()
        instructionLabel.text = "准备导航..."
        instructionLabel.textColor = .white
        instructionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        instructionLabel.numberOfLines = 1
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.backgroundColor = UIColor.clear
        instructionLabel.isHidden = false
        topInfoView.addSubview(instructionLabel)
        
        container.addSubview(topInfoView)
        
        // 🔧 关键：确保UI面板在最上层（在所有其他视图之上）
        container.bringSubviewToFront(topInfoView)
        
        NSLayoutConstraint.activate([
            // 🔧 关键：顶部信息栏 - 从安全区域顶部开始（避免被状态栏遮挡）
            topInfoView.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 0),
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
        // 🔧 关键：创建导航视图但完全隐藏，只作为数据源使用
        // 这个视图不会显示，只用于接收 AMapNaviWalkManager 的导航数据更新
        // 原地图将显示路线，自定义UI面板将显示导航信息
        let walkView = AMapNaviWalkView()
        walkView.delegate = coordinator
        
        // 禁用所有UI元素（这个视图不用于显示）
        walkView.showUIElements = false
        walkView.showBrowseRouteButton = false
        walkView.showMoreButton = false
        
        // 🔧 关键：完全隐藏这个视图
        walkView.isHidden = true
        walkView.alpha = 0
        walkView.isUserInteractionEnabled = false  // 不接收触摸事件
        
        walkView.backgroundColor = UIColor.clear
        walkView.isOpaque = false
        
        // 添加到容器（但隐藏，不影响原地图）
        container.addSubview(walkView)
        walkView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            walkView.topAnchor.constraint(equalTo: container.topAnchor),
            walkView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            walkView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            walkView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // 🔧 关键：放在最底层，不影响原地图和自定义UI
        container.sendSubviewToBack(walkView)
        
        // 保存引用
        coordinator.navigationView = walkView
        
        print("✅ [导航] 导航视图已添加（仅作为数据源，完全隐藏）")
        print("🔍 [导航] 使用原地图显示路线，自定义UI显示导航信息")
    }
}
