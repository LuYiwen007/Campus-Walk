import AMapNaviKit
import AMapSearchKit

extension AMapViewRepresentable.Coordinator {
    
    // MARK: - AMapNaviWalkViewDelegate
    
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
    
    // MARK: - AMapSearchDelegate 路线搜索回调
    
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
}
