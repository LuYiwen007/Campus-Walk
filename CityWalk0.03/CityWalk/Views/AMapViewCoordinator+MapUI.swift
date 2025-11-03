import UIKit

extension AMapViewRepresentable.Coordinator {
    
    // 确保导航UI在最顶层
    func ensureNavigationUIOnTop() {
        print("🔍 [UI调试] 确保导航UI在最顶层")
        
        // 确保顶部和底部面板都在最顶层
        if let topView = topInfoView, let bottomView = bottomNavView {
            // 获取共同的父容器
            if let container = topView.superview {
                // 🔧 关键：确保原地图在中层，自定义导航UI在最上层
                // 导航视图在最底层（已隐藏）
                if let mapView = mapView {
                    container.bringSubviewToFront(mapView)  // 原地图在中层
                }
                container.bringSubviewToFront(topView)      // 顶部导航UI在最上层
                container.bringSubviewToFront(bottomView)    // 底部导航UI在最上层
                print("✅ [UI调试] 导航UI已置于最顶层，原地图在中层")
            } else {
                print("❌ [UI调试] 无法找到容器视图")
            }
        } else {
            print("❌ [UI调试] 导航UI视图未初始化")
        }
    }
    
    // 显示导航信息面板
    func showNavigationInfoPanel() {
        print("📱 [导航] 显示导航信息面板")
        
        // 🔧 显示顶部和底部导航面板，确保完全可见
        if let topInfoView = topInfoView {
            topInfoView.isHidden = false
            topInfoView.alpha = 1.0
            topInfoView.superview?.bringSubviewToFront(topInfoView)
            topInfoView.setNeedsDisplay()
            topInfoView.setNeedsLayout()
            topInfoView.layoutIfNeeded()
            print("✅ [UI调试] 顶部导航面板已显示并刷新")
        }
        
        if let bottomNavView = bottomNavView {
            bottomNavView.isHidden = false
            bottomNavView.alpha = 1.0
            bottomNavView.superview?.bringSubviewToFront(bottomNavView)
            bottomNavView.setNeedsDisplay()
            bottomNavView.setNeedsLayout()
            bottomNavView.layoutIfNeeded()
        }
        
        // 🔧 确保指令标签可见
        if let instructionLabel = instructionLabel {
            instructionLabel.isHidden = false
            instructionLabel.alpha = 1.0
            instructionLabel.setNeedsDisplay()
            print("✅ [UI调试] 指令标签已显示: \(instructionLabel.text ?? "nil")")
        }
        
        // 添加调试信息
        print("🔍 [UI调试] topInfoView状态: \(topInfoView?.isHidden == false ? "显示" : "隐藏")")
        print("🔍 [UI调试] bottomNavView状态: \(bottomNavView?.isHidden == false ? "显示" : "隐藏")")
        print("🔍 [UI调试] topInfoView父视图: \(topInfoView?.superview != nil ? "存在" : "nil")")
        print("🔍 [UI调试] bottomNavView父视图: \(bottomNavView?.superview != nil ? "存在" : "nil")")
        
        // 确保导航面板在最上层
        if let topInfoView = topInfoView {
            topInfoView.superview?.bringSubviewToFront(topInfoView)
        }
        if let bottomNavView = bottomNavView {
            bottomNavView.superview?.bringSubviewToFront(bottomNavView)
        }
        
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
    
    // 更新导航信息 - 优先使用WalkingNavigationManager的数据
    func updateNavigationInfo() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 🔧 更新导航指令 - 使用WalkingNavigationManager的实时指令
            let instruction = self.parent.walkNavManager.currentInstruction
            if let instructionLabel = self.instructionLabel {
                instructionLabel.text = instruction
                instructionLabel.isHidden = false
                instructionLabel.setNeedsDisplay()
                print("📢 [UI更新] 导航指令已更新: \(instruction)")
                print("🔍 [UI调试] instructionLabel状态: isHidden=\(instructionLabel.isHidden), text=\(instructionLabel.text ?? "nil")")
            } else {
                print("❌ [UI更新] instructionLabel为nil，无法更新指令")
            }
            
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
            
            // 🔧 强制刷新顶部导航信息栏
            self.topInfoView?.setNeedsDisplay()
            self.topInfoView?.setNeedsLayout()
            self.topInfoView?.layoutIfNeeded()
            
            // 🔧 确保顶部导航信息栏在最上层
            if let topInfoView = self.topInfoView {
                topInfoView.superview?.bringSubviewToFront(topInfoView)
                topInfoView.isHidden = false
                topInfoView.alpha = 1.0
            }
        }
    }
    
    // 启动定时器更新导航信息 - 显示WalkingNavigationManager的实时数据
    func startNavigationTimer() {
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
    
    // 跳转到起始位置
    func jumpToStartLocation() {
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
    
    // 更新导航信息（带路线数据）
    func updateNavigationInfoWithRouteData(distance: Double, duration: Double) {
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
    
    // 确保导航视图显示路线
    func ensureNavigationViewShowsRoute() {
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
