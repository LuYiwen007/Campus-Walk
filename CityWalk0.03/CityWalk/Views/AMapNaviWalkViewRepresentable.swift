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
        
        // 保存引用到 Coordinator
        context.coordinator.walkViewRef = walkView
        
        // 配置导航视图属性
        walkView.showUIElements = true
        walkView.showBrowseRouteButton = true
        walkView.showMoreButton = true
        
        // 设置显示模式
        walkView.showMode = .carPositionLocked
        walkView.trackingMode = .mapNorth
        
        // 立即尝试添加导航视图到管理器（如果管理器已初始化）
        // 如果未初始化，会在 startNavigation 中再次尝试
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak walkView] in
            guard let walkView = walkView else { return }
            let navigationManager = WalkingNavigationManager.shared
            if let amapWalkManager = navigationManager.getWalkManager() {
                amapWalkManager.addDataRepresentative(walkView)
                print("✅ [SwiftUI包装器] 导航视图已添加到管理器")
            } else {
                print("⚠️ [SwiftUI包装器] 导航管理器尚未初始化，将在启动导航时添加")
            }
        }
        
        return walkView
    }
    
    func updateUIView(_ uiView: AMapNaviWalkView, context: Context) {
        // 防止重复调用 - 只在状态变化时执行
        // SwiftUI 的 updateUIView 可能被多次调用，需要防抖处理
        
        if isNavigating && !context.coordinator.hasStartedNavigation {
            // 延迟执行，避免在视图更新过程中触发
            DispatchQueue.main.async {
                context.coordinator.startNavigation(to: destination)
            }
        } else if !isNavigating && context.coordinator.hasStartedNavigation {
            // 状态变为非导航时停止
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
    
    // 视图销毁时的清理
    static func dismantleUIView(_ uiView: AMapNaviWalkView, coordinator: Coordinator) {
        print("🧹 [SwiftUI包装器] 清理导航视图")
        coordinator.cleanup()
    }
    
    class Coordinator: NSObject, AMapNaviWalkViewDelegate {
        @Binding var isNavigating: Bool
        let onNavigationStart: (() -> Void)?
        let onNavigationStop: (() -> Void)?
        private let walkNavManager = WalkingNavigationManager.shared
        
        // 防止重复调用的标志（internal 访问级别，允许结构体访问）
        var hasStartedNavigation = false
        var walkViewRef: AMapNaviWalkView?
        
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
            // 防止重复调用
            guard !hasStartedNavigation else {
                print("⚠️ [SwiftUI包装器] 导航已启动，跳过重复调用")
                return
            }
            
            print("🚀 [SwiftUI包装器] 开始导航到: \(destination)")
            hasStartedNavigation = true
            
            // 确保在主线程执行
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // 确保导航视图已添加到管理器
                self.ensureWalkViewAddedToManager()
                
                // 启动导航
                self.walkNavManager.startWalkingNavigation(to: destination)
                self.onNavigationStart?()
            }
        }
        
        func stopNavigation() {
            print("🛑 [SwiftUI包装器] 停止导航")
            
            // 重置标志
            hasStartedNavigation = false
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.walkNavManager.stopNavigation()
                self.onNavigationStop?()
            }
        }
        
        // 确保导航视图已添加到管理器
        private func ensureWalkViewAddedToManager() {
            guard let walkView = walkViewRef else {
                print("⚠️ [SwiftUI包装器] walkViewRef 为 nil，无法添加到管理器")
                return
            }
            
            let navigationManager = WalkingNavigationManager.shared
            if let amapWalkManager = navigationManager.getWalkManager() {
                // 安全地添加导航视图（SDK 会处理重复添加的情况）
                amapWalkManager.addDataRepresentative(walkView)
                print("✅ [SwiftUI包装器] 确保导航视图已添加到管理器")
                
                // 确保 walkView 也被保存到 WalkingNavigationManager
                // 这样在路线规划成功时可以确认视图已添加
                navigationManager.setWalkView(walkView)
            } else {
                print("❌ [SwiftUI包装器] 导航管理器尚未初始化")
            }
        }
        
        // 清理资源
        func cleanup() {
            // 停止导航
            if hasStartedNavigation {
                stopNavigation()
            }
            
            // 从管理器中移除视图
            if let walkView = walkViewRef {
                let navigationManager = WalkingNavigationManager.shared
                if let amapWalkManager = navigationManager.getWalkManager() {
                    amapWalkManager.removeDataRepresentative(walkView)
                    print("🧹 [SwiftUI包装器] 已从管理器中移除导航视图")
                }
            }
            
            // 清空引用
            walkViewRef = nil
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
