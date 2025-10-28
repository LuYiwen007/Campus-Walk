import SwiftUI
import AMapNaviKit

// AMapNaviWalkView的SwiftUI包装器
struct AMapNaviWalkViewRepresentable: UIViewRepresentable {
    @Binding var isNavigating: Bool
    let destination: CLLocationCoordinate2D
    let onNavigationStart: (() -> Void)?
    let onNavigationStop: (() -> Void)?
    
    init(
        isNavigating: Binding<Bool>,
        destination: CLLocationCoordinate2D,
        onNavigationStart: (() -> Void)? = nil,
        onNavigationStop: (() -> Void)? = nil
    ) {
        self._isNavigating = isNavigating
        self.destination = destination
        self.onNavigationStart = onNavigationStart
        self.onNavigationStop = onNavigationStop
    }
    
    func makeUIView(context: Context) -> AMapNaviWalkView {
        let walkView = AMapNaviWalkView()
        walkView.delegate = context.coordinator
        
        // 配置导航视图属性
        walkView.showUIElements = true
        walkView.showBrowseRouteButton = true
        walkView.showMoreButton = true
        
        // 设置显示模式
        walkView.showMode = .carPositionLocked
        walkView.trackingMode = .mapNorth
        
        // 延迟添加导航视图到管理器，避免初始化冲突
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let navigationManager = WalkingNavigationManager.shared
            if let amapWalkManager = navigationManager.getWalkManager() {
                amapWalkManager.addDataRepresentative(walkView)
                print("✅ [SwiftUI包装器] 导航视图已添加到管理器")
            }
        }
        
        return walkView
    }
    
    func updateUIView(_ uiView: AMapNaviWalkView, context: Context) {
        // 根据导航状态更新视图
        if isNavigating {
            // 开始导航时的处理
            context.coordinator.startNavigation(to: destination)
        } else {
            // 停止导航时的处理
            context.coordinator.stopNavigation()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            isNavigating: $isNavigating,
            onNavigationStart: onNavigationStart,
            onNavigationStop: onNavigationStop
        )
    }
    
    class Coordinator: NSObject, AMapNaviWalkViewDelegate {
        @Binding var isNavigating: Bool
        let onNavigationStart: (() -> Void)?
        let onNavigationStop: (() -> Void)?
        private let walkNavManager = WalkingNavigationManager.shared
        
        init(
            isNavigating: Binding<Bool>,
            onNavigationStart: (() -> Void)?,
            onNavigationStop: (() -> Void)?
        ) {
            self._isNavigating = isNavigating
            self.onNavigationStart = onNavigationStart
            self.onNavigationStop = onNavigationStop
        }
        
        func startNavigation(to destination: CLLocationCoordinate2D) {
            print("🚀 [SwiftUI包装器] 开始导航到: \(destination)")
            walkNavManager.startWalkingNavigation(to: destination)
            onNavigationStart?()
        }
        
        func stopNavigation() {
            print("🛑 [SwiftUI包装器] 停止导航")
            walkNavManager.stopNavigation()
            onNavigationStop?()
        }
        
        // MARK: - AMapNaviWalkViewDelegate
        
        func walkView(_ walkView: AMapNaviWalkView, didChange showMode: AMapNaviWalkViewShowMode) {
            print("🔄 [SwiftUI包装器] 显示模式变化: \(showMode.rawValue)")
        }
        
        func walkView(_ walkView: AMapNaviWalkView, didChangeOrientation isLandscape: Bool) {
            print("📱 [SwiftUI包装器] 屏幕方向变化: \(isLandscape ? "横屏" : "竖屏")")
        }
        
        func walkViewCloseButtonClicked(_ walkView: AMapNaviWalkView) {
            print("❌ [SwiftUI包装器] 用户点击关闭按钮")
            DispatchQueue.main.async {
                self.isNavigating = false
            }
        }
        
        func walkViewMoreButtonClicked(_ walkView: AMapNaviWalkView) {
            print("⚙️ [SwiftUI包装器] 用户点击更多按钮")
        }
        
        func walkViewBrowseRouteButtonClicked(_ walkView: AMapNaviWalkView) {
            print("🗺️ [SwiftUI包装器] 用户点击全览按钮")
        }
        
        func walkViewTrafficButtonClicked(_ walkView: AMapNaviWalkView) {
            print("🚦 [SwiftUI包装器] 用户点击交通按钮")
        }
        
        func walkViewZoomInOutButtonClicked(_ walkView: AMapNaviWalkView) {
            print("🔍 [SwiftUI包装器] 用户点击缩放按钮")
        }
    }
}

// 预览
#if DEBUG
struct AMapNaviWalkViewRepresentable_Previews: PreviewProvider {
    @State static var isNavigating = false
    
    static var previews: some View {
        AMapNaviWalkViewRepresentable(
            isNavigating: $isNavigating,
            destination: CLLocationCoordinate2D(latitude: 23.129, longitude: 113.264)
        )
        .ignoresSafeArea()
    }
}
#endif
