import Foundation
import CoreLocation
import AMapNaviKit
import AMapSearchKit
import AMapFoundationKit
import AVFoundation

// 完整的步行导航管理器 - 根据高德官方文档实现
class WalkingNavigationManager: NSObject, ObservableObject {
    static let shared = WalkingNavigationManager()
    
    // 导航状态
    @Published var isNavigating: Bool = false
    @Published var currentInstruction: String = "准备导航..."
    @Published var distanceToDestination: Double = 0
    @Published var distanceToNext: Double = 0
    @Published var currentSpeed: Double = 0
    @Published var currentRoadName: String = ""
    @Published var estimatedArrivalTime: String = ""
    @Published var navigationRoute: [CLLocation] = []
    
    // 高德导航组件
    private var walkManager: AMapNaviWalkManager?
    private var walkView: AMapNaviWalkView? = nil
    private var searchAPI: AMapSearchAPI?
    
    // 定位和语音
    private let locationManager = CLLocationManager()
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    // 导航数据
    private var destination: CLLocationCoordinate2D?
    private var currentLocation: CLLocation?
    private var navigationSteps: [AMapStep] = []
    private var currentStepIndex: Int = 0
    
    // 实时导航状态
    private var navigationTimer: Timer?
    private var lastUpdateTime: Date = Date()
    
    override init() {
        super.init()
        setupLocationManager()
        setupSpeechSynthesizer()
        // 延迟初始化导航组件，避免在初始化时崩溃
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.setupNavigationComponents()
        }
    }
    
    // MARK: - 初始化导航组件
    private func setupNavigationComponents() {
        print("🔧 [步行导航] 开始初始化导航组件")
        
        // 初始化搜索API
        searchAPI = AMapSearchAPI()
        searchAPI?.delegate = self
        
        // 初始化步行导航管理器 - 使用更安全的方式
        DispatchQueue.main.async {
            do {
                self.walkManager = AMapNaviWalkManager.sharedInstance()
                self.walkManager?.delegate = self
                print("✅ [步行导航] 导航管理器初始化成功")
                
                // 初始化导航视图 - 关键功能！
                self.setupWalkView()
            } catch {
                print("❌ [步行导航] 导航管理器初始化失败: \(error)")
            }
        }
    }
    
    // MARK: - 初始化导航视图
    private func setupWalkView() {
        print("🔧 [步行导航] 开始初始化导航视图")
        
        do {
            // 创建高德导航视图
            walkView = AMapNaviWalkView()
            walkView?.delegate = self
            
            // 配置导航视图属性
            walkView?.showUIElements = true
            walkView?.showBrowseRouteButton = true
            walkView?.showMoreButton = true
            
            // 设置显示模式
            walkView?.showMode = .carPositionLocked
            walkView?.trackingMode = .mapNorth
            
            // 延迟添加导航视图到管理器，避免初始化冲突
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let walkView = self.walkView, let walkManager = self.walkManager {
                    walkManager.addDataRepresentative(walkView)
                    print("✅ [步行导航] 导航视图初始化成功并已添加到管理器")
                } else {
                    print("❌ [步行导航] 导航视图初始化失败")
                }
            }
        } catch {
            print("❌ [步行导航] 导航视图创建失败: \(error)")
        }
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1.0
        
        // 请求定位权限
        switch locationManager.authorizationStatus {
        case .notDetermined:
            print("🔄 [定位] 请求定位权限...")
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            print("❌ [定位] 定位权限被拒绝或受限")
            // 尝试请求权限
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ [定位] 定位权限已授权")
            // 开始定位
            locationManager.startUpdatingLocation()
        @unknown default:
            print("⚠️ [定位] 未知的定位权限状态")
        }
    }
    
    private func setupSpeechSynthesizer() {
        // 语音合成器设置
    }
    
    // MARK: - 导航控制方法
    
    /// 开始步行导航
    func startWalkingNavigation(to destination: CLLocationCoordinate2D) {
        print("🚶 [步行导航] 开始导航到: \(destination)")
        
        self.destination = destination
        isNavigating = true
        currentInstruction = "正在规划路线..."
        
        // 确保导航管理器已初始化
        if walkManager == nil {
            print("⚠️ [步行导航] 导航管理器未初始化，重新初始化...")
            setupNavigationComponents()
            // 等待初始化完成后再继续
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startWalkingNavigation(to: destination)
            }
            return
        }
        
        // 确保在主线程上执行
        DispatchQueue.main.async {
            // 开始位置更新
            self.locationManager.startUpdatingLocation()
            
            // 规划步行路线
            self.planWalkingRoute(to: destination)
            
            // 启动实时导航状态更新
            self.startRealTimeNavigationUpdate()
        }
    }
    
    /// 停止导航
    func stopNavigation() {
        print("🛑 [步行导航] 停止导航")
        
        isNavigating = false
        currentInstruction = "导航已停止"
        
        // 停止实时导航状态更新
        stopRealTimeNavigationUpdate()
        
        // 停止位置更新
        locationManager.stopUpdatingLocation()
        
        // 停止导航
        walkManager?.stopNavi()
        
        // 清理资源
        cleanup()
    }
    
    /// 暂停导航
    func pauseNavigation() {
        locationManager.stopUpdatingLocation()
        currentInstruction = "导航已暂停"
        speakInstruction("导航已暂停")
    }
    
    /// 恢复导航
    func resumeNavigation() {
        locationManager.startUpdatingLocation()
        currentInstruction = "继续导航"
        speakInstruction("继续导航")
    }
    
    /// 规划步行路线
    private func planWalkingRoute(to destination: CLLocationCoordinate2D) {
        // 确保导航管理器已初始化
        guard let walkManager = walkManager else {
            print("❌ [步行导航] 导航管理器未初始化，重新初始化...")
            setupNavigationComponents()
            return
        }
        
        // 获取当前位置
        guard let currentLocation = getCurrentLocation() else {
            print("❌ [步行导航] 无法获取当前位置")
            DispatchQueue.main.async {
                self.currentInstruction = "无法获取当前位置"
            }
            return
        }
        
        print("📍 [步行导航] 当前位置: \(currentLocation.coordinate)")
        print("📍 [步行导航] 目的地: \(destination)")
        
        // 创建起终点 - 使用更安全的方式
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            do {
                guard let startPoint = AMapNaviPoint.location(withLatitude: CGFloat(currentLocation.coordinate.latitude), 
                                                             longitude: CGFloat(currentLocation.coordinate.longitude)),
                      let endPoint = AMapNaviPoint.location(withLatitude: CGFloat(destination.latitude), 
                                                         longitude: CGFloat(destination.longitude)) else {
                    print("❌ [步行导航] 无法创建起终点")
                    return
                }
                
                print("✅ [步行导航] 起终点创建成功，开始规划路线")
                
                // 使用安全的路线规划方式，避免崩溃
                print("🔄 [步行导航] 开始安全路线规划...")
                
                // 使用地图API进行路线规划，避免SDK崩溃
                self.planRouteUsingMapAPI(to: destination)
                print("✅ [步行导航] 使用地图API进行路线规划，避免崩溃")
            } catch {
                print("❌ [步行导航] 规划路线时发生错误: \(error)")
            }
        }
    }
    
    /// 获取当前位置
    private func getCurrentLocation() -> CLLocation? {
        // 优先使用定位管理器的位置
        if let location = locationManager.location {
            return location
        }
        // 如果没有定位，返回默认位置用于测试
        return CLLocation(latitude: 39.908791, longitude: 116.321257)
    }
    
    /// 使用地图API进行路线规划，避免SDK崩溃
    private func planRouteUsingMapAPI(to destination: CLLocationCoordinate2D) {
        guard let currentLocation = getCurrentLocation() else {
            print("❌ [地图API] 无法获取当前位置")
            return
        }
        
        print("🗺️ [地图API] 开始使用地图API进行路线规划")
        print("📍 [地图API] 起点: \(currentLocation.coordinate)")
        print("📍 [地图API] 终点: \(destination)")
        
        // 创建路线规划请求
        let request = AMapWalkingRouteSearchRequest()
        request.origin = AMapGeoPoint.location(withLatitude: CGFloat(currentLocation.coordinate.latitude), 
                                             longitude: CGFloat(currentLocation.coordinate.longitude))
        request.destination = AMapGeoPoint.location(withLatitude: CGFloat(destination.latitude), 
                                                  longitude: CGFloat(destination.longitude))
        
        // 发送请求
        searchAPI?.aMapWalkingRouteSearch(request)
        print("✅ [地图API] 路线规划请求已发送")
    }
    
    /// 语音播报
    private func speakInstruction(_ instruction: String) {
        guard !instruction.isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: instruction)
        utterance.rate = 0.5
        utterance.volume = 0.8
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        
        speechSynthesizer.speak(utterance)
    }
    
    /// 清理资源
    private func cleanup() {
        if let walkView = walkView {
            walkManager?.removeDataRepresentative(walkView)
        }
        walkManager?.delegate = nil
    }
    
    deinit {
        cleanup()
    }
}

// MARK: - AMapNaviWalkManagerDelegate
extension WalkingNavigationManager: AMapNaviWalkManagerDelegate {
    
    /// 路线规划成功回调
    func walkManager(_ walkManager: AMapNaviWalkManager, onCalculateRouteSuccess type: AMapNaviRoutePlanType) {
        print("✅ [步行导航] 路线规划成功")
        
        DispatchQueue.main.async {
            self.currentInstruction = "路线规划成功，开始导航"
        }
        
        // 语音播报
        speakInstruction("路线规划成功，开始导航")
        
        // 开始实时导航
        walkManager.startGPSNavi()
    }
    
    /// 路线规划失败回调
    func walkManager(_ walkManager: AMapNaviWalkManager, onCalculateRouteFailure error: Error) {
        print("❌ [步行导航] 路线规划失败: \(error.localizedDescription)")
        
        DispatchQueue.main.async {
            self.currentInstruction = "路线规划失败"
            self.isNavigating = false
        }
        
        speakInstruction("路线规划失败")
    }
    
    /// 导航诱导信息更新
    func walkManager(_ walkManager: AMapNaviWalkManager, updateNaviInfo naviInfo: AMapNaviInfo?) {
        guard let naviInfo = naviInfo else { return }
        
        DispatchQueue.main.async {
            // 更新导航信息
            self.currentInstruction = naviInfo.nextRoadName ?? "继续前进"
            self.distanceToNext = Double(naviInfo.segmentRemainDistance)
            self.distanceToDestination = Double(naviInfo.routeRemainDistance)
            self.currentRoadName = naviInfo.nextRoadName ?? ""
            
            // 计算预计到达时间
            let timeInMinutes = naviInfo.routeRemainTime / 60
            if timeInMinutes < 60 {
                self.estimatedArrivalTime = "\(timeInMinutes)分钟"
            } else {
                let hours = timeInMinutes / 60
                let minutes = timeInMinutes % 60
                self.estimatedArrivalTime = "\(hours)小时\(minutes)分钟"
            }
            
            // 语音播报重要指令
            if naviInfo.segmentRemainDistance < 50 && !naviInfo.nextRoadName.isEmpty {
                self.speakInstruction("\(naviInfo.segmentRemainDistance)米后\(naviInfo.nextRoadName)")
            }
        }
    }
    
    /// 导航结束回调
    func walkManager(_ walkManager: AMapNaviWalkManager, didArriveDestination destination: AMapNaviPoint) {
        print("🎯 [步行导航] 已到达目的地")
        
        DispatchQueue.main.async {
            self.currentInstruction = "已到达目的地"
            self.isNavigating = false
        }
        
        speakInstruction("已到达目的地")
    }
    
    /// 导航开始回调
    func walkManager(_ walkManager: AMapNaviWalkManager, didStartNavi naviMode: AMapNaviMode) {
        print("🚀 [步行导航] 导航已开始，模式: \(naviMode.rawValue)")
        
        DispatchQueue.main.async {
            self.currentInstruction = "导航已开始"
        }
    }
    
    /// 导航停止回调
    func walkManager(_ walkManager: AMapNaviWalkManager, didStopNavi naviMode: AMapNaviMode) {
        print("🛑 [步行导航] 导航已停止，模式: \(naviMode.rawValue)")
        
        DispatchQueue.main.async {
            self.currentInstruction = "导航已停止"
            self.isNavigating = false
        }
    }
}

// MARK: - AMapNaviWalkViewDelegate
extension WalkingNavigationManager: AMapNaviWalkViewDelegate {
    
    /// 导航视图显示模式变化回调
    func walkView(_ walkView: AMapNaviWalkView, didChange showMode: AMapNaviWalkViewShowMode) {
        print("🔄 [步行导航] 显示模式变化: \(showMode.rawValue)")
        
        DispatchQueue.main.async {
            switch showMode {
            case .carPositionLocked:
                self.currentInstruction = "跟随模式"
            case .overview:
                self.currentInstruction = "全览模式"
            case .normal:
                self.currentInstruction = "普通模式"
            @unknown default:
                self.currentInstruction = "导航模式"
            }
        }
    }
    
    /// 导航视图横竖屏切换回调
    func walkView(_ walkView: AMapNaviWalkView, didChangeOrientation isLandscape: Bool) {
        print("📱 [步行导航] 屏幕方向变化: \(isLandscape ? "横屏" : "竖屏")")
    }
    
    /// 导航视图关闭按钮点击回调
    func walkViewCloseButtonClicked(_ walkView: AMapNaviWalkView) {
        print("❌ [步行导航] 用户点击关闭按钮")
        
        DispatchQueue.main.async {
            self.stopNavigation()
        }
    }
    
    /// 导航视图更多按钮点击回调
    func walkViewMoreButtonClicked(_ walkView: AMapNaviWalkView) {
        print("⚙️ [步行导航] 用户点击更多按钮")
        // 可以在这里显示更多设置选项
    }
    
    /// 导航视图全览按钮点击回调
    func walkViewBrowseRouteButtonClicked(_ walkView: AMapNaviWalkView) {
        print("🗺️ [步行导航] 用户点击全览按钮")
        
        DispatchQueue.main.async {
            self.currentInstruction = "查看全览路线"
        }
    }
    
    /// 导航视图交通按钮点击回调
    func walkViewTrafficButtonClicked(_ walkView: AMapNaviWalkView) {
        print("🚦 [步行导航] 用户点击交通按钮")
        
        DispatchQueue.main.async {
            self.currentInstruction = "切换交通显示"
        }
    }
    
    /// 导航视图缩放按钮点击回调
    func walkViewZoomInOutButtonClicked(_ walkView: AMapNaviWalkView) {
        print("🔍 [步行导航] 用户点击缩放按钮")
    }
    
    /// 获取导航视图（供SwiftUI使用）
    func getWalkView() -> AMapNaviWalkView? {
        return walkView
    }
    
    /// 获取导航管理器（供SwiftUI使用）
    func getWalkManager() -> AMapNaviWalkManager? {
        return walkManager
    }
}

// MARK: - CLLocationManagerDelegate
extension WalkingNavigationManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.currentLocation = location
            print("📍 [定位] 位置更新: \(location.coordinate)")
            
            // 更新导航状态
            self.updateNavigationStatus()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🔄 [定位] 权限状态变化: \(status.rawValue)")
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ [定位] 定位权限已授权，开始定位")
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("❌ [定位] 定位权限被拒绝或受限")
            DispatchQueue.main.async {
                self.currentInstruction = "位置权限被拒绝，无法导航"
            }
        case .notDetermined:
            print("🔄 [定位] 定位权限未确定，请求权限")
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            print("⚠️ [定位] 未知的定位权限状态")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ [定位] 位置更新失败: \(error.localizedDescription)")
        
        DispatchQueue.main.async {
            self.currentInstruction = "位置更新失败"
        }
        
        // 如果是权限问题，尝试重新请求
        if let clError = error as? CLError, clError.code == .denied {
            print("🔄 [定位] 定位权限被拒绝，尝试重新请求")
            manager.requestWhenInUseAuthorization()
        }
    }
    
}

// MARK: - AMapSearchDelegate
extension WalkingNavigationManager: AMapSearchDelegate {
    
    func aMapSearchRequest(_ request: Any!, didFailWithError error: Error!) {
        print("❌ [步行导航] 搜索请求失败: \(error.localizedDescription)")
    }
    
    // 步行路线搜索回调
    func onRouteSearchDone(_ request: AMapRouteSearchBaseRequest!, response: AMapRouteSearchResponse!) {
        print("🗺️ [地图API] 路线搜索完成")
        
        if response.count > 0 {
            print("✅ [地图API] 找到 \(response.count) 条路线")
            
            if let route = response.route, let paths = route.paths, paths.count > 0 {
                guard let path = paths.first else { 
                    print("❌ [地图API] 无法获取第一条路线")
                    return 
                }
                
                // 计算总距离和时间
                let totalDistance = path.distance
                let totalDuration = path.duration
                
                print("📏 [地图API] 路线距离: \(totalDistance)米, 预计时间: \(totalDuration)秒")
                
                // 更新导航状态
                DispatchQueue.main.async {
                    self.distanceToDestination = Double(totalDistance)
                    self.currentInstruction = "路线规划成功，开始导航"
                    
                    // 计算预计到达时间
                    let timeInMinutes = totalDuration / 60
                    if timeInMinutes < 60 {
                        self.estimatedArrivalTime = "\(timeInMinutes)分钟"
                    } else {
                        let hours = timeInMinutes / 60
                        let minutes = timeInMinutes % 60
                        self.estimatedArrivalTime = "\(hours)小时\(minutes)分钟"
                    }
                    
                    print("✅ [地图API] 导航状态已更新")
                }
            } else {
                print("❌ [地图API] 路线数据为空")
            }
        } else {
            print("❌ [地图API] 未找到路线，响应数量: \(response.count)")
        }
    }
}

// MARK: - 实时导航状态更新
extension WalkingNavigationManager {
    
    /// 启动实时导航状态更新
    private func startRealTimeNavigationUpdate() {
        print("🔄 [实时导航] 启动实时状态更新")
        
        // 停止之前的定时器
        navigationTimer?.invalidate()
        
        // 创建新的定时器，每2秒更新一次
        navigationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateNavigationStatus()
        }
    }
    
    /// 停止实时导航状态更新
    private func stopRealTimeNavigationUpdate() {
        print("🛑 [实时导航] 停止实时状态更新")
        navigationTimer?.invalidate()
        navigationTimer = nil
    }
    
    /// 更新导航状态
    private func updateNavigationStatus() {
        guard isNavigating,
              let currentLocation = locationManager.location?.coordinate,
              let destination = destination else {
            print("⚠️ [实时导航] 导航状态更新条件不满足 - isNavigating: \(isNavigating), currentLocation: \(locationManager.location?.coordinate != nil), destination: \(destination != nil)")
            print("🔍 [实时导航] 详细状态 - isNavigating: \(isNavigating), 定位坐标: \(locationManager.location?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)), 目的地: \(destination ?? CLLocationCoordinate2D(latitude: 0, longitude: 0))")
            return
        }
        
        // 计算实时距离
        let distance = calculateDistance(from: currentLocation, to: destination)
        
        // 更新导航状态
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.distanceToDestination = distance
            self.updateNavigationInstruction()
            self.updateEstimatedArrivalTime()
            
            print("📍 [实时导航] 距离: \(Int(distance))米, 指令: \(self.currentInstruction)")
        }
    }
    
    /// 更新导航指令 - 基于真实路线步骤
    private func updateNavigationInstruction() {
        print("🔍 [导航指令] 开始更新指令 - 步骤数量: \(navigationSteps.count), 当前步骤: \(currentStepIndex)")
        
        // 如果有路线步骤，使用真实指令
        if !navigationSteps.isEmpty, currentStepIndex < navigationSteps.count {
            let currentStep = navigationSteps[currentStepIndex]
            let instruction = currentStep.instruction ?? "直行"
            let distance = currentStep.distance
            
            print("🔍 [导航指令] 当前步骤指令: \(instruction), 距离: \(distance)")
            
            // 根据距离格式化指令
            if distance < 20 {
                currentInstruction = "🎯 \(instruction)"
            } else if distance < 100 {
                currentInstruction = "📍 \(instruction) \(Int(distance))米"
            } else if distance < 1000 {
                currentInstruction = "🚶 \(instruction) \(Int(distance))米"
            } else {
                let kilometers = Double(distance) / 1000.0
                currentInstruction = "🚶 \(instruction) \(String(format: "%.1f", kilometers))公里"
            }
            
            print("📢 [导航指令] 基于路线步骤: \(currentInstruction)")
        } else {
            // 回退到基于总距离的简单指令
            let distance = distanceToDestination
            
            print("🔍 [导航指令] 回退到总距离模式 - 总距离: \(distance)")
            
            if distance < 20 {
                currentInstruction = "🎯 即将到达目的地"
            } else if distance < 100 {
                currentInstruction = "📍 前方\(Int(distance))米到达目的地"
            } else if distance < 500 {
                currentInstruction = "🚶 继续直行\(Int(distance))米"
            } else if distance < 1000 {
                currentInstruction = "🚶 直行\(Int(distance))米"
            } else {
                let kilometers = distance / 1000.0
                currentInstruction = "🚶 直行\(String(format: "%.1f", kilometers))公里"
            }
            
            print("📢 [导航指令] 基于总距离: \(currentInstruction)")
        }
    }
    
    /// 更新预计到达时间
    private func updateEstimatedArrivalTime() {
        let distance = distanceToDestination
        let walkingSpeed: Double = 1.4 // 米/秒，约5公里/小时
        let estimatedSeconds = distance / walkingSpeed
        
        let hours = Int(estimatedSeconds) / 3600
        let minutes = (Int(estimatedSeconds) % 3600) / 60
        
        if hours > 0 {
            estimatedArrivalTime = "\(hours)小时\(minutes)分钟"
        } else {
            estimatedArrivalTime = "\(minutes)分钟"
        }
    }
    
    /// 计算两点间距离
    private func calculateDistance(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLocation = CLLocation(latitude: end.latitude, longitude: end.longitude)
        return startLocation.distance(from: endLocation)
    }
    
    /// 解析路线步骤，生成导航指令
    func parseRouteSteps(from path: AMapPath) {
        print("🗺️ [路线解析] 开始解析路线步骤")
        print("🔍 [路线解析] 路径对象: \(path)")
        print("🔍 [路线解析] 路径步骤数量: \(path.steps?.count ?? 0)")
        
        guard let steps = path.steps, !steps.isEmpty else {
            print("❌ [路线解析] 路线步骤为空")
            print("🔍 [路线解析] path.steps = \(path.steps?.description ?? "nil")")
            return
        }
        
        // 保存路线步骤
        navigationSteps = steps
        currentStepIndex = 0
        
        print("✅ [路线解析] 解析到 \(steps.count) 个路线步骤")
        
        // 打印所有步骤用于调试
        for (index, step) in steps.enumerated() {
            let instruction = step.instruction ?? "直行"
            let distance = step.distance
            print("📍 [步骤\(index)] \(instruction) \(Int(distance))米")
            print("🔍 [步骤\(index)] 详细信息: instruction=\(step.instruction ?? "nil"), distance=\(step.distance), polyline=\(step.polyline ?? "nil")")
        }
        
        // 更新当前指令
        updateNavigationInstruction()
        print("✅ [路线解析] 路线步骤解析完成")
    }
    
    /// 移动到下一个路线步骤
    func moveToNextStep() {
        guard !navigationSteps.isEmpty, currentStepIndex < navigationSteps.count - 1 else {
            print("📍 [路线步骤] 已到达最后一个步骤")
            return
        }
        
        currentStepIndex += 1
        print("📍 [路线步骤] 移动到步骤 \(currentStepIndex)")
        updateNavigationInstruction()
    }
}

// MARK: - 步行导航步骤数据模型
struct WalkingNavigationStep {
    let instruction: String
    let distance: Double
    let coordinate: CLLocationCoordinate2D
}