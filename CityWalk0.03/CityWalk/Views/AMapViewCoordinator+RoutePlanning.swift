import AMapSearchKit
import AMapNaviKit
import CoreLocation

extension AMapViewRepresentable.Coordinator {
    
    // 使用高德地图API进行路线规划，避免导航SDK崩溃
    func calculateRouteUsingAMapAPI(to destination: CLLocationCoordinate2D) {
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
        print("🔍 [地图API] 搜索API状态: 已初始化")
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
    
    // 绘制导航路线
    func drawNavigationRoute(to destination: CLLocationCoordinate2D) {
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
    
    // 在地图上显示详细路线
    func displayRouteOnMap(path: AMapPath) {
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
}
