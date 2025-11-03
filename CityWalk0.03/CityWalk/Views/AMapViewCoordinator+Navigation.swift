import AMapNaviKit

extension AMapViewRepresentable.Coordinator {
    
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
    
    // 在原地图界面启用导航
    private func enableNavigationOnMap(destination: CLLocationCoordinate2D) {
        print("🗺️ [导航] 在原地图界面启用导航")
        
        // 🔧 关键：确保原地图可见，导航视图保持隐藏（仅作为数据源）
        mapView?.isHidden = false
        navigationView?.isHidden = true  // 导航视图保持隐藏，只作为数据源
        print("✅ [导航] 原地图可见，导航视图隐藏（仅作为数据源）")
        
        // 确保地图显示用户位置
        mapView?.showsUserLocation = true
        mapView?.userTrackingMode = .followWithHeading
        mapView?.userLocation.title = "我的位置"
        mapView?.userLocation.subtitle = "当前位置"
        print("✅ [导航] 地图用户位置已启用")
        
        // 强制刷新用户位置显示
        mapView?.setNeedsDisplay()
        
        // 延迟添加导航视图到管理器（作为数据源，接收导航数据）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let walkManager = self.parent.walkNavManager.getWalkManager(),
               let navigationView = self.navigationView {
                // 添加导航视图作为数据源（接收导航数据更新，但不显示）
                walkManager.addDataRepresentative(navigationView)
                print("✅ [导航] 导航视图已添加到管理器（作为数据源）")
            }
        }
        
        // 🔧 路线会在路线规划成功后通过 displayRouteOnMap 在原地图上绘制
        // 不需要在这里设置地图中心，路线规划成功后会自动调整地图视野
        
        print("✅ [导航] 导航已在原地图界面启动（使用原地图显示路线）")
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
                        
                        // 使用高德导航SDK进行路线规划（使用Swift桥接的方法名）
                        let startPoints: [AMapNaviPoint] = [startPoint]
                        let endPoints: [AMapNaviPoint] = [endPoint]
                        walkManager.calculateWalkRoute(withStart: startPoints, end: endPoints)
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
            
            // 🔧 确保导航视图保持隐藏（它只作为数据源，不显示）
            self.navigationView?.isHidden = true
            self.navigationView?.alpha = 0
            
            // 清除原地图上的路线
            self.mapView?.removeOverlays(self.mapView?.overlays ?? [])
            
            // 从管理器中移除导航视图
            if let walkManager = self.parent.walkNavManager.getWalkManager(),
               let navigationView = self.navigationView {
                walkManager.removeDataRepresentative(navigationView)
                print("✅ [导航] 导航视图已从管理器移除")
            }
        
            // 隐藏导航UI面板
            self.hideNavigationUI()
        
            // 显示搜索框和其他非导航UI
            self.showNonNavigationUI()
            
            // 确保原地图可见
            self.mapView?.isHidden = false
        
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
}
