import SwiftUI
import MapKit

// 聊天主界面，包含消息列表、输入区和地图弹出逻辑
struct MessageView: View {
    @EnvironmentObject var viewModel: MessageViewModel // 聊天数据模型
    @StateObject private var settings = SettingsManager.shared // 设置管理器
    @StateObject private var userViewModel = UserViewModel()
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
    
    // 新增：地图状态共享对象
    var sharedMapState: SharedMapState? = nil
    
    // 地图高度的常量
    private let minMapHeight: CGFloat = UIScreen.main.bounds.height * 0.5
    private let maxMapHeight: CGFloat = UIScreen.main.bounds.height * 0.5
    private let defaultMapHeight: CGFloat = UIScreen.main.bounds.height * 0.5
    // 新增：用于地图和路线详情联动
    @State private var selectedPlaceIndex: Int = 0
    @State private var startCoordinate: CLLocationCoordinate2D? = nil
    @State private var destinationLocation: CLLocationCoordinate2D? = nil
    
    // 主体视图，渲染聊天界面、消息列表、地图弹窗、输入区等
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // 用户资料抽屉
            if showProfileDrawer {
                UserProfileView(isShowingProfile: $showProfileDrawer)
                    .ignoresSafeArea()
                    .transition(.move(edge: .leading))
                    .zIndex(2)
            }
            
            // 地图始终在底层
            if !showChat {
                if let sharedMapState = sharedMapState {
                    MapView(
                        isExpanded: .constant(true),
                        isShowingProfile: .constant(false),
                        sharedMapState: sharedMapState,
                        routeInfo: routeToShow,
                        destinationLocation: $destinationLocation,
                        selectedPlaceIndex: $selectedPlaceIndex,
                        startCoordinateBinding: $startCoordinate
                    )
                    .ignoresSafeArea()
                    .transition(.opacity)
                } else {
                    MapView(
                        isExpanded: .constant(true),
                        isShowingProfile: .constant(false),
                        routeInfo: routeToShow,
                        destinationLocation: $destinationLocation,
                        selectedPlaceIndex: $selectedPlaceIndex,
                        startCoordinateBinding: $startCoordinate
                    )
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
                // 右下角按钮区：回到路线详情+聊天小圆圈
                HStack(spacing: 16) {
                    Button(action: {
                        // 拉起路线详情
                        routeToShow = "推荐路线"
                        NotificationCenter.default.post(name: NSNotification.Name("ShowRouteDetailSheet"), object: nil)
                    }) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 23, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isChatMinimized = false
                            showChat = true
                            routeToShow = nil
                        }
                    }) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 23, weight: .bold))
                            .frame(width: 50, height: 50)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                }
                .padding(.trailing, 17)
                .padding(.bottom, 30)
                .frame(maxWidth: .infinity, alignment: .trailing)
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
                            MessageBubble(message: message, userAvatar: userViewModel.userAvatar, viewModel: viewModel) { option in
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    self.routeToShow = option
                                    isChatMinimized = true
                                    showChat = false
                                }
                            }
                            .id(message.id)
                            .environment(\.fontSize, settings.fontSize)
                            .environment(\.language, settings.language)
                            // 如果是推荐线路消息，展示确认按钮
                            if message.isRouteRecommendation {
                                Button(action: {
                                    // 点击确认后收缩聊天页面并显示地图
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        isChatMinimized = true
                                        showChat = false
                                    }
                                }) {
                                    Text("确认")
                                        .font(.system(size: 15, weight: .bold))
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                        .shadow(radius: 2)
                                }
                                .padding(.bottom, 8)
                            }
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
                        if let id = notification.object as? UUID {
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
                                let msg = Message(content: "[图片]", isUser: true, timestamp: Date(), imageData: data)
                                viewModel.messages.append(msg)
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
            // 监听聊天记录清除通知，收到后清空消息
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ChatHistoryCleared"),
                object: nil,
                queue: .main
            ) { _ in
                viewModel.messages.removeAll()
            }
            // 聊天页面出现时自动滚动到底部
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let lastMessage = viewModel.messages.last {
                    NotificationCenter.default.post(name: NSNotification.Name("ScrollToBottom"), object: lastMessage.id)
                }
            }
        }
    }
}
