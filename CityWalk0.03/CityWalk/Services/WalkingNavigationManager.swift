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
    private var navigationSteps: [WalkingNavigationStep] = []
    private var currentStepIndex: Int = 0
    
    /// 语音节流：避免诱导回调过于频繁时连续播报
    private var lastSpeechDate: Date = .distantPast
    private var lastSpeechBucket: Int = -9999
    
    override init() {
        super.init()
        setupLocationManager()
        setupSpeechSynthesizer()
        // 延迟初始化导航组件，避免在初始化时崩溃
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
            } catch {
                print("❌ [步行导航] 导航管理器初始化失败: \(error)")
            }
        }
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1.0
        locationManager.requestWhenInUseAuthorization()
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
        }
    }
    
    /// 停止导航
    func stopNavigation() {
        print("🛑 [步行导航] 停止导航")
        
        isNavigating = false
        currentInstruction = "导航已停止"
        lastSpeechBucket = -9999
        
        // 停止位置更新
        locationManager.stopUpdatingLocation()
        
        // 停止导航（单例长期存活，不要 nil delegate，否则下次无法收到诱导回调）
        walkManager?.stopNavi()
        walkManager?.delegate = self
        
        speakInstruction("导航已停止")
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
                
                // 开始规划路线
                walkManager.calculateWalkRoute(withStart: [startPoint], 
                                             end: [endPoint])
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
    
    /// 语音播报
    private func speakInstruction(_ instruction: String) {
        guard !instruction.isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: instruction)
        utterance.rate = 0.5
        utterance.volume = 0.8
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        
        speechSynthesizer.speak(utterance)
    }
    
    /// 清理资源（仅用于实例释放；shared 单例一般不走这里）
    private func cleanup() {
        locationManager.stopUpdatingLocation()
        if let walkView = walkView {
            walkManager?.removeDataRepresentative(walkView)
        }
        walkManager?.delegate = nil
        searchAPI?.delegate = nil
    }
    
    deinit {
        cleanup()
        print("✅ [WalkingNavigationManager] 资源已清理")
    }
}

// MARK: - AMapNaviWalkManagerDelegate
extension WalkingNavigationManager: AMapNaviWalkManagerDelegate {
    
    /// 路线规划成功回调
    func walkManager(_ walkManager: AMapNaviWalkManager, onCalculateRouteSuccess type: AMapNaviRoutePlanType) {
        print("✅ [步行导航] 路线规划成功")
        
        lastSpeechBucket = -9999
        lastSpeechDate = .distantPast
        
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
        
        let roadName = naviInfo.nextRoadName ?? ""
        let segRemain = Int(naviInfo.segmentRemainDistance)
        let routeRemain = Double(naviInfo.routeRemainDistance)
        
        DispatchQueue.main.async {
            let headline: String
            if roadName.isEmpty {
                headline = segRemain > 0 ? "沿路线前行，下一段 \(segRemain) 米" : "继续前进"
            } else {
                headline = segRemain > 0 ? "\(segRemain)米后\(roadName)" : roadName
            }
            self.currentInstruction = headline
            self.distanceToNext = Double(segRemain)
            self.distanceToDestination = routeRemain
            self.currentRoadName = roadName
            
            let timeInMinutes = naviInfo.routeRemainTime / 60
            if timeInMinutes < 60 {
                self.estimatedArrivalTime = "\(timeInMinutes)分钟"
            } else {
                let hours = timeInMinutes / 60
                let minutes = timeInMinutes % 60
                self.estimatedArrivalTime = "\(hours)小时\(minutes)分钟"
            }
            
            // 语音：约每 50 米进度或至少间隔 8 秒播报一次（近路口更密）
            let bucket = segRemain / 50
            let now = Date()
            let minInterval: TimeInterval = segRemain < 35 ? 4.0 : 8.0
            let shouldSpeak = segRemain > 8 && (
                bucket != self.lastSpeechBucket || now.timeIntervalSince(self.lastSpeechDate) >= minInterval
            )
            if shouldSpeak {
                self.lastSpeechBucket = bucket
                self.lastSpeechDate = now
                let line: String
                if roadName.isEmpty {
                    line = "前方步行\(segRemain)米，请按地图路线前进"
                } else {
                    line = "\(segRemain)米后\(roadName)"
                }
                self.speakInstruction(line)
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

// MARK: - CLLocationManagerDelegate
extension WalkingNavigationManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentLocation = location
        
        // 更新导航状态
        updateNavigationStatus()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("位置权限被拒绝")
            currentInstruction = "位置权限被拒绝，无法导航"
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置更新失败: \(error.localizedDescription)")
        currentInstruction = "位置更新失败"
    }
    
    private func updateNavigationStatus() {
        guard let currentLocation = currentLocation,
              let destination = destination else { return }
        
        // 计算到目的地的距离
        distanceToDestination = currentLocation.distance(from: CLLocation(
            latitude: destination.latitude,
            longitude: destination.longitude
        ))
        
        // 更新速度
        currentSpeed = currentLocation.speed
    }
}

// MARK: - AMapSearchDelegate
extension WalkingNavigationManager: AMapSearchDelegate {
    
    func aMapSearchRequest(_ request: Any!, didFailWithError error: Error!) {
        print("❌ [步行导航] 搜索请求失败: \(error.localizedDescription)")
    }
}

// MARK: - 步行导航步骤数据模型
struct WalkingNavigationStep {
    let instruction: String
    let distance: Double
    let coordinate: CLLocationCoordinate2D
}