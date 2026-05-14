import SwiftUI
import AMapNaviKit
import AMapSearchKit
import CoreLocation
import AMapLocationKit
import AMapFoundationKit

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

/// 分段步行路线 overlay，便于按段设置不同描边色
final class LegIndexedPolyline: MAPolyline {
    var legIndex: Int = 0
}

/// POI 检索后可选的步行方案（高德可能返回多条 path）
struct POIRouteOption {
    let distanceM: Int
    let durationSec: Int
    let coordinates: [CLLocationCoordinate2D]
    let steps: [AMapStep]
    let stepCoords: [[CLLocationCoordinate2D]]
}

struct AMapViewRepresentable: UIViewRepresentable {
    // 基本属性
    let startCoordinate: CLLocationCoordinate2D?
    let destination: CLLocationCoordinate2D?
    var centerCoordinate: CLLocationCoordinate2D? = nil
    var showSearchBar: Bool = true
    /// 聊天确认后的地名链（起点、途经点…、终点），将依次 POI 检索并分段请求高德步行路径
    var pendingWalkLegPlaceNames: [String]? = nil
    var onConsumePendingWalkLeg: (() -> Void)? = nil
    /// 后端导航会话（方案 2 分段 + 进度落库）
    var pendingNavigationSession: NavigationSessionDTO? = nil
    var onConsumePendingNavigationSession: (() -> Void)? = nil

    var onNavigationStart: (() -> Void)? = nil
    var onNavigationStop: (() -> Void)? = nil
    /// 地图全屏时右下角「返回聊天」，与 AR、定位同一套贴底/贴选路面板自适应
    var onBackToChat: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIView {
        print("[AMapViewRepresentable] 创建地图视图")
        let container = UIView(frame: .zero)
        let mapView = MAMapView(frame: .zero)
        
        // 基本地图设置
        mapView.showsUserLocation = true
        mapView.showsCompass = false // 不显示右上角「北」指南针
        mapView.showsScale = false // 不显示左下角半透明比例尺
        mapView.userTrackingMode = .follow // 仅跟随位置，不跟朝向（避免出现半透明朝向扇形）
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
        context.coordinator.applyUserLocationHeadingIndicator(mapView, navigating: false)

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
            context.coordinator.searchBarView = searchView
            NSLayoutConstraint.activate([
                searchView.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 12),
                searchView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
                searchView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
                searchView.heightAnchor.constraint(equalToConstant: 52)
            ])
        }

        let mapFloatingBtnSize: CGFloat = 50
        let mapFloatingCorner: CGFloat = 14

        // 右侧三键：上 AR — 中 返回聊天 — 下 定位；位置由 updateFloatingStackLayout 统一约束
        let arBtn = UIButton(type: .custom)
        arBtn.setTitle("AR", for: .normal)
        arBtn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        arBtn.setTitleColor(.white, for: .normal)
        arBtn.setTitleColor(.white.withAlphaComponent(0.6), for: .disabled)
        arBtn.backgroundColor = .systemGray
        arBtn.layer.cornerRadius = mapFloatingCorner
        arBtn.layer.masksToBounds = true
        arBtn.layer.shadowOpacity = 0.12
        arBtn.layer.shadowRadius = 4
        arBtn.translatesAutoresizingMaskIntoConstraints = false
        arBtn.isEnabled = false
        arBtn.addTarget(context.coordinator, action: #selector(Coordinator.openARDirect), for: .touchUpInside)
        container.addSubview(arBtn)
        context.coordinator.arButton = arBtn

        let chatBtn = UIButton(type: .custom)
        chatBtn.setImage(UIImage(systemName: "bubble.left.and.bubble.right.fill"), for: .normal)
        chatBtn.tintColor = .white
        chatBtn.backgroundColor = .systemBlue
        chatBtn.layer.cornerRadius = mapFloatingCorner
        chatBtn.layer.masksToBounds = true
        chatBtn.translatesAutoresizingMaskIntoConstraints = false
        chatBtn.addTarget(context.coordinator, action: #selector(Coordinator.backToChatTapped), for: .touchUpInside)
        container.addSubview(chatBtn)
        context.coordinator.chatBackButton = chatBtn

        let locateBtn = UIButton(type: .custom)
        locateBtn.setImage(UIImage(systemName: "location.fill"), for: .normal)
        locateBtn.tintColor = .systemBlue
        locateBtn.backgroundColor = .white
        locateBtn.layer.cornerRadius = mapFloatingCorner
        locateBtn.layer.masksToBounds = true
        locateBtn.layer.shadowColor = UIColor.black.cgColor
        locateBtn.layer.shadowOpacity = 0.12
        locateBtn.layer.shadowOffset = CGSize(width: 0, height: 2)
        locateBtn.layer.shadowRadius = 4
        locateBtn.translatesAutoresizingMaskIntoConstraints = false
        locateBtn.addTarget(context.coordinator, action: #selector(Coordinator.locateUser), for: .touchUpInside)
        container.addSubview(locateBtn)
        context.coordinator.locateButton = locateBtn

        NSLayoutConstraint.activate([
            arBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -17),
            arBtn.widthAnchor.constraint(equalToConstant: mapFloatingBtnSize),
            arBtn.heightAnchor.constraint(equalToConstant: mapFloatingBtnSize),
            chatBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -17),
            chatBtn.widthAnchor.constraint(equalToConstant: mapFloatingBtnSize),
            chatBtn.heightAnchor.constraint(equalToConstant: mapFloatingBtnSize),
            locateBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -17),
            locateBtn.widthAnchor.constraint(equalToConstant: mapFloatingBtnSize),
            locateBtn.heightAnchor.constraint(equalToConstant: mapFloatingBtnSize)
        ])

        context.coordinator.mapContainerView = container

        // 导航 UI（顶栏信息 + 底栏仅退出/语音）
        addNavigationUI(to: container, coordinator: context.coordinator)

        context.coordinator.updateFloatingStackLayout()
        context.coordinator.bringFloatingButtonsToFront()

        return container
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let mapView = context.coordinator.mapView else { return }

        mapView.showsCompass = false
        mapView.showsScale = false
        // 导航中保持跟朝向，避免 SwiftUI 刷新把模式打回 .follow
        if !context.coordinator.isNavigating {
            if mapView.userTrackingMode != .follow {
                mapView.userTrackingMode = .follow
            }
        } else if mapView.userTrackingMode != .followWithHeading {
            mapView.userTrackingMode = .followWithHeading
            context.coordinator.applyUserLocationHeadingIndicator(mapView, navigating: true)
        }

        // 如果正在导航或多段路线规划中，不要清除覆盖层
        if !context.coordinator.isNavigating && !context.coordinator.isMultiLegRouting {
            mapView.removeOverlays(mapView.overlays)
        }
        
        // 仅在非导航下根据绑定调整中心；导航中若仍 setCenter(start)，会与 followWithHeading 抢中心，朝向扇区/箭头不显示或异常
        if !context.coordinator.isNavigating, let start = startCoordinate {
            mapView.setCenter(start, animated: false)
            mapView.userTrackingMode = .follow
        }

        if !context.coordinator.isNavigating, let center = centerCoordinate {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard !context.coordinator.isNavigating else { return }
                mapView.setCenter(center, animated: true)
                mapView.userTrackingMode = .follow
            }
        }
        
        // 自动规划路线（仅在非导航、非多段规划状态下，且起终点改变时）
        if !context.coordinator.isNavigating,
           !context.coordinator.isMultiLegRouting,
           let start = startCoordinate,
           let dest = destination {
            if context.coordinator.lastRouteStart != start || context.coordinator.lastRouteDest != dest {
                context.coordinator.lastRouteStart = start
                context.coordinator.lastRouteDest = dest
                context.coordinator.searchWalkingRoute(from: start, to: dest, on: mapView)
            }
        }

        if let session = pendingNavigationSession,
           !context.coordinator.isNavigating,
           session.id != context.coordinator.lastIngestedNavigationSessionId {
            context.coordinator.ingestPendingNavigationSession(session, mapView: mapView)
            onConsumePendingNavigationSession?()
        }

        if let names = pendingWalkLegPlaceNames, names.count >= 2, !context.coordinator.isMultiLegRouting {
            context.coordinator.beginMultiLegWalking(names: names, mapView: mapView)
        }
    }

    // MARK: - 导航 UI：顶栏（转向/朝向/剩余）贴搜索栏位置；底栏仅退出/语音贴容器底（与 Tab 上沿对齐）
    private func addNavigationUI(to container: UIView, coordinator: Coordinator) {
        let topCard = UIView()
        topCard.backgroundColor = UIColor.black.withAlphaComponent(0.92)
        topCard.layer.cornerRadius = 16
        topCard.layer.masksToBounds = true
        topCard.translatesAutoresizingMaskIntoConstraints = false
        topCard.isHidden = true

        let bottomBar = UIView()
        bottomBar.backgroundColor = UIColor.black.withAlphaComponent(0.92)
        bottomBar.layer.cornerRadius = 16
        bottomBar.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        bottomBar.layer.masksToBounds = true
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.isHidden = true

        let exitButton = UIButton(type: .system)
        exitButton.setTitle("退出", for: .normal)
        exitButton.setTitleColor(.white, for: .normal)
        exitButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
        exitButton.layer.cornerRadius = 10
        exitButton.layer.masksToBounds = true
        exitButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        exitButton.translatesAutoresizingMaskIntoConstraints = false
        exitButton.addTarget(coordinator, action: #selector(Coordinator.exitNavigation), for: .touchUpInside)

        let voiceButton = UIButton(type: .system)
        voiceButton.setImage(UIImage(systemName: "speaker.wave.2.fill"), for: .normal)
        voiceButton.tintColor = .white
        voiceButton.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        voiceButton.layer.cornerRadius = 10
        voiceButton.layer.masksToBounds = true
        voiceButton.translatesAutoresizingMaskIntoConstraints = false
        voiceButton.addTarget(coordinator, action: #selector(Coordinator.voiceReplayTapped), for: .touchUpInside)

        let bottomInner = UIStackView(arrangedSubviews: [exitButton, UIView(), voiceButton])
        bottomInner.axis = .horizontal
        bottomInner.alignment = .center
        bottomInner.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(bottomInner)

        let turnIcon = UIImageView(image: UIImage(systemName: "arrow.up"))
        turnIcon.tintColor = .white
        turnIcon.contentMode = .scaleAspectFit
        turnIcon.translatesAutoresizingMaskIntoConstraints = false
        turnIcon.widthAnchor.constraint(equalToConstant: 36).isActive = true
        turnIcon.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let instructionLabel = UILabel()
        instructionLabel.textColor = .white
        instructionLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        instructionLabel.numberOfLines = 2
        instructionLabel.adjustsFontSizeToFitWidth = true
        instructionLabel.minimumScaleFactor = 0.78

        let headingLabel = UILabel()
        headingLabel.textColor = UIColor.white.withAlphaComponent(0.78)
        headingLabel.font = UIFont.systemFont(ofSize: 13)
        headingLabel.text = "朝向 —"

        let remainLabel = UILabel()
        remainLabel.textColor = UIColor.white.withAlphaComponent(0.92)
        remainLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        remainLabel.textAlignment = .natural
        remainLabel.numberOfLines = 2

        let turnRow = UIStackView(arrangedSubviews: [turnIcon, instructionLabel])
        turnRow.axis = .horizontal
        turnRow.spacing = 10
        turnRow.alignment = .top

        let topInner = UIStackView(arrangedSubviews: [turnRow, headingLabel, remainLabel])
        topInner.axis = .vertical
        topInner.spacing = 8
        topInner.translatesAutoresizingMaskIntoConstraints = false
        topCard.addSubview(topInner)

        container.addSubview(topCard)
        container.addSubview(bottomBar)

        NSLayoutConstraint.activate([
            topInner.topAnchor.constraint(equalTo: topCard.topAnchor, constant: 12),
            topInner.leadingAnchor.constraint(equalTo: topCard.leadingAnchor, constant: 14),
            topInner.trailingAnchor.constraint(equalTo: topCard.trailingAnchor, constant: -14),
            topInner.bottomAnchor.constraint(equalTo: topCard.bottomAnchor, constant: -12),

            topCard.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 12),
            topCard.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            topCard.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),

            bottomInner.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 8),
            bottomInner.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 12),
            bottomInner.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -12),
            bottomInner.bottomAnchor.constraint(equalTo: bottomBar.bottomAnchor, constant: -8),
            exitButton.widthAnchor.constraint(equalToConstant: 72),
            exitButton.heightAnchor.constraint(equalToConstant: 40),
            voiceButton.widthAnchor.constraint(equalToConstant: 48),
            voiceButton.heightAnchor.constraint(equalToConstant: 40),

            bottomBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        coordinator.navTopInfoView = topCard
        coordinator.navBottomBarView = bottomBar
        coordinator.exitButton = exitButton
        coordinator.remainLabel = remainLabel
        coordinator.instructionLabel = instructionLabel
        coordinator.headingLabel = headingLabel
        coordinator.voiceButton = voiceButton
        coordinator.turnIconImageView = turnIcon
    }

    class Coordinator: NSObject, MAMapViewDelegate, AMapSearchDelegate, CustomSearchBarViewDelegate, AMapLocationManagerDelegate {
        var parent: AMapViewRepresentable
        var search: AMapSearchAPI?
        var mapView: MAMapView?
        var currentPOI: AMapPOI?
        var currentDest: CLLocationCoordinate2D? = nil
        var latestUserLocation: CLLocationCoordinate2D?
        var lastRouteStart: CLLocationCoordinate2D? = nil
        var lastRouteDest: CLLocationCoordinate2D? = nil
        var startAnnotation: MAPointAnnotation?
        var endAnnotation: MAPointAnnotation?
        var arButton: UIButton?
        var chatBackButton: UIButton?
        weak var locateButton: UIButton?
        weak var mapContainerView: UIView?
        weak var searchBarView: CustomSearchBarView?
        var floatingButtonConstraints: [NSLayoutConstraint] = []

        // 导航 UI：顶栏信息 + 底栏控制
        var navTopInfoView: UIView?
        var navBottomBarView: UIView?
        var instructionLabel: UILabel?
        var headingLabel: UILabel?
        var voiceButton: UIButton?
        var turnIconImageView: UIImageView?
        var exitButton: UIButton?
        var remainLabel: UILabel?
        var isNavigating: Bool = false
        var navigationTimer: Timer? // 保存 Timer 引用，防止内存泄漏

        // POI 检索后多路线选择（大模型路线不经此流程）
        var isAwaitingPOIRouteChoice: Bool = false
        var poiRouteChoiceDestination: CLLocationCoordinate2D?
        var poiRouteOptions: [POIRouteOption] = []
        var selectedPOIRouteIndex: Int = 0
        var routeChoicePanel: UIView?
        var routeChoiceCardButtons: [UIButton] = []

        // 路线指引相关
        var routeSteps: [AMapStep] = [] // 保存路线步骤
        var currentStepIndex: Int = 0 // 当前路段索引
        /// 当前整条高德步行方案总距离(米)、总时间(秒)，与 `routeSteps` 同步更新
        var routeTotalDistanceM: Int = 0
        var routeTotalDurationSec: Int = 0
        var routeGuidanceView: UIView? // 已弃用浮层，保留字段避免大范围改动
        var routeGuidanceScrollView: UIScrollView?
        var routeStepCoordinates: [[CLLocationCoordinate2D]] = [] // 每个路段的坐标点数组
        var navigationDestination: CLLocationCoordinate2D? // 保存导航目的地，用于重新规划
        var lastReplanTime: Date? // 上次重新规划的时间，用于防止频繁重新规划
        var isOffRoute: Bool = false // 是否偏离路线

        // 后端分段导航（方案 2）
        var lastIngestedNavigationSessionId: Int?
        var navigationSessionId: Int?
        var serverSegmentedMode: Bool = false
        var serverApproachStart: Bool = false
        var serverActiveLegIndex: Int = 0
        var serverSegmentWaypoints: [(label: String, coordinate: CLLocationCoordinate2D)] = []

        // MARK: - 聊天确认后的多段步行（POI 检索 + 分段高德步行路径）
        var isMultiLegRouting: Bool = false
        private var multiLegGeocodeNames: [String]?
        private var multiLegGeocodeCoords: [CLLocationCoordinate2D] = []
        private var multiLegResolvedCoords: [CLLocationCoordinate2D]?
        private var multiLegWalkingSegmentIndex: Int = 0

        init(_ parent: AMapViewRepresentable) {
            self.parent = parent
            super.init()
            self.search = AMapSearchAPI()
            self.search?.delegate = self
        }

        /// 搜索栏显隐（选路 / 导航时隐藏）
        func setSearchBarHidden(_ hidden: Bool) {
            searchBarView?.isHidden = hidden
        }

        /// 控制定位点方向指示（扇区/箭头）。`followWithHeading` 下需为 true 才稳定显示；浏览地图时关闭以免半透明扇形干扰
        func applyUserLocationHeadingIndicator(_ mapView: MAMapView, navigating: Bool) {
            let rep = MAUserLocationRepresentation()
            rep.showsHeadingIndicator = navigating
            mapView.update(rep)
        }

        /// AR、返回聊天、定位：自下而上排列；默认贴容器底，有选路面板/导航底栏时贴其上方
        func updateFloatingStackLayout() {
            guard let locate = locateButton, let ar = arButton, let chat = chatBackButton, let box = mapContainerView else { return }
            NSLayoutConstraint.deactivate(floatingButtonConstraints)
            floatingButtonConstraints.removeAll()
            let gap: CGFloat = 12
            let btnH: CGFloat = 50
            let defaultBottomPad: CGFloat = 16 + btnH * 3 + gap * 2

            let dockTop: UIView? = {
                if let p = routeChoicePanel, p.superview != nil { return p }
                if isNavigating, let b = navBottomBarView, !b.isHidden { return b }
                return nil
            }()

            let locateBottom: NSLayoutConstraint
            if let dock = dockTop {
                locateBottom = locate.bottomAnchor.constraint(equalTo: dock.topAnchor, constant: -gap)
            } else {
                locateBottom = locate.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -defaultBottomPad)
            }
            let chatBottom = chat.bottomAnchor.constraint(equalTo: locate.topAnchor, constant: -gap)
            let arBottom = ar.bottomAnchor.constraint(equalTo: chat.topAnchor, constant: -gap)
            NSLayoutConstraint.activate([locateBottom, chatBottom, arBottom])
            floatingButtonConstraints = [locateBottom, chatBottom, arBottom]
        }

        func bringFloatingButtonsToFront() {
            guard let box = mapContainerView else { return }
            if let c = chatBackButton { box.bringSubviewToFront(c) }
            if let l = locateButton { box.bringSubviewToFront(l) }
            if let a = arButton { box.bringSubviewToFront(a) }
        }

        @objc func backToChatTapped() {
            parent.onBackToChat?()
        }

        /// 将地图中心移到当前位置（与聊天页右下角布局配套的定位按钮）
        @objc func locateUser() {
            guard let mapView = mapView else { return }
            mapView.showsCompass = false
            mapView.showsScale = false
            if let userLoc = mapView.userLocation.location?.coordinate {
                mapView.setCenter(userLoc, animated: true)
                mapView.userTrackingMode = isNavigating ? .followWithHeading : .follow
                if isNavigating {
                    applyUserLocationHeadingIndicator(mapView, navigating: true)
                }
                return
            }
            let locationManager = AMapLocationManager()
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.locationTimeout = 10
            locationManager.requestLocation(withReGeocode: false) { location, _, error in
                if let error = error {
                    print("❌ [定位] 定位失败: \(error.localizedDescription)")
                    return
                }
                guard let loc = location else { return }
                DispatchQueue.main.async {
                    mapView.setCenter(loc.coordinate, animated: true)
                    mapView.userTrackingMode = self.isNavigating ? .followWithHeading : .follow
                    if self.isNavigating {
                        self.applyUserLocationHeadingIndicator(mapView, navigating: true)
                    }
                }
            }
        }

        // MARK: - POI 多路线选择

        private func extractAMapPaths(from raw: Any?) -> [AMapPath] {
            if let arr = raw as? [AMapPath] { return arr }
            var out: [AMapPath] = []
            if let ns = raw as? NSArray {
                for i in 0 ..< ns.count {
                    if let p = ns[i] as? AMapPath { out.append(p) }
                }
            }
            return out
        }

        private func parsePOIRouteOption(from path: AMapPath) -> POIRouteOption? {
            guard let steps = path.steps, !steps.isEmpty else { return nil }
            var coordinates: [CLLocationCoordinate2D] = []
            var stepCoords: [[CLLocationCoordinate2D]] = []
            for step in steps {
                var sc: [CLLocationCoordinate2D] = []
                if let polylineStr = step.polyline {
                    let points = polylineStr.split(separator: ";").compactMap { pair -> CLLocationCoordinate2D? in
                        let comps = pair.split(separator: ",")
                        if comps.count == 2, let lon = Double(comps[0]), let lat = Double(comps[1]) {
                            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        }
                        return nil
                    }
                    sc = points
                    coordinates.append(contentsOf: points)
                }
                stepCoords.append(sc)
            }
            guard coordinates.count > 1 else { return nil }
            return POIRouteOption(
                distanceM: path.distance,
                durationSec: path.duration,
                coordinates: coordinates,
                steps: steps,
                stepCoords: stepCoords
            )
        }

        func beginPOIRouteSelection(to dest: CLLocationCoordinate2D) {
            guard let mapView = mapView, let u = mapView.userLocation?.coordinate else {
                print("❌ [POI路线] 无起点坐标")
                setSearchBarHidden(false)
                return
            }
            cancelMultiLegRouting(reason: "POI 查看路线")
            dismissRouteChoicePanel(restoreSearch: false)
            setSearchBarHidden(true)
            updateFloatingStackLayout()
            poiRouteChoiceDestination = dest
            isAwaitingPOIRouteChoice = true
            selectedPOIRouteIndex = 0
            routeChoiceCardButtons = []
            poiRouteOptions = []
            searchWalkingRoute(from: u, to: dest, on: mapView)
        }

        func dismissRouteChoicePanel(restoreSearch: Bool = true) {
            routeChoicePanel?.removeFromSuperview()
            routeChoicePanel = nil
            routeChoiceCardButtons = []
            if restoreSearch && !isNavigating {
                setSearchBarHidden(false)
            }
            updateFloatingStackLayout()
        }

        private func presentRouteChoicePanel() {
            dismissRouteChoicePanel(restoreSearch: false)
            guard let mapView = mapView, let box = mapView.superview else { return }

            let panel = UIView()
            panel.backgroundColor = UIColor.systemBackground
            panel.layer.cornerRadius = 16
            panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            panel.layer.masksToBounds = true
            panel.translatesAutoresizingMaskIntoConstraints = false

            let title = UILabel()
            title.text = "选择步行方案"
            title.font = UIFont.boldSystemFont(ofSize: 16)
            title.textColor = .label
            title.translatesAutoresizingMaskIntoConstraints = false

            let scroll = UIScrollView()
            scroll.showsHorizontalScrollIndicator = false
            scroll.translatesAutoresizingMaskIntoConstraints = false

            let stack = UIStackView()
            stack.axis = .horizontal
            stack.spacing = 10
            stack.alignment = .fill
            stack.translatesAutoresizingMaskIntoConstraints = false

            routeChoiceCardButtons = []
            for (i, opt) in poiRouteOptions.enumerated() {
                let b = UIButton(type: .system)
                b.tag = i
                let dm = opt.distanceM
                let dur = opt.durationSec
                let distStr = dm >= 1000 ? String(format: "%.1f公里", Double(dm) / 1000.0) : "\(dm)米"
                let mins = max(1, dur / 60)
                let hrs = mins / 60
                let m = mins % 60
                let timeStr = hrs > 0 ? "\(hrs)小时\(m)分" : "\(m)分钟"
                b.setTitle("\(timeStr)\n\(distStr)\n方案 \(i + 1)", for: .normal)
                b.titleLabel?.numberOfLines = 3
                b.titleLabel?.textAlignment = .center
                b.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
                b.layer.cornerRadius = 12
                b.layer.masksToBounds = true
                b.layer.borderWidth = 2
                b.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
                b.addTarget(self, action: #selector(poiRouteCardTapped(_:)), for: .touchUpInside)
                b.widthAnchor.constraint(equalToConstant: 132).isActive = true
                stack.addArrangedSubview(b)
                routeChoiceCardButtons.append(b)
            }

            scroll.addSubview(stack)
            let startBtn = UIButton(type: .system)
            startBtn.setTitle("开始步行导航", for: .normal)
            startBtn.setTitleColor(.white, for: .normal)
            startBtn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
            startBtn.backgroundColor = .systemBlue
            startBtn.layer.cornerRadius = 12
            startBtn.layer.masksToBounds = true
            startBtn.translatesAutoresizingMaskIntoConstraints = false
            startBtn.addTarget(self, action: #selector(confirmPOIStartWalkingNavigation), for: .touchUpInside)

            panel.addSubview(title)
            panel.addSubview(scroll)
            panel.addSubview(startBtn)
            box.addSubview(panel)
            routeChoicePanel = panel

            NSLayoutConstraint.activate([
                panel.leadingAnchor.constraint(equalTo: box.leadingAnchor),
                panel.trailingAnchor.constraint(equalTo: box.trailingAnchor),
                panel.bottomAnchor.constraint(equalTo: box.bottomAnchor),

                title.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14),
                title.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),

                scroll.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 10),
                scroll.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
                scroll.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
                scroll.heightAnchor.constraint(equalToConstant: 100),

                stack.topAnchor.constraint(equalTo: scroll.topAnchor),
                stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
                stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
                stack.heightAnchor.constraint(equalTo: scroll.heightAnchor),

                startBtn.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 12),
                startBtn.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
                startBtn.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
                startBtn.heightAnchor.constraint(equalToConstant: 50),
                startBtn.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14)
            ])
            refreshRouteChoiceSelection()
            box.layoutIfNeeded()
            updateFloatingStackLayout()
            bringFloatingButtonsToFront()
        }

        private func refreshRouteChoiceSelection() {
            for (i, b) in routeChoiceCardButtons.enumerated() {
                let on = i == selectedPOIRouteIndex
                b.layer.borderColor = (on ? UIColor.systemBlue : UIColor.separator).cgColor
                b.backgroundColor = on ? UIColor.systemBlue.withAlphaComponent(0.12) : UIColor.secondarySystemBackground
                b.setTitleColor(on ? .systemBlue : .label, for: .normal)
            }
        }

        @objc private func poiRouteCardTapped(_ sender: UIButton) {
            selectedPOIRouteIndex = sender.tag
            refreshRouteChoiceSelection()
        }

        @objc private func confirmPOIStartWalkingNavigation() {
            guard let dest = poiRouteChoiceDestination, let mv = mapView else { return }
            guard selectedPOIRouteIndex < poiRouteOptions.count else { return }
            let opt = poiRouteOptions[selectedPOIRouteIndex]
            ingestPOIRouteOption(opt, mapView: mv)
            dismissRouteChoicePanel(restoreSearch: false)
            poiRouteOptions = []
            poiRouteChoiceDestination = nil
            beginNavigationWithoutRouteSearch(to: dest)
        }

        private func ingestPOIRouteOption(_ opt: POIRouteOption, mapView: MAMapView) {
            routeSteps = opt.steps
            routeStepCoordinates = opt.stepCoords
            routeTotalDistanceM = opt.distanceM
            routeTotalDurationSec = opt.durationSec
            currentStepIndex = 0
            isOffRoute = false
            var coords = opt.coordinates
            mapView.removeOverlays(mapView.overlays)
            let polyline = MAPolyline(coordinates: &coords, count: UInt(coords.count))
            mapView.add(polyline)
        }

        /// 已规划好折线后进入导航（不再请求步行规划）
        private func beginNavigationWithoutRouteSearch(to destination: CLLocationCoordinate2D) {
            guard !isNavigating else { return }
            DispatchQueue.main.async {
                self.clearServerSegmentedNavigationState()
                self.isNavigating = true
                self.hideNonNavigationUI()
                self.showNavigationUI()
                self.navigationDestination = destination
                self.isOffRoute = false
                self.lastReplanTime = nil
                guard let mapView = self.mapView else {
                    self.isNavigating = false
                    return
                }
                mapView.isRotateEnabled = true
                mapView.userTrackingMode = .followWithHeading
                self.applyUserLocationHeadingIndicator(mapView, navigating: true)
                self.jumpToStartLocation()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.startNavigationTimer()
                    self.updateARButtonState()
                    self.parent.onNavigationStart?()
                }
            }
        }

        @objc func voiceReplayTapped() {
            let t = instructionLabel?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !t.isEmpty else { return }
            NavigationSpeechController.shared.speakImmediate(t)
        }

        private func updateTurnIconForGuidance(_ text: String) {
            let t = text.lowercased()
            let name: String
            if t.contains("左") { name = "arrow.turn.up.left" }
            else if t.contains("右") { name = "arrow.turn.up.right" }
            else if t.contains("调头") || t.contains("掉头") { name = "uturn.up" }
            else { name = "arrow.up" }
            turnIconImageView?.image = UIImage(systemName: name)
        }
        
        // 搜索功能
        func didTapSearch(with keyword: String) {
            guard !keyword.isEmpty else { return }
            cancelMultiLegRouting(reason: "用户发起关键词搜索")
            let request = AMapPOIKeywordsSearchRequest()
            request.keywords = keyword
            request.city = nil
            search?.aMapPOIKeywordsSearch(request)
        }

        private func cancelMultiLegRouting(reason: String) {
            if isMultiLegRouting || multiLegGeocodeNames != nil {
                print("ℹ️ [多段路线] 取消：\(reason)")
            }
            multiLegGeocodeNames = nil
            multiLegGeocodeCoords = []
            multiLegResolvedCoords = nil
            isMultiLegRouting = false
        }

        // MARK: - 后端分段导航（方案 2）

        func ingestPendingNavigationSession(_ session: NavigationSessionDTO, mapView: MAMapView) {
            guard !isNavigating else { return }
            if session.id == lastIngestedNavigationSessionId { return }
            lastIngestedNavigationSessionId = session.id
            cancelMultiLegRouting(reason: "后端导航会话")
            let sorted = session.waypoints.sorted { $0.order < $1.order }
            let resolved: [(label: String, coordinate: CLLocationCoordinate2D)] = sorted.compactMap { w in
                guard let la = w.latitude, let lo = w.longitude else { return nil }
                return (w.label, CLLocationCoordinate2D(latitude: la, longitude: lo))
            }
            navigationSessionId = session.id
            let maxLegStart = max(0, resolved.count - 2)
            serverActiveLegIndex = min(max(0, session.activeLegIndex), maxLegStart)

            if resolved.count >= 2 {
                serverSegmentWaypoints = resolved
                serverSegmentedMode = true
                startActiveServerSegmentNavigation(on: mapView)
                return
            }
            let names = sorted.map(\.label).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let deduped = names.reduce(into: [String]()) { acc, s in
                if acc.last != s { acc.append(s) }
            }
            serverSegmentedMode = false
            serverSegmentWaypoints = []
            if deduped.count >= 2 {
                beginMultiLegWalking(names: deduped, mapView: mapView)
            } else {
                print("⚠️ [后端导航] 途经点不足且无法地理编码，请配置 AMAP_REST_KEY")
            }
        }

        private func startActiveServerSegmentNavigation(on mapView: MAMapView) {
            guard serverSegmentWaypoints.count >= 2 else { return }
            guard let finalCoord = serverSegmentWaypoints.last?.coordinate else { return }

            isNavigating = true
            hideNonNavigationUI()
            showNavigationUI()
            navigationDestination = finalCoord
            isOffRoute = false
            lastReplanTime = nil

            guard let userCoord = mapView.userLocation?.coordinate else {
                instructionLabel?.text = "无法获取当前位置，请检查定位权限"
                isNavigating = false
                return
            }

            let w0 = serverSegmentWaypoints[0].coordinate
            let distToStart = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
                .distance(from: CLLocation(latitude: w0.latitude, longitude: w0.longitude))
            let approachThreshold: CLLocationDistance = 100

            if serverActiveLegIndex == 0 && distToStart > approachThreshold {
                serverApproachStart = true
                instructionLabel?.text = "正在规划前往起点…"
                searchWalkingRoute(from: userCoord, to: w0, on: mapView)
            } else {
                serverApproachStart = false
                let from = serverSegmentWaypoints[serverActiveLegIndex].coordinate
                let to = serverSegmentWaypoints[serverActiveLegIndex + 1].coordinate
                instructionLabel?.text = "正在规划第 \(serverActiveLegIndex + 1) 段路线…"
                searchWalkingRoute(from: from, to: to, on: mapView)
            }

            mapView.isRotateEnabled = true
            mapView.userTrackingMode = .followWithHeading
            applyUserLocationHeadingIndicator(mapView, navigating: true)
            jumpToStartLocation()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                self.startNavigationTimer()
                self.updateARButtonState()
                self.parent.onNavigationStart?()
                NavigationSpeechController.shared.speakImmediate("开始分段导航")
                if let sid = self.navigationSessionId {
                    Task {
                        try? await APIClient.shared.patchNavigationSession(sessionId: sid, activeLegIndex: self.serverActiveLegIndex, status: nil)
                    }
                }
            }
        }

        private func evaluateServerSegmentAdvance() {
            guard serverSegmentedMode, isNavigating, let mapView = mapView,
                  let uid = mapView.userLocation?.coordinate else { return }
            let n = serverSegmentWaypoints.count
            guard n >= 2 else { return }
            let userLoc = CLLocation(latitude: uid.latitude, longitude: uid.longitude)

            if serverApproachStart {
                let w0 = serverSegmentWaypoints[0].coordinate
                let d = userLoc.distance(from: CLLocation(latitude: w0.latitude, longitude: w0.longitude))
                if d > 65 { return }
                serverApproachStart = false
                serverActiveLegIndex = 0
                instructionLabel?.text = "开始第 1 段路线"
                NavigationSpeechController.shared.speakImmediate("已接近起点，开始途经点导航")
                let to = serverSegmentWaypoints[1].coordinate
                searchWalkingRoute(from: w0, to: to, on: mapView)
                if let sid = navigationSessionId {
                    Task {
                        try? await APIClient.shared.patchNavigationSession(sessionId: sid, activeLegIndex: 0, status: nil)
                    }
                }
                return
            }

            let segmentEndIdx = serverActiveLegIndex + 1
            if segmentEndIdx >= n { return }
            let endCoord = serverSegmentWaypoints[segmentEndIdx].coordinate
            let dEnd = userLoc.distance(from: CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude))
            if dEnd > 45 { return }

            if serverActiveLegIndex >= n - 2 {
                let endName = serverSegmentWaypoints[n - 1].label
                NavigationSpeechController.shared.speakImmediate("已到达目的地：\(endName)")
                instructionLabel?.text = "导航结束"
                if let sid = navigationSessionId {
                    Task {
                        try? await APIClient.shared.patchNavigationSession(sessionId: sid, activeLegIndex: n - 2, status: "COMPLETED")
                    }
                }
                exitNavigation()
                return
            }

            serverActiveLegIndex += 1
            let patchedLeg = serverActiveLegIndex
            let from = serverSegmentWaypoints[serverActiveLegIndex].coordinate
            let to = serverSegmentWaypoints[serverActiveLegIndex + 1].coordinate
            let nextName = serverSegmentWaypoints[serverActiveLegIndex + 1].label
            instructionLabel?.text = "前往：\(nextName)"
            NavigationSpeechController.shared.speakImmediate("即将前往\(nextName)")
            searchWalkingRoute(from: from, to: to, on: mapView)
            if let sid = navigationSessionId {
                Task {
                    try? await APIClient.shared.patchNavigationSession(sessionId: sid, activeLegIndex: patchedLeg, status: nil)
                }
            }
        }

        private func clearServerSegmentedNavigationState() {
            serverSegmentedMode = false
            serverApproachStart = false
            serverSegmentWaypoints = []
            navigationSessionId = nil
        }

        func beginMultiLegWalking(names: [String], mapView: MAMapView) {
            print("[多段路线] 开始解析地名链：\(names.joined(separator: " → "))")
            lastRouteStart = nil
            lastRouteDest = nil
            isMultiLegRouting = true
            multiLegResolvedCoords = nil
            multiLegWalkingSegmentIndex = 0
            multiLegGeocodeNames = names
            multiLegGeocodeCoords = []
            mapView.removeOverlays(mapView.overlays)
            requestMultiLegPoi(keyword: names[0])
        }

        private func requestMultiLegPoi(keyword: String) {
            let request = AMapPOIKeywordsSearchRequest()
            request.keywords = keyword
            request.city = nil
            search?.aMapPOIKeywordsSearch(request)
        }

        private func failMultiLeg(_ reason: String) {
            print("❌ [多段路线] \(reason)")
            endMultiLegAndNotifyParent()
        }

        private func endMultiLegAndNotifyParent() {
            multiLegGeocodeNames = nil
            multiLegGeocodeCoords = []
            multiLegResolvedCoords = nil
            isMultiLegRouting = false
            DispatchQueue.main.async {
                self.parent.onConsumePendingWalkLeg?()
            }
        }

        private func finishMultiLegSuccess(mapView: MAMapView) {
            let coords = multiLegResolvedCoords ?? []
            guard coords.count >= 2 else {
                failMultiLeg("坐标链无效")
                return
            }
            let minLat = coords.map(\.latitude).min() ?? 0
            let maxLat = coords.map(\.latitude).max() ?? 0
            let minLon = coords.map(\.longitude).min() ?? 0
            let maxLon = coords.map(\.longitude).max() ?? 0
            let centerLat = (minLat + maxLat) / 2
            let centerLon = (minLon + maxLon) / 2
            let spanLat = max(maxLat - minLat, 0.004) * 1.35
            let spanLon = max(maxLon - minLon, 0.004) * 1.35
            let region = MACoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MACoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
            )
            mapView.setRegion(region, animated: true)
            endMultiLegAndNotifyParent()
        }

        /// 步行规划回调中的多段分支；返回 true 表示已消费该回调
        private func handleMultiLegOnRouteSearchDone(path: AMapPath, mapView: MAMapView!) -> Bool {
            guard isMultiLegRouting,
                  let chain = multiLegResolvedCoords,
                  chain.count >= 2,
                  multiLegWalkingSegmentIndex < chain.count - 1,
                  let steps = path.steps as? [AMapStep],
                  !steps.isEmpty
            else { return false }

            var coordinates: [CLLocationCoordinate2D] = []
            for step in steps {
                guard let polylineStr = step.polyline else { continue }
                let points = polylineStr.split(separator: ";").compactMap { pair -> CLLocationCoordinate2D? in
                    let comps = pair.split(separator: ",")
                    if comps.count == 2, let lon = Double(comps[0]), let lat = Double(comps[1]) {
                        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    }
                    return nil
                }
                coordinates.append(contentsOf: points)
            }
            guard coordinates.count > 1 else {
                failMultiLeg("某段路线坐标不足")
                return true
            }
            let legIdx = multiLegWalkingSegmentIndex
            var coordsMut = coordinates
            guard let poly = LegIndexedPolyline(coordinates: &coordsMut, count: UInt(coordsMut.count)) else {
                failMultiLeg("无法创建路线折线")
                return true
            }
            poly.legIndex = legIdx
            mapView.add(poly)
            multiLegWalkingSegmentIndex += 1
            if multiLegWalkingSegmentIndex < chain.count - 1 {
                let from = chain[multiLegWalkingSegmentIndex]
                let to = chain[multiLegWalkingSegmentIndex + 1]
                searchWalkingRoute(from: from, to: to, on: mapView)
            } else {
                finishMultiLegSuccess(mapView: mapView)
            }
            return true
        }
        
        // POI搜索回调
        func onPOISearchDone(_ request: AMapPOISearchBaseRequest!, response: AMapPOISearchResponse!) {
            guard let mapView = mapView else { return }

            if let names = multiLegGeocodeNames {
                guard let poi = response.pois.first else {
                    failMultiLeg("地点「\(names[multiLegGeocodeCoords.count])」检索无结果")
                    return
                }
                let dest = CLLocationCoordinate2D(
                    latitude: CLLocationDegrees(poi.location.latitude),
                    longitude: CLLocationDegrees(poi.location.longitude)
                )
                multiLegGeocodeCoords.append(dest)
                if multiLegGeocodeCoords.count < names.count {
                    let nextKeyword = names[multiLegGeocodeCoords.count]
                    requestMultiLegPoi(keyword: nextKeyword)
                } else {
                    multiLegGeocodeNames = nil
                    multiLegResolvedCoords = multiLegGeocodeCoords
                    multiLegGeocodeCoords = []
                    multiLegWalkingSegmentIndex = 0
                    guard let chain = multiLegResolvedCoords, chain.count >= 2 else {
                        failMultiLeg("解析后坐标不足两段")
                        return
                    }
                    searchWalkingRoute(from: chain[0], to: chain[1], on: mapView)
                }
                return
            }

            guard let poi = response.pois.first else {
                print("[地图] POI 搜索无结果")
                return
            }
            
            let dest = CLLocationCoordinate2D(latitude: CLLocationDegrees(poi.location.latitude),
                                            longitude: CLLocationDegrees(poi.location.longitude))
            
            currentDest = dest
            updateARButtonState()

            DispatchQueue.main.async {
                mapView.setCenter(dest, animated: true)
                mapView.setZoomLevel(16, animated: true)
                self.beginPOIRouteSelection(to: dest)
            }
        }
        
        // 步行路线规划
        func searchWalkingRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, on mapView: MAMapView) {
            print("[地图] 规划步行路线 from=\(origin), to=\(destination)")
            let request = AMapWalkingRouteSearchRequest()
            request.origin = AMapGeoPoint.location(withLatitude: CGFloat(origin.latitude), longitude: CGFloat(origin.longitude))
            request.destination = AMapGeoPoint.location(withLatitude: CGFloat(destination.latitude), longitude: CGFloat(destination.longitude))
            request.showFieldsType = AMapWalkingRouteShowFieldType.all
            search?.aMapWalkingRouteSearch(request)
        }
        
        // 路线规划回调
        func onRouteSearchDone(_ request: AMapRouteSearchBaseRequest!, response: AMapRouteSearchResponse!) {
            guard let mapView = mapView else {
                print("❌ [路线规划] mapView 为空")
                DispatchQueue.main.async {
                    if self.isNavigating {
                        self.instructionLabel?.text = "地图视图不可用"
                    }
                }
                return
            }

            // POI「查看路线」：仅展示多方案 + 开始导航，不走大模型/多段分支
            if isAwaitingPOIRouteChoice {
                defer { isAwaitingPOIRouteChoice = false }
                let pathList = extractAMapPaths(from: response.route.paths)
                guard !pathList.isEmpty else {
                    print("❌ [POI路线] 路线数据为空")
                    DispatchQueue.main.async {
                        self.setSearchBarHidden(false)
                        self.updateFloatingStackLayout()
                    }
                    return
                }
                var options: [POIRouteOption] = []
                for p in pathList {
                    if let o = parsePOIRouteOption(from: p) { options.append(o) }
                }
                guard !options.isEmpty else {
                    print("❌ [POI路线] 无法解析任意方案")
                    DispatchQueue.main.async {
                        self.setSearchBarHidden(false)
                        self.updateFloatingStackLayout()
                    }
                    return
                }
                poiRouteOptions = options
                selectedPOIRouteIndex = 0
                DispatchQueue.main.async {
                    self.presentRouteChoicePanel()
                }
                return
            }
            
            // ========== 路线解析信息打印开始 ==========
            print("\n" + String(repeating: "=", count: 60))
            print("🗺️ [路线解析] 开始解析路线数据")
            print(String(repeating: "=", count: 60))
            
            // 打印路线基本信息
            print("📍 [路线基本信息]")
            if let origin = response.route.origin {
                print("  起点: (\(origin.latitude), \(origin.longitude))")
            }
            if let destination = response.route.destination {
                print("  终点: (\(destination.latitude), \(destination.longitude))")
            }
            print("  路线方案数量: \(response.route.paths.count)")
            
            // 安全检查：确保 paths 数组不为空
            guard !response.route.paths.isEmpty,
                  let path = response.route.paths.first else {
                print("❌ [路线规划] 路线数据为空")
                if self.isMultiLegRouting {
                    self.failMultiLeg("未找到可用步行路线")
                    return
                }
                DispatchQueue.main.async {
                    if self.isNavigating {
                        self.instructionLabel?.text = "未找到可用路线，请重试"
                    }
                }
                return
            }
            
            // 打印当前使用的路线方案信息
            print("\n📍 [当前路线方案]")
            print("  总距离: \(path.distance) 米 (\(String(format: "%.2f", Double(path.distance) / 1000.0)) 公里)")
            print("  预计时间: \(path.duration) 秒 (\(path.duration / 60) 分钟)")
            if let strategy = path.strategy {
                print("  导航策略: \(strategy)")
            }
            print("  路段数量: \(path.steps?.count ?? 0)")
            
            guard let steps = path.steps, !steps.isEmpty else {
                print("❌ [路线规划] 路线步骤为空")
                if self.isMultiLegRouting {
                    self.failMultiLeg("某段路线无可用步行步骤")
                    return
                }
                DispatchQueue.main.async {
                    if self.isNavigating {
                        self.instructionLabel?.text = "路线数据不完整"
                    }
                }
                return
            }

            if handleMultiLegOnRouteSearchDone(path: path, mapView: mapView) {
                return
            }
            
            // 打印每个路段的详细信息
            print("\n📍 [路段详细信息] (共 \(steps.count) 个路段)")
            print(String(repeating: "-", count: 60))
            
            var coordinates: [CLLocationCoordinate2D] = []
            var totalStepDistance = 0
            var totalStepDuration = 0
            
            // 清空之前的坐标数据
            self.routeStepCoordinates = []
            
            for (index, step) in steps.enumerated() {
                let stepDistance = step.distance
                let stepDuration = step.duration
                totalStepDistance += stepDistance
                totalStepDuration += stepDuration
                
                print("\n  [路段 \(index + 1)/\(steps.count)]")
                if let instruction = step.instruction {
                    print("    指令: \(instruction)")
                }
                if let road = step.road {
                    print("    道路: \(road)")
                }
                print("    距离: \(stepDistance) 米")
                print("    时间: \(stepDuration) 秒 (\(stepDuration / 60) 分钟)")
                if let action = step.action {
                    print("    动作: \(action)")
                }
                if let assistantAction = step.assistantAction {
                    print("    辅助动作: \(assistantAction)")
                }
                
                // 解析并保存每个路段的坐标点
                var stepCoordinates: [CLLocationCoordinate2D] = []
                if let polylineStr = step.polyline {
                    let points = polylineStr.split(separator: ";").compactMap { pair -> CLLocationCoordinate2D? in
                        let comps = pair.split(separator: ",")
                        if comps.count == 2, let lon = Double(comps[0]), let lat = Double(comps[1]) {
                            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        }
                        return nil
                    }
                    stepCoordinates = points
                    coordinates.append(contentsOf: points)
                    print("    坐标点数量: \(points.count)")
                    if !points.isEmpty {
                        print("    起点坐标: (\(points.first!.latitude), \(points.first!.longitude))")
                        print("    终点坐标: (\(points.last!.latitude), \(points.last!.longitude))")
                    }
                } else {
                    print("    坐标点: 无")
                }
                
                // 保存该路段的坐标点数组
                self.routeStepCoordinates.append(stepCoordinates)
            }
            
            print("\n" + String(repeating: "-", count: 60))
            print("📍 [路段汇总]")
            print("  路段总距离: \(totalStepDistance) 米")
            print("  路段总时间: \(totalStepDuration) 秒 (\(totalStepDuration / 60) 分钟)")
            print("  路线总坐标点: \(coordinates.count) 个")
            
            // 确保有足够的坐标点
            guard coordinates.count > 1 else {
                print("❌ [路线规划] 坐标点不足，无法绘制路线")
                DispatchQueue.main.async {
                    if self.isNavigating {
                        self.instructionLabel?.text = "路线坐标数据不足"
                    }
                }
                return
            }
            
            // 打印路线边界信息
            let minLat = coordinates.map { $0.latitude }.min() ?? 0
            let maxLat = coordinates.map { $0.latitude }.max() ?? 0
            let minLon = coordinates.map { $0.longitude }.min() ?? 0
            let maxLon = coordinates.map { $0.longitude }.max() ?? 0
            
            print("\n📍 [路线边界]")
            print("  最小纬度: \(minLat)")
            print("  最大纬度: \(maxLat)")
            print("  最小经度: \(minLon)")
            print("  最大经度: \(maxLon)")
            print("  纬度跨度: \(maxLat - minLat)")
            print("  经度跨度: \(maxLon - minLon)")
            
            print("\n" + String(repeating: "=", count: 60))
            print("✅ [路线解析] 路线解析完成，准备绘制")
            print(String(repeating: "=", count: 60) + "\n")
            // ========== 路线解析信息打印结束 ==========
            
            // 保存路线步骤信息
            self.routeSteps = steps
            self.routeTotalDistanceM = path.distance
            self.routeTotalDurationSec = path.duration
            self.currentStepIndex = 0
            self.isOffRoute = false // 路线重新规划后，重置偏离状态
            print("📍 [路线解析] 已保存 \(self.routeStepCoordinates.count) 个路段的坐标点")
            
            // 绘制路线
            let polyline = MAPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
            mapView.removeOverlays(mapView.overlays)
            mapView.add(polyline)
            
            // 在导航模式下，不自动调整地图区域，保持用户当前位置为中心
            // 只有在非导航模式下，才显示整条路线
            if !isNavigating {
                // 设置地图区域以显示整条路线
                let centerLat = (minLat + maxLat) / 2
                let centerLon = (minLon + maxLon) / 2
                let spanLat = max(maxLat - minLat, 0.01) * 1.5
                let spanLon = max(maxLon - minLon, 0.01) * 1.5
                
                let region = MACoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    span: MACoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
                )
                mapView.setRegion(region, animated: true)
                print("✅ [路线规划] 非导航模式：已设置地图区域显示整条路线")
            } else {
                // 导航模式下，保持用户当前位置为中心，使用合适的缩放级别
                // 地图视角由 jumpToStartLocation 和用户位置跟踪控制
                print("📍 [路线规划] 导航模式下保持用户位置为中心，不调整地图区域")
            }
            
            print("✅ [路线规划] 路线已绘制，坐标点数量: \(coordinates.count)")
            
            // 更新导航信息
            DispatchQueue.main.async {
                if self.isNavigating {
                    self.updateNavigationInfo()
                    print("📍 [路线规划] 已刷新导航 UI（剩余里程/ETA 来自高德路径）")
                }
            }
        }
        
        // 开始步行导航
        func startWalkingNavigation(to destination: CLLocationCoordinate2D) {
            guard !isNavigating else { return }
            
            print("🚶 [步行导航] 开始导航到: \(destination)")
            
            // 确保在主线程上执行
            DispatchQueue.main.async {
                self.clearServerSegmentedNavigationState()
                self.isNavigating = true
                
                // 隐藏搜索框和信息卡片
                self.hideNonNavigationUI()
                
                // 显示导航UI
                self.showNavigationUI()
                
                // 先调用路线规划API，而不是直接画直线
                guard let mapView = self.mapView,
                      let currentLocation = mapView.userLocation?.coordinate else {
                    print("❌ [导航] 无法获取当前位置，无法规划路线")
                    DispatchQueue.main.async {
                        self.instructionLabel?.text = "无法获取当前位置，请检查定位权限"
                    }
                    self.isNavigating = false
                    return
                }
                
                // 保存导航目的地，用于重新规划
                self.navigationDestination = destination
                self.isOffRoute = false
                self.lastReplanTime = nil
                
                // 调用路线规划API
                print("🗺️ [导航] 开始规划路线: \(currentLocation) -> \(destination)")
                self.instructionLabel?.text = "正在规划路线..."
                self.searchWalkingRoute(from: currentLocation, to: destination, on: mapView)
                
                mapView.isRotateEnabled = true
                mapView.userTrackingMode = .followWithHeading
                self.applyUserLocationHeadingIndicator(mapView, navigating: true)
                // 跳转到起始位置
                self.jumpToStartLocation()
                
                // 启动步行导航 - 添加延迟确保UI更新完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.startNavigationTimer()
                    self.updateARButtonState()
                    self.parent.onNavigationStart?()
                }
            }
        }
        
        // 退出导航
        @objc func exitNavigation() {
            guard isNavigating else { return }
            
            print("🛑 [步行导航] 退出导航")

            if let sid = navigationSessionId {
                Task {
                    try? await APIClient.shared.patchNavigationSession(sessionId: sid, activeLegIndex: nil, status: "CANCELLED")
                }
            }
            clearServerSegmentedNavigationState()
            lastIngestedNavigationSessionId = nil
            
            isNavigating = false
            isAwaitingPOIRouteChoice = false
            dismissRouteChoicePanel()

            // 停止定时器
            stopNavigationTimer()

            routeSteps = []
            routeStepCoordinates = []
            routeTotalDistanceM = 0
            routeTotalDurationSec = 0
            currentStepIndex = 0
            
            // 停止导航（里程/ETA 已全部来自高德路径，不再使用独立定位管理器）
            
            routeGuidanceView?.removeFromSuperview()
            routeGuidanceView = nil

            // 隐藏导航UI
            hideNavigationUI()

            if let mv = mapView {
                mv.removeOverlays(mv.overlays)
                mv.userTrackingMode = .follow
                mv.isRotateEnabled = false
                applyUserLocationHeadingIndicator(mv, navigating: false)
            }
            navigationDestination = nil

            // 显示搜索框
            showNonNavigationUI()
            
            // 更新AR按钮状态
            updateARButtonState()
            
            parent.onNavigationStop?()
            updateFloatingStackLayout()
        }
        
        deinit {
            // 清理所有资源，防止内存泄漏
            stopNavigationTimer()
            search?.delegate = nil
            mapView?.delegate = nil
            print("✅ [Coordinator] 资源已清理")
        }
        
        // 显示导航UI
        private func showNavigationUI() {
            navTopInfoView?.isHidden = false
            navBottomBarView?.isHidden = false
            updateFloatingStackLayout()
            updateNavigationInfo()
            bringFloatingButtonsToFront()
        }
        
        // 隐藏导航UI
        private func hideNavigationUI() {
            navTopInfoView?.isHidden = true
            navBottomBarView?.isHidden = true
            updateFloatingStackLayout()
        }
        
        // 根据用户位置判断当前路段，并检测是否偏离路线
        private func updateCurrentStepBasedOnLocation() {
            guard let mapView = mapView,
                  let userLocation = mapView.userLocation?.coordinate,
                  !routeSteps.isEmpty,
                  !routeStepCoordinates.isEmpty,
                  isNavigating else {
                return
            }
            
            let userLocationPoint = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            var newStepIndex = currentStepIndex
            var minDistance = Double.infinity
            var closestStepIndex = currentStepIndex
            
            // 检查所有路段，找到最近的路段（用于偏离检测）
            var globalMinDistance = Double.infinity
            for (index, stepCoordinates) in routeStepCoordinates.enumerated() {
                if stepCoordinates.isEmpty { continue }
                
                var stepMinDistance = Double.infinity
                for coord in stepCoordinates {
                    let coordLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    let distance = userLocationPoint.distance(from: coordLocation)
                    stepMinDistance = min(stepMinDistance, distance)
                }
                
                if stepMinDistance < globalMinDistance {
                    globalMinDistance = stepMinDistance
                }
            }
            
            // 偏离检测：如果用户距离所有路段都超过200米，判定为偏离路线
            let offRouteThreshold: Double = 200.0
            if globalMinDistance > offRouteThreshold {
                if !isOffRoute {
                    print("⚠️ [偏离检测] 用户已偏离路线，距离最近路段: \(Int(globalMinDistance))米")
                    isOffRoute = true
                    // 触发重新规划
                    replanRouteIfNeeded()
                }
                return // 偏离路线时，不更新路段索引
            } else {
                // 用户回到路线上
                if isOffRoute {
                    print("✅ [偏离检测] 用户已回到路线上")
                    isOffRoute = false
                }
            }
            
            // 从当前路段开始检查，向前查找（最多检查当前路段和接下来3个路段）
            let searchEndIndex = min(currentStepIndex + 4, routeSteps.count)
            
            for index in currentStepIndex..<searchEndIndex {
                let stepCoordinates = routeStepCoordinates[index]
                if stepCoordinates.isEmpty { continue }
                
                // 计算用户位置到该路段最近点的距离
                var stepMinDistance = Double.infinity
                for coord in stepCoordinates {
                    let coordLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    let distance = userLocationPoint.distance(from: coordLocation)
                    stepMinDistance = min(stepMinDistance, distance)
                }
                
                // 记录最近的路段
                if stepMinDistance < minDistance {
                    minDistance = stepMinDistance
                    closestStepIndex = index
                }
                
                // 如果距离小于50米，认为用户在该路段上
                if stepMinDistance < 50 {
                    newStepIndex = index
                    break
                }
            }
            
            // 如果当前路段距离太远（>100米），切换到最近的路段
            if minDistance > 100 && closestStepIndex != currentStepIndex {
                newStepIndex = closestStepIndex
            }
            
            // 如果用户已经超过当前路段，检查是否应该进入下一路段
            if newStepIndex == currentStepIndex && currentStepIndex < routeSteps.count - 1 {
                let currentStepCoords = routeStepCoordinates[currentStepIndex]
                if !currentStepCoords.isEmpty {
                    // 检查用户是否接近当前路段的终点
                    let endCoord = currentStepCoords.last!
                    let endLocation = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)
                    let distanceToEnd = userLocationPoint.distance(from: endLocation)
                    
                    // 如果距离终点小于30米，进入下一路段
                    if distanceToEnd < 30 {
                        newStepIndex = min(currentStepIndex + 1, routeSteps.count - 1)
                    }
                }
            }
            
            // 如果路段索引发生变化，更新指引
            if newStepIndex != currentStepIndex {
                print("📍 [导航指引] 路段更新: \(currentStepIndex + 1) -> \(newStepIndex + 1), 距离: \(Int(minDistance))米")
                currentStepIndex = newStepIndex
                updateCurrentStepGuidance()
            }
        }
        
        // 重新规划路线（如果用户偏离路线）
        private func replanRouteIfNeeded() {
            guard let mapView = mapView,
                  let userLocation = mapView.userLocation?.coordinate,
                  let destination = navigationDestination,
                  isNavigating else {
                return
            }
            
            // 防止频繁重新规划：距离上次重新规划至少10秒
            if let lastReplan = lastReplanTime {
                let timeSinceLastReplan = Date().timeIntervalSince(lastReplan)
                if timeSinceLastReplan < 10.0 {
                    print("⏱️ [重新规划] 距离上次重新规划仅 \(Int(timeSinceLastReplan)) 秒，跳过")
                    return
                }
            }
            
            print("🔄 [重新规划] 开始从当前位置重新规划路线")
            print("   当前位置: \(userLocation)")
            print("   目的地: \(destination)")
            
            // 更新UI提示
            DispatchQueue.main.async {
                self.instructionLabel?.text = "已偏离路线，正在重新规划..."
            }
            
            // 记录重新规划时间
            lastReplanTime = Date()
            
            // 从当前位置重新规划到当前段终点（后端分段模式）或总终点
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.serverSegmentedMode, !self.serverSegmentWaypoints.isEmpty {
                    let n = self.serverSegmentWaypoints.count
                    if self.serverApproachStart {
                        let w0 = self.serverSegmentWaypoints[0].coordinate
                        self.searchWalkingRoute(from: userLocation, to: w0, on: mapView)
                    } else if self.serverActiveLegIndex + 1 < n {
                        let toIdx = self.serverActiveLegIndex + 1
                        let destCoord = self.serverSegmentWaypoints[toIdx].coordinate
                        self.searchWalkingRoute(from: userLocation, to: destCoord, on: mapView)
                    } else {
                        self.searchWalkingRoute(from: userLocation, to: destination, on: mapView)
                    }
                } else {
                    self.searchWalkingRoute(from: userLocation, to: destination, on: mapView)
                }
            }
        }
        
        // 更新当前路段指引
        private func updateCurrentStepGuidance() {
            guard currentStepIndex < routeSteps.count else { return }
            
            let currentStep = routeSteps[currentStepIndex]
            
            // 获取用户当前位置
            guard let mapView = mapView,
                  let userLocation = mapView.userLocation?.coordinate else {
                // 如果没有位置信息，显示基本指引
                var guidanceText = ""
                if let instruction = currentStep.instruction {
                    guidanceText = instruction
                }
                if let road = currentStep.road {
                    if !guidanceText.isEmpty {
                        guidanceText += " - \(road)"
                    } else {
                        guidanceText = road
                    }
                }
                if guidanceText.isEmpty {
                    guidanceText = "继续前行 \(currentStep.distance)米"
                }
                instructionLabel?.text = guidanceText
                updateTurnIconForGuidance(guidanceText)
                NavigationSpeechController.shared.speakGuidance(guidanceText)
                return
            }
            
            let userLocationPoint = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            
            // 计算到当前路段终点的实时距离
            var distanceToStepEnd = Double(currentStep.distance)
            if currentStepIndex < routeStepCoordinates.count {
                let stepCoords = routeStepCoordinates[currentStepIndex]
                if !stepCoords.isEmpty {
                    let endCoord = stepCoords.last!
                    let endLocation = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)
                    distanceToStepEnd = userLocationPoint.distance(from: endLocation)
                }
            }
            
            // 构建导航指引文本（包含实时距离）
            var guidanceText = ""
            
            // 如果即将到达当前路段终点，显示下一路段的指引
            if distanceToStepEnd < 30 && currentStepIndex < routeSteps.count - 1 {
                let nextStep = routeSteps[currentStepIndex + 1]
                if let nextInstruction = nextStep.instruction {
                    guidanceText = "\(Int(distanceToStepEnd))米后\(nextInstruction)"
                } else {
                    guidanceText = "\(Int(distanceToStepEnd))米后进入下一段"
                }
            } else {
                // 显示当前路段指引和实时剩余距离
                if let instruction = currentStep.instruction {
                    guidanceText = "\(instruction)，剩余 \(Int(distanceToStepEnd))米"
                } else {
                    guidanceText = "继续前行，剩余 \(Int(distanceToStepEnd))米"
                }
            }
            
            // 添加道路名称
            if let road = currentStep.road {
                if !guidanceText.contains(road) {
                    guidanceText += " - \(road)"
                }
            }
            
            instructionLabel?.text = guidanceText
            updateTurnIconForGuidance(guidanceText)
            NavigationSpeechController.shared.speakGuidance(guidanceText)
        }
        private func hideNonNavigationUI() {
            setSearchBarHidden(true)
        }
        
        // 显示非导航UI
        private func showNonNavigationUI() {
            setSearchBarHidden(false)
        }

        /// 沿当前高德 `routeSteps` 的剩余路程（米）：到当前 step 终点 + 后续各 step 的 `distance`
        private func remainingDistanceAlongRouteMeters(user: CLLocationCoordinate2D) -> Double {
            guard !routeSteps.isEmpty, currentStepIndex < routeSteps.count else { return 0 }
            let currentStep = routeSteps[currentStepIndex]
            var distanceToStepEnd = Double(currentStep.distance)
            if currentStepIndex < routeStepCoordinates.count {
                let stepCoords = routeStepCoordinates[currentStepIndex]
                if !stepCoords.isEmpty, let endCoord = stepCoords.last {
                    let u = CLLocation(latitude: user.latitude, longitude: user.longitude)
                    let e = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)
                    distanceToStepEnd = u.distance(from: e)
                }
            }
            var remaining = distanceToStepEnd
            if currentStepIndex + 1 < routeSteps.count {
                for i in (currentStepIndex + 1)..<routeSteps.count {
                    remaining += Double(routeSteps[i].distance)
                }
            }
            if routeTotalDistanceM > 0 {
                remaining = min(remaining, Double(routeTotalDistanceM))
            }
            return max(0, remaining)
        }

        /// 剩余时间（秒）：当前 step 按剩余路程占 step 总长比例 × `duration`，后续 step 累加高德 `duration`
        private func remainingTimeAlongRouteSec(user: CLLocationCoordinate2D) -> Int {
            guard !routeSteps.isEmpty, currentStepIndex < routeSteps.count else { return 0 }
            let currentStep = routeSteps[currentStepIndex]
            var distanceToStepEnd = Double(currentStep.distance)
            if currentStepIndex < routeStepCoordinates.count {
                let stepCoords = routeStepCoordinates[currentStepIndex]
                if !stepCoords.isEmpty, let endCoord = stepCoords.last {
                    let u = CLLocation(latitude: user.latitude, longitude: user.longitude)
                    let e = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)
                    distanceToStepEnd = u.distance(from: e)
                }
            }
            let stepLen = max(Double(currentStep.distance), 1)
            let frac = min(1.0, distanceToStepEnd / stepLen)
            var sec = Int(round(Double(currentStep.duration) * frac))
            for i in (currentStepIndex + 1)..<routeSteps.count {
                sec += routeSteps[i].duration
            }
            if routeTotalDurationSec > 0 {
                sec = min(sec, routeTotalDurationSec)
            }
            return max(0, sec)
        }

        private func formatWalkingETA(seconds: Int) -> String {
            let s = max(0, seconds)
            if s < 45 { return "不到1分钟" }
            let mins = s / 60
            if mins < 60 { return "约\(mins)分钟" }
            let h = mins / 60
            let m = mins % 60
            return m > 0 ? "约\(h)小时\(m)分钟" : "约\(h)小时"
        }
        
        // 更新导航信息
        private func updateNavigationInfo() {
            DispatchQueue.main.async {
                // 根据用户位置更新当前路段
                self.updateCurrentStepBasedOnLocation()
                
                // 更新导航指令（这会根据当前路段和实时位置更新）
                self.updateCurrentStepGuidance()
                
                // 剩余距离 / ETA：完全来自高德路径 steps + duration，非直线近似
                let distance: Double
                let time: String
                if let u = self.mapView?.userLocation?.coordinate, !self.routeSteps.isEmpty {
                    distance = self.remainingDistanceAlongRouteMeters(user: u)
                    let sec = self.remainingTimeAlongRouteSec(user: u)
                    time = self.formatWalkingETA(seconds: sec)
                } else if self.routeTotalDistanceM > 0 {
                    distance = Double(self.routeTotalDistanceM)
                    time = self.formatWalkingETA(seconds: self.routeTotalDurationSec)
                } else {
                    distance = 0
                    time = "--"
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
                }

                if self.isNavigating {
                    if let h = self.mapView?.userLocation?.heading {
                        if h.trueHeading >= 0 {
                            self.headingLabel?.text = String(format: "朝向 %.0f°", h.trueHeading)
                        } else {
                            self.headingLabel?.text = String(format: "朝向 %.0f°", h.magneticHeading)
                        }
                    } else if let course = self.mapView?.userLocation?.location?.course, course >= 0 {
                        self.headingLabel?.text = String(format: "行进方向 %.0f°", course)
                    } else {
                        self.headingLabel?.text = "朝向 —"
                    }
                }

                if self.serverSegmentedMode {
                    self.evaluateServerSegmentAdvance()
                }
            }
        }
        
        // 启动定时器更新导航信息
        private func startNavigationTimer() {
            // 先取消之前的 Timer
            navigationTimer?.invalidate()
            navigationTimer = nil
            
            // 创建新的 Timer 并保存引用
            navigationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self, self.isNavigating else { return }
                
                DispatchQueue.main.async {
                    self.updateNavigationInfo()
                }
            }
        }
        
        // 停止定时器
        private func stopNavigationTimer() {
            navigationTimer?.invalidate()
            navigationTimer = nil
        }
        
        // 绘制导航路线
        private func drawNavigationRoute(to destination: CLLocationCoordinate2D) {
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
            
            // 在导航模式下，不自动调整地图区域，保持用户当前位置为中心
            if !isNavigating {
                // 设置地图区域以显示整条路线（仅非导航模式）
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
                print("✅ [导航] 非导航模式：已设置地图区域显示整条路线")
            } else {
                print("📍 [导航] 导航模式下保持用户位置为中心，不调整地图区域")
            }
            
            print("✅ [导航] 路线绘制完成")
        }
        
        // 跳转到起始位置
        private func jumpToStartLocation() {
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
            
            // 导航时跟朝向，需允许地图随航向旋转
            mapView.userTrackingMode = isNavigating ? .followWithHeading : .follow
            if isNavigating {
                applyUserLocationHeadingIndicator(mapView, navigating: true)
            }

            print("✅ [导航] 已跳转到起始位置")
        }
        
        // 更新AR按钮状态
        private func updateARButtonState() {
            DispatchQueue.main.async {
                guard let arButton = self.arButton else { return }
                
                // 只有在导航模式下才启用AR按钮
                let shouldEnable = self.isNavigating && self.currentDest != nil
                
                arButton.isEnabled = shouldEnable
                arButton.backgroundColor = shouldEnable ? .systemBlue : .systemGray
                
                print("🔘 [AR按钮] 状态更新: \(shouldEnable ? "启用(蓝色)" : "禁用(灰色)"), 导航中: \(self.isNavigating), 有目的地: \(self.currentDest != nil)")
            }
        }
        
        // AR导航
        @objc func openARDirect() {
            guard let dest = currentDest else { return }
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let vc = UIHostingController(rootView: ARNavigationView(destination: dest))
                window.rootViewController?.present(vc, animated: true)
            }
        }
        
        // 地图代理方法
        func mapView(_ mapView: MAMapView!, rendererFor overlay: MAOverlay!) -> MAOverlayRenderer! {
            if let legLine = overlay as? LegIndexedPolyline {
                let renderer = MAPolylineRenderer(polyline: legLine)
                let colors: [UIColor] = [.systemBlue, .systemOrange, .systemGreen]
                let c = colors[legLine.legIndex % colors.count]
                renderer?.strokeColor = c.withAlphaComponent(0.9)
                renderer?.lineWidth = 7.0
                return renderer
            }
            if let polyline = overlay as? MAPolyline {
                let renderer = MAPolylineRenderer(polyline: polyline)
                renderer?.strokeColor = UIColor.systemBlue
                renderer?.lineWidth = 8.0 // 增加线宽使其更明显
                print("🎨 [路线渲染] 创建路线渲染器，线宽: 8.0，颜色: 蓝色")
                return renderer
            }
            return nil
        }
        
        func mapView(_ mapView: MAMapView!, didUpdate userLocation: MAUserLocation!, updatingLocation: Bool) {
            if updatingLocation, let coord = userLocation.location?.coordinate {
                latestUserLocation = coord
                
                // 如果正在导航，根据位置更新当前路段和距离
                if isNavigating {
                    updateCurrentStepBasedOnLocation()
                }
            }
        }
        
        func aMapSearchRequest(_ request: Any!, didFailWithError error: Error!) {
            print("❌ [路线规划] 搜索请求失败：\(error.localizedDescription)")
            if isAwaitingPOIRouteChoice {
                isAwaitingPOIRouteChoice = false
                dismissRouteChoicePanel()
                DispatchQueue.main.async {
                    self.setSearchBarHidden(false)
                    self.updateFloatingStackLayout()
                }
                return
            }
            if isMultiLegRouting || multiLegGeocodeNames != nil {
                failMultiLeg("高德请求失败：\(error.localizedDescription)")
                return
            }

            // 显示错误信息给用户
            DispatchQueue.main.async {
                if self.isNavigating {
                    var errorMessage = "路线规划失败"
                    
                    // 根据错误类型提供更友好的错误信息
                    let errorDescription = error.localizedDescription.lowercased()
                    if errorDescription.contains("network") || errorDescription.contains("网络") {
                        errorMessage = "网络连接失败，请检查网络设置"
                    } else if errorDescription.contains("timeout") || errorDescription.contains("超时") {
                        errorMessage = "请求超时，请重试"
                    } else if errorDescription.contains("key") || errorDescription.contains("密钥") {
                        errorMessage = "API密钥无效，请联系开发者"
                    } else if errorDescription.contains("permission") || errorDescription.contains("权限") {
                        errorMessage = "权限不足，请检查应用权限设置"
                    } else {
                        errorMessage = "路线规划失败：\(error.localizedDescription)"
                    }
                    
                    self.instructionLabel?.text = errorMessage
                    self.remainLabel?.text = "路线规划失败"
                    
                    // 如果正在导航，停止导航状态
                    self.isNavigating = false
                    self.hideNavigationUI()
                    self.showNonNavigationUI()
                }
            }
        }
    }
}

// 自定义搜索框
protocol CustomSearchBarViewDelegate: AnyObject {
    func didTapSearch(with keyword: String)
}

class CustomSearchBarView: UIView, UITextFieldDelegate {
    weak var delegate: CustomSearchBarViewDelegate?
    private let iconView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
    private let textField = UITextField()
    private let micView = UIImageView(image: UIImage(systemName: "mic.fill"))
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.white.withAlphaComponent(0.95)
        layer.cornerRadius = 26
        layer.masksToBounds = true
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        
        iconView.tintColor = .gray
        micView.tintColor = .gray
        textField.placeholder = "搜索地点"
        textField.font = UIFont.boldSystemFont(ofSize: 18)
        textField.textColor = .darkGray
        textField.delegate = self
        textField.returnKeyType = .search
        
        let stack = UIStackView(arrangedSubviews: [iconView, textField, micView])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            micView.widthAnchor.constraint(equalToConstant: 28),
            micView.heightAnchor.constraint(equalToConstant: 28),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let text = textField.text {
            delegate?.didTapSearch(with: text)
        }
        textField.resignFirstResponder()
        return true
    }
}
