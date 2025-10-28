import SwiftUI
import ARKit
import RealityKit
import CoreLocation
import AMapFoundationKit
import AMapSearchKit
import AMapNaviKit

// 识别的建筑数据结构
struct DetectedBuilding: Identifiable {
    let id = UUID()
    let name: String
    let confidence: Float
    let boundingBox: CGRect
    let description: String?
    let poiId: Int?
    
    init(name: String, confidence: Float, boundingBox: CGRect, description: String? = nil, poiId: Int? = nil) {
        self.name = name
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.description = description
        self.poiId = poiId
    }
}

struct ARNavigationView: View {
    let destination: CLLocationCoordinate2D
    @StateObject private var navigationManager = CampusNavigationManager.shared
    @StateObject private var navManager = CompleteNavigationManager.shared
    @State private var currentInstruction: String = "正在定位..."
    @State private var distanceToNext: Double = 0
    @State private var distanceToDestination: Double = 0
    @State private var currentSpeed: Double = 0
    @State private var currentRoadName: String = ""
    @Environment(\.presentationMode) var presentationMode
    
    // 识别模式相关状态
    @State private var isRecognitionModeEnabled: Bool = false
    @State private var detectedBuildings: [DetectedBuilding] = []
    @State private var currentDetectedBuilding: DetectedBuilding? = nil

    var body: some View {
        ARViewContainer(
            destination: destination, 
            navigationManager: navigationManager,
            isRecognitionModeEnabled: $isRecognitionModeEnabled,
            detectedBuildings: $detectedBuildings,
            currentDetectedBuilding: $currentDetectedBuilding
        )
        .ignoresSafeArea(.all)
        .onAppear {
            // 开始AR导航
            navManager.startNavigation(to: destination)
        }
        .onReceive(navManager.$currentInstruction) { instruction in
            currentInstruction = instruction
        }
        .onReceive(navManager.$distanceToDestination) { distance in
            distanceToDestination = distance
        }
        .onReceive(navManager.$currentSpeed) { speed in
            currentSpeed = speed
        }
        .onReceive(navManager.$currentRoadName) { roadName in
            currentRoadName = roadName
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UpdateNavigationInstruction"))) { notification in
            if let instruction = notification.userInfo?["instruction"] as? String {
                currentInstruction = instruction
            }
            if let distance = notification.userInfo?["distance"] as? Double {
                distanceToNext = distance
            }
            if let destDistance = notification.userInfo?["destinationDistance"] as? Double {
                distanceToDestination = destDistance
            }
        }
        .overlay(
                ZStack {
                    VStack {
                        // 顶部状态栏
                        HStack {
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            Text(isRecognitionModeEnabled ? "AR 识别" : "AR 导航")
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        
                        // 识别模式提示
                        if isRecognitionModeEnabled {
                            HStack {
                                Image(systemName: "eye.fill")
                                    .foregroundColor(.red)
                                Text("识别模式已开启，将自动识别镜头内的校园建筑")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                        
                        Spacer()
                        
                        // 底部信息区域
                        VStack(spacing: 12) {
                            // 识别到的建筑信息卡片
                            if let building = currentDetectedBuilding {
                                BuildingInfoCard(building: building) {
                                    currentDetectedBuilding = nil
                                }
                            }
                            
                            // 导航信息卡片（识别模式下隐藏）
                            if !isRecognitionModeEnabled {
                                VStack(alignment: .leading, spacing: 12) {
                                    // 导航指令
                                    Text(currentInstruction)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    // 当前道路信息
                                    if !currentRoadName.isEmpty {
                                        Text("当前道路: \(currentRoadName)")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    
                                    // 距离和速度信息
                                    HStack(spacing: 20) {
                                        if distanceToNext > 0 {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("下一段")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.white.opacity(0.7))
                                                Text("\(Int(distanceToNext))米")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        
                                        if distanceToDestination > 0 {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("总距离")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.white.opacity(0.7))
                                                Text("\(Int(distanceToDestination))米")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        
                                        if currentSpeed > 0 {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("当前速度")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.white.opacity(0.7))
                                                Text("\(Int(currentSpeed)) km/h")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        
                                        Spacer()
                                    }
                                }
                                .padding(20)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    
                    // 右下角识别模式按钮
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isRecognitionModeEnabled.toggle()
                                    if !isRecognitionModeEnabled {
                                        currentDetectedBuilding = nil
                                        detectedBuildings.removeAll()
                                    }
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: isRecognitionModeEnabled ? "eye.fill" : "eye.slash")
                                        .font(.system(size: 20, weight: .semibold))
                                    Text("识别")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(isRecognitionModeEnabled ? Color.red : Color.blue)
                                .cornerRadius(20)
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, 100)
                        }
                    }
                }
            )
    }
}

// 建筑信息卡片组件
struct BuildingInfoCard: View {
    let building: DetectedBuilding
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(building.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("识别置信度: \(Int(building.confidence * 100))%")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            if let description = building.description {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(3)
            } else {
                Text("暂无详细信息")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .italic()
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.6), lineWidth: 2)
        )
    }
}

fileprivate struct ARViewContainer: UIViewRepresentable {
    let destination: CLLocationCoordinate2D
    let navigationManager: CampusNavigationManager
    // let simpleNavManager: SimpleNavigationManager
    @Binding var isRecognitionModeEnabled: Bool
    @Binding var detectedBuildings: [DetectedBuilding]
    @Binding var currentDetectedBuilding: DetectedBuilding?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            destination: destination, 
            navigationManager: navigationManager,
            isRecognitionModeEnabled: $isRecognitionModeEnabled,
            detectedBuildings: $detectedBuildings,
            currentDetectedBuilding: $currentDetectedBuilding
        )
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Only run on supported devices
        guard ARWorldTrackingConfiguration.isSupported else { return arView }

        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading
        config.environmentTexturing = .automatic
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        // Prepare arrow entity
        context.coordinator.setup(in: arView)

        // Start location updates
        context.coordinator.start()

        arView.session.delegate = context.coordinator
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.destination = destination
    }

    class Coordinator: NSObject, CLLocationManagerDelegate, ARSessionDelegate {
        private let locationManager = CLLocationManager()
        private weak var arView: ARView?
        private var arrowAnchor = AnchorEntity(.camera)
        private var arrowEntity = ModelEntity()
        private let navigationManager: CampusNavigationManager
        // private let simpleNavManager: SimpleNavigationManager

        var destination: CLLocationCoordinate2D
        private var lastHeading: CLHeading?
        private var lastLocation: CLLocation?
        
        // 识别模式相关属性
        @Binding var isRecognitionModeEnabled: Bool
        @Binding var detectedBuildings: [DetectedBuilding]
        @Binding var currentDetectedBuilding: DetectedBuilding?

        init(
            destination: CLLocationCoordinate2D, 
            navigationManager: CampusNavigationManager,
            // simpleNavManager: SimpleNavigationManager,
            isRecognitionModeEnabled: Binding<Bool>,
            detectedBuildings: Binding<[DetectedBuilding]>,
            currentDetectedBuilding: Binding<DetectedBuilding?>
        ) {
            self.destination = destination
            self.navigationManager = navigationManager
            // self.simpleNavManager = simpleNavManager
            self._isRecognitionModeEnabled = isRecognitionModeEnabled
            self._detectedBuildings = detectedBuildings
            self._currentDetectedBuilding = currentDetectedBuilding
            super.init()
            locationManager.delegate = self
        }

        func setup(in arView: ARView) {
            self.arView = arView
            // 简化为单一圆锥体箭头，始终在摄像机前方指向大致方位
            let cone = ModelEntity(
                mesh: .generateCone(height: 0.22, radius: 0.08),
                materials: [SimpleMaterial(color: .systemBlue, isMetallic: false)]
            )
            // 圆锥默认尖头朝上，绕X轴-90°让尖头朝前（-Z轴）
            cone.orientation = simd_quatf(angle: -.pi/2, axis: SIMD3<Float>(1, 0, 0))

            // 父实体用于绕Y轴旋转以指向方位
            let parent = ModelEntity()
            parent.addChild(cone)
            // 放到摄像机前方略低处，避免遮挡视野中心
            parent.position = SIMD3<Float>(0, -0.1, -0.8)
            arrowEntity = parent

            arrowAnchor.addChild(arrowEntity)
            arView.scene.addAnchor(arrowAnchor)
        }

        func start() {
            if CLLocationManager.authorizationStatus() == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
            locationManager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                locationManager.headingFilter = 1
                locationManager.startUpdatingHeading()
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let loc = locations.last else { return }
            lastLocation = loc
            
            // 使用校园路径导航
            updateCampusNavigation()
        }

        func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
            lastHeading = newHeading
            updateCampusNavigation()
        }

        private func updateCampusNavigation() {
            guard let heading = lastHeading, let loc = lastLocation else { return }
            
            // 计算到目的地的总距离
            let destinationDistance = navigationManager.calculateDistance(from: loc.coordinate, to: destination)
            
            // 直接指向目的地
            let bearingDeg = bearing(from: loc.coordinate, to: destination)
            let userHeadingDeg = heading.trueHeading > 0 ? heading.trueHeading : heading.magneticHeading
            let deltaDeg = normalizeDegrees(bearingDeg - userHeadingDeg)
            
            // 旋转箭头指向目的地
            // deltaDeg 是目标方向与用户朝向的差值
            // 正值表示目标在用户右侧，负值表示目标在用户左侧
            // 需要反向旋转，因为圆锥的朝向逻辑
            let deltaRad = Float(-deltaDeg * .pi / 180.0)
            arrowEntity.orientation = simd_quatf(angle: deltaRad, axis: SIMD3<Float>(0, 1, 0))
            
            // 发送通知更新UI
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("UpdateNavigationInstruction"),
                    object: nil,
                    userInfo: [
                        "instruction": "向目的地前进",
                        "distance": 0, // 没有下一段距离
                        "destinationDistance": destinationDistance
                    ]
                )
            }
        }

        private func normalizeDegrees(_ deg: CLLocationDegrees) -> CLLocationDegrees {
            var d = deg
            while d <= -180 { d += 360 }
            while d > 180 { d -= 360 }
            return d
        }

        private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDegrees {
            let lat1 = from.latitude * .pi / 180.0
            let lon1 = from.longitude * .pi / 180.0
            let lat2 = to.latitude * .pi / 180.0
            let lon2 = to.longitude * .pi / 180.0
            let dLon = lon2 - lon1
            let y = sin(dLon) * cos(lat2)
            let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
            let brng = atan2(y, x)
            var deg = brng * 180.0 / .pi
            if deg < 0 { deg += 360 }
            return deg
        }
        
        private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
            let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
            let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
            return fromLocation.distance(from: toLocation)
        }
        
        // MARK: - 识别模式相关方法（框架代码，待后续实现）
        
        /// 模拟建筑识别功能（待后续替换为真实识别）
        private func simulateBuildingRecognition() {
            guard isRecognitionModeEnabled else { return }
            
            // 模拟识别结果
            let mockBuildings = [
                DetectedBuilding(
                    name: "图书馆",
                    confidence: 0.85,
                    boundingBox: CGRect(x: 100, y: 200, width: 200, height: 150),
                    description: "校园主图书馆，建于1995年，藏书丰富",
                    poiId: 1
                ),
                DetectedBuilding(
                    name: "教学楼A",
                    confidence: 0.72,
                    boundingBox: CGRect(x: 150, y: 300, width: 180, height: 120),
                    description: "主要教学楼，包含多个教室和实验室",
                    poiId: 2
                )
            ]
            
            // 随机选择一个建筑进行显示（模拟识别过程）
            if let randomBuilding = mockBuildings.randomElement() {
                DispatchQueue.main.async {
                    self.currentDetectedBuilding = randomBuilding
                }
            }
        }
        
        /// 开始识别模式
        func startRecognitionMode() {
            // TODO: 实现真实的图像识别逻辑
            print("识别模式已开启")
        }
        
        /// 停止识别模式
        func stopRecognitionMode() {
            // TODO: 停止图像识别
            print("识别模式已关闭")
        }
    }
}

#if DEBUG
import SwiftUI
private struct ARNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        ARNavigationView(destination: CLLocationCoordinate2D(latitude: 23.129, longitude: 113.264))
    }
}
#endif
