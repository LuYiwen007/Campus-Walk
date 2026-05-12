import SwiftUI
import MapKit

// 聊天主界面，包含消息列表、输入区和地图弹出逻辑
struct MessageView: View {
    @EnvironmentObject var viewModel: MessageViewModel // 聊天数据模型
    @StateObject private var settings = SettingsManager.shared // 设置管理器
    /// 用户侧气泡头像（登录态由后端账号区分，此处统一用系统图标）
    private var userBubbleAvatar: Image { Image(systemName: "person.crop.circle.fill") }
    @State private var mapHeight: CGFloat = 0 // 地图高度
    @State private var isChatMinimized = false // 聊天页面是否收缩为小圆圈
    @State private var showChat = true // 是否显示聊天页面
    @State private var showImagePicker = false // 是否显示图片选择器
    @State private var showPhotoActionSheet = false // 是否显示图片操作表
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var dragOffset: CGSize = .zero // 聊天小圆圈拖动偏移
    @Namespace private var animation // 用于动画
    
    @State private var showProfileDrawer = false // 控制侧边抽屉
    @State private var routeToShow: String? = nil // 用于传递给地图页的路线信息
    // 新增：输入框焦点状态
    @FocusState private var isInputFocused: Bool
    
    // 与 Tab 地图共享：确认路线后写入待规划地名链
    @ObservedObject var sharedMapState: SharedMapState

    private static func walkPlaceNameChain(from variant: RouteVariantDTO) -> [String] {
        let mid = Array(variant.scenicSpotExamples.prefix(3))
        let raw = [variant.startLabel] + mid + [variant.endLabel]
        return raw.reduce(into: [String]()) { acc, s in
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            if acc.last != t { acc.append(t) }
        }
    }
    
    // 地图高度的常量
    private let minMapHeight: CGFloat = UIScreen.main.bounds.height * 0.5
    private let maxMapHeight: CGFloat = UIScreen.main.bounds.height * 0.5
    private let defaultMapHeight: CGFloat = UIScreen.main.bounds.height * 0.5
    // 新增：用于地图和路线详情联动
    @State private var selectedPlaceIndex: Int = 0
    @State private var startCoordinate: CLLocationCoordinate2D? = nil
    @State private var destinationLocation: CLLocationCoordinate2D? = nil
    
    // 新增：导航相关状态
    @State private var isNavigationMode: Bool = false
    @State private var showNavigationControls: Bool = false
    
    // 主体视图，渲染聊天界面、消息列表、地图弹窗、输入区等
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // 用户资料抽屉
            if showProfileDrawer {
                HStack(spacing: 0) {
                    UserProfileView(isShowingProfile: $showProfileDrawer)
                        .frame(width: UIScreen.main.bounds.width * 0.85, alignment: .leading)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .background(Color.white)
                        .ignoresSafeArea(edges: .top)
                        .transition(.move(edge: .leading))
                    Spacer(minLength: 0)
                }
                .background(
                    Color.black.opacity(0.2)
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation { showProfileDrawer = false } }
                )
                .ignoresSafeArea()
                .zIndex(2)
            }
            
            // 地图始终在底层
            if !showChat {
                MapView(
                    isExpanded: .constant(true),
                    isShowingProfile: .constant(false),
                    routeInfo: routeToShow,
                    destinationLocation: $destinationLocation,
                    selectedPlaceIndex: $selectedPlaceIndex,
                    startCoordinateBinding: $startCoordinate,
                    isNavigationMode: $isNavigationMode,
                    pendingWalkLegPlaceNames: sharedMapState.pendingWalkLegPlaceNames,
                    onConsumePendingWalkLeg: { sharedMapState.pendingWalkLegPlaceNames = nil },
                    pendingNavigationSession: sharedMapState.pendingNavigationSession,
                    onConsumePendingNavigationSession: { sharedMapState.pendingNavigationSession = nil },
                    onBackToChat: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isChatMinimized = false
                            showChat = true
                            routeToShow = nil
                        }
                    }
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }
            // 聊天主页面
            if showChat {
        VStack(spacing: 0) {
                    // 顶部栏
            HStack {
                Button(action: {
                    withAnimation { showProfileDrawer = true }
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("聊天")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Chat")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                // A spacer to balance the left button and keep the title centered
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .foregroundColor(.clear)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            .background(Color.white)
            
            Divider()
                    // 聊天消息区
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message, userAvatar: userBubbleAvatar, viewModel: viewModel) { variant in
                                Task {
                                    do {
                                        let navSession = try await APIClient.shared.createNavigationSession(routeVariantId: variant.id)
                                        await MainActor.run {
                                            sharedMapState.pendingNavigationSession = navSession
                                            sharedMapState.pendingWalkLegPlaceNames = nil
                                        }
                                    } catch {
                                        await MainActor.run {
                                            sharedMapState.pendingNavigationSession = nil
                                            sharedMapState.pendingWalkLegPlaceNames = Self.walkPlaceNameChain(from: variant)
                                        }
                                    }
                                    await MainActor.run {
                                        let samples = Array(variant.scenicSpotExamples.prefix(3)).joined(separator: "、")
                                        self.routeToShow = "\(variant.displayLabel)：\(variant.startLabel) → \(variant.endLabel)\(samples.isEmpty ? "" : "（途经：\(samples)）")\n\(variant.description)"
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                            self.isChatMinimized = true
                                            self.showChat = false
                                        }
                                    }
                                }
                            }
                            .id(message.id)
                            .environment(\.fontSize, settings.fontSize)
                            .environment(\.language, settings.language)
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGray6))
                .frame(maxHeight: mapHeight > 0 ? UIScreen.main.bounds.height * 0.5 : .infinity)
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let lastMessage = viewModel.messages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    // 监听流式输出时的自动滚动
                    NotificationCenter.default.addObserver(forName: NSNotification.Name("StreamScrollToBottom"), object: nil, queue: .main) { notification in
                        if let id = notification.object as? String {
                            withAnimation {
                                proxy.scrollTo(id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
                    // "回到地图"按钮
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            routeToShow = "推荐路线" // 设置默认路线信息
                            isChatMinimized = true
                            showChat = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "map")
                            Text("回到地图")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .shadow(radius: 2)
                    }
                    .padding(.top, 8)
                    // 输入区
            HStack(spacing: 16) {
                Button(action: {
                    showPhotoActionSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .actionSheet(isPresented: $showPhotoActionSheet) {
                    ActionSheet(title: Text("选择操作"), buttons: [
                        .default(Text("拍照")) {
                            imagePickerSource = .camera
                            showImagePicker = true
                        },
                        .default(Text("AR 识别")) {
                            // 打开 AR 识别入口
                            let vc = UIHostingController(rootView: ARBuildingInfoView())
                            UIApplication.shared.windows.first?.rootViewController?.present(vc, animated: true)
                        },
                        .default(Text("从相册选择")) {
                            imagePickerSource = .photoLibrary
                            showImagePicker = true
                        },
                        .cancel()
                    ])
                }

                // 自定义输入框
                HStack {
                    TextField(settings.language == "简体中文" ? "发送消息..." : "Send message...", text: $viewModel.inputText, onCommit: {
                        viewModel.sendMessage()
                        isInputFocused = false // 发送后失去焦点
                    })
                    .font(.system(size: settings.fontSize))
                    .padding(.leading, 12)
                    .frame(height: 40)
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    
                    Button(action: {
                        viewModel.sendMessage()
                        isInputFocused = false // 发送后失去焦点
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(viewModel.inputText.isEmpty ? Color.gray.opacity(0.5) : Color.blue)
                    }
                    .disabled(viewModel.inputText.isEmpty || viewModel.isLoading)
                    .padding(.trailing, 4)
                }
                .background(Color(.systemGray6))
                .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.systemGray5)),
                alignment: .top
            )
                    .sheet(isPresented: $showImagePicker) {
                        ImagePicker(sourceType: imagePickerSource) { image in
                            if let image = image, let data = image.jpegData(compressionQuality: 0.8) {
                                viewModel.sendImageMessage(data: data)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .cornerRadius(isChatMinimized ? UIScreen.main.bounds.width / 2 : 0)
                .scaleEffect(isChatMinimized ? 0.14 : 1, anchor: .bottomTrailing)
                .offset(x: isChatMinimized ? UIScreen.main.bounds.width * 0.38 + dragOffset.width : dragOffset.width, y: isChatMinimized ? UIScreen.main.bounds.height * 0.38 + dragOffset.height : dragOffset.height)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isChatMinimized)
                .gesture(
                    isChatMinimized ?
                    DragGesture()
                        .onChanged { value in
                            let minY: CGFloat = 44 // 顶部安全区
                            let maxY: CGFloat = UIScreen.main.bounds.height - 48 - 48 // tab栏高度+圆圈高度
                            let newY = value.translation.height + dragOffset.height
                            if newY >= minY && newY <= maxY {
                                dragOffset = CGSize(width: value.translation.width, height: value.translation.height)
                            }
                        }
                        .onEnded { value in
                            dragOffset = CGSize(width: dragOffset.width + value.translation.width, height: dragOffset.height)
                        }
                    : nil
                )
                .onTapGesture {
                    if isChatMinimized {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isChatMinimized = false
                            showChat = true
                            routeToShow = nil // 返回聊天时，重置路线信息
                        }
                    }
                }
            }
        }
        .onAppear {
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ChatHistoryCleared"),
                object: nil,
                queue: .main
            ) { _ in
                viewModel.messages.removeAll()
            }
            Task {
                await viewModel.bootstrapConversation()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let lastMessage = viewModel.messages.last {
                    NotificationCenter.default.post(name: NSNotification.Name("ScrollToBottom"), object: lastMessage.id)
                }
            }
        }
    }
}
