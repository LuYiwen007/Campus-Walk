import Foundation
import CoreLocation
import AVFoundation
import Combine

// 简化的导航管理器，避免复杂的内存管理问题
class SimpleNavigationManager: NSObject, ObservableObject {
    static let shared = SimpleNavigationManager()
    
    @Published var isNavigating: Bool = false
    @Published var currentInstruction: String = "正在定位..."
    @Published var distanceToDestination: Double = 0
    @Published var distanceToNext: Double = 0
    @Published var currentSpeed: Double = 0
    @Published var currentRoadName: String = ""
    @Published var estimatedArrivalTime: String = "--"
    @Published var navigationRoute: [CLLocation] = []
    
    // 定位和语音
    private let locationManager = CLLocationManager()
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    // 导航数据
    private var destination: CLLocationCoordinate2D?
    private var currentLocation: CLLocation?
    private var navigationTimer: Timer?
    
    override init() {
        super.init()
        setupLocationManager()
        setupSpeechSynthesizer()
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
        print("🚶 [简化导航] 开始导航到: \(destination)")
        
        self.destination = destination
        isNavigating = true
        currentInstruction = "正在规划路线..."
        
        // 开始位置更新
        locationManager.startUpdatingLocation()
        
        // 模拟路线规划
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.simulateRoutePlanning()
        }
    }
    
    /// 停止导航
    func stopNavigation() {
        print("🛑 [简化导航] 停止导航")
        
        isNavigating = false
        currentInstruction = "导航已停止"
        navigationTimer?.invalidate()
        navigationTimer = nil
        locationManager.stopUpdatingLocation()
        speakInstruction("导航已停止")
    }
    
    /// 暂停导航
    func pauseNavigation() {
        print("⏸️ [简化导航] 暂停导航")
        navigationTimer?.invalidate()
        currentInstruction = "导航已暂停"
        speakInstruction("导航已暂停")
    }
    
    /// 恢复导航
    func resumeNavigation() {
        print("▶️ [简化导航] 恢复导航")
        currentInstruction = "继续导航"
        startNavigationTimer()
        speakInstruction("继续导航")
    }
    
    // MARK: - 模拟路线规划
    
    private func simulateRoutePlanning() {
        print("🗺️ [简化导航] 开始路线规划")
        
        // 使用真实位置计算距离
        if let currentLocation = currentLocation, let destination = destination {
            let distance = currentLocation.distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
            distanceToDestination = distance
            
            // 根据真实距离计算预计时间（步行速度5km/h）
            let walkingSpeed = 5.0 // km/h
            let timeInHours = distance / 1000.0 / walkingSpeed
            let timeInMinutes = Int(timeInHours * 60)
            estimatedArrivalTime = "\(timeInMinutes)分钟"
            
            // 根据距离设置指令
            if distance > 1000 {
                currentInstruction = "继续前行 \(Int(distance/1000))公里"
            } else {
                currentInstruction = "继续前行 \(Int(distance))米"
            }
            
            print("📍 [简化导航] 真实距离: \(Int(distance))米, 预计时间: \(timeInMinutes)分钟")
        } else {
            currentInstruction = "路线规划成功，开始导航"
            distanceToDestination = 0
            estimatedArrivalTime = "--"
        }
        
        distanceToNext = 200.0 // 200米
        currentSpeed = 5.0 // 5km/h
        currentRoadName = "当前道路"
        
        // 开始导航定时器
        startNavigationTimer()
        
        // 语音播报
        speakInstruction("开始步行导航")
    }
    
    private func startNavigationTimer() {
        navigationTimer?.invalidate()
        navigationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateNavigationInfo()
        }
    }
    
    private func updateNavigationInfo() {
        guard isNavigating else { return }
        
        // 使用真实定位数据，不再模拟
        if let currentLocation = currentLocation, let destination = destination {
            // 计算真实距离
            let distance = currentLocation.distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
            distanceToDestination = distance
            
            // 根据真实位置更新指令（不包含距离信息）
            if distance > 1000 {
                currentInstruction = "继续前行"
            } else if distance > 100 {
                currentInstruction = "即将到达目的地"
            } else {
                currentInstruction = "已到达目的地"
            }
            
            // 更新预计到达时间（基于步行速度5km/h）
            let walkingSpeed = 5.0 // km/h
            let timeInHours = distance / 1000.0 / walkingSpeed
            let timeInMinutes = Int(timeInHours * 60)
            estimatedArrivalTime = "\(timeInMinutes)分钟"
            
            print("📍 [简化导航] 真实位置: \(currentLocation.coordinate), 距离: \(Int(distance))米")
        } else {
            currentInstruction = "正在定位..."
        }
    }
    
    // MARK: - 语音播报
    
    private func speakInstruction(_ instruction: String) {
        guard !instruction.isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: instruction)
        utterance.rate = 0.5
        utterance.volume = 0.8
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        
        speechSynthesizer.speak(utterance)
    }
    
    deinit {
        navigationTimer?.invalidate()
    }
}

// MARK: - CLLocationManagerDelegate
extension SimpleNavigationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        
        if isNavigating {
            // 更新导航状态
            print("📍 [简化导航] 位置更新: \(location.coordinate)")
        }
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
}
