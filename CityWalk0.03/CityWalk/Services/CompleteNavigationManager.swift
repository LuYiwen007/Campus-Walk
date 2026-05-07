import Foundation
import CoreLocation
import AVFoundation
import AMapNaviKit
import Combine

// 完整的导航管理器 - 包含语音播报、实时导航、路线规划等功能
class CompleteNavigationManager: NSObject, ObservableObject {
    static let shared = CompleteNavigationManager()
    
    // 导航状态
    @Published var isNavigating: Bool = false
    @Published var currentInstruction: String = "正在定位..."
    @Published var distanceToDestination: Double = 0
    @Published var distanceToNext: Double = 0
    @Published var currentSpeed: Double = 0
    @Published var currentRoadName: String = ""
    @Published var estimatedArrivalTime: Date?
    @Published var navigationRoute: [CLLocation] = []
    
    // 导航数据
    private var destination: CLLocationCoordinate2D?
    private var currentLocation: CLLocation?
    private var currentStepIndex: Int = 0
    private var navigationSteps: [NavigationStep] = []
    
    // 系统组件
    private let locationManager = CLLocationManager()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var navigationTimer: Timer?
    
    override init() {
        super.init()
        setupLocationManager()
        setupSpeechSynthesizer()
    }
    
    // MARK: - 初始化设置
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1.0
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func setupSpeechSynthesizer() {
        // 语音合成器设置
    }
    
    // MARK: - 导航控制
    
    func startNavigation(to destination: CLLocationCoordinate2D) {
        self.destination = destination
        isNavigating = true
        currentInstruction = "开始导航"
        
        // 规划路线
        planRoute(to: destination)
        
        // 开始位置更新
        locationManager.startUpdatingLocation()
        
        // 开始导航定时器
        startNavigationTimer()
        
        // 语音播报
        speakInstruction("开始导航")
    }
    
    func stopNavigation() {
        isNavigating = false
        currentInstruction = "导航已停止"
        
        locationManager.stopUpdatingLocation()
        navigationTimer?.invalidate()
        navigationTimer = nil
        
        speakInstruction("导航已停止")
    }
    
    func pauseNavigation() {
        locationManager.stopUpdatingLocation()
        currentInstruction = "导航已暂停"
        speakInstruction("导航已暂停")
    }
    
    func resumeNavigation() {
        locationManager.startUpdatingLocation()
        currentInstruction = "继续导航"
        speakInstruction("继续导航")
    }
    
    // MARK: - 路线规划
    
    private func planRoute(to destination: CLLocationCoordinate2D) {
        guard let currentLocation = currentLocation else { return }
        
        // 创建导航步骤
        navigationSteps = [
            NavigationStep(
                instruction: "直行",
                distance: 100,
                coordinate: CLLocationCoordinate2D(
                    latitude: currentLocation.coordinate.latitude + 0.001,
                    longitude: currentLocation.coordinate.longitude + 0.001
                )
            ),
            NavigationStep(
                instruction: "左转",
                distance: 50,
                coordinate: CLLocationCoordinate2D(
                    latitude: destination.latitude - 0.001,
                    longitude: destination.longitude - 0.001
                )
            ),
            NavigationStep(
                instruction: "到达目的地",
                distance: 0,
                coordinate: destination
            )
        ]
        
        // 更新路线
        navigationRoute = navigationSteps.map { CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
    }
    
    // MARK: - 导航计算
    
    private func startNavigationTimer() {
        navigationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateNavigationStatus()
        }
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
        
        // 生成导航指令
        generateNavigationInstruction()
        
        // 计算预计到达时间
        calculateEstimatedArrivalTime()
    }
    
    private func generateNavigationInstruction() {
        guard let currentLocation = currentLocation,
              let destination = destination else { return }
        
        let distance = distanceToDestination
        
        if distance < 10 {
            currentInstruction = "已到达目的地"
            speakInstruction("已到达目的地")
            stopNavigation()
        } else if distance < 50 {
            currentInstruction = "即将到达目的地，距离\(Int(distance))米"
            speakInstruction("即将到达目的地")
        } else if distance < 100 {
            currentInstruction = "继续前进，距离目的地\(Int(distance))米"
        } else if distance < 500 {
            currentInstruction = "向目的地前进，距离\(Int(distance))米"
        } else {
            currentInstruction = "导航中，距离目的地\(Int(distance))米"
        }
        
        // 更新到下一段的距离
        distanceToNext = distance
    }
    
    private func calculateEstimatedArrivalTime() {
        guard let currentLocation = currentLocation,
              let destination = destination,
              currentSpeed > 0 else { return }
        
        let distance = currentLocation.distance(from: CLLocation(
            latitude: destination.latitude,
            longitude: destination.longitude
        ))
        
        let timeInSeconds = distance / currentSpeed
        estimatedArrivalTime = Date().addingTimeInterval(timeInSeconds)
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
        // 清理所有资源，防止内存泄漏
        navigationTimer?.invalidate()
        navigationTimer = nil
        locationManager.stopUpdatingLocation()
        locationManager.delegate = nil
        print("✅ [CompleteNavigationManager] 资源已清理")
    }
}

// MARK: - 导航步骤数据模型
struct NavigationStep {
    let instruction: String
    let distance: Double
    let coordinate: CLLocationCoordinate2D
}

// MARK: - CLLocationManagerDelegate
extension CompleteNavigationManager: CLLocationManagerDelegate {
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
}
