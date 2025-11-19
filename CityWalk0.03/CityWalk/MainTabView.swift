import SwiftUI
import MapKit

// 地图状态共享对象，负责全局地图摄像头位置同步
class SharedMapState: ObservableObject {
    @Published var cameraPosition: MapCameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
}

// 主Tab视图，包含底部导航栏和各主页面
struct MainTabView: View {
    @Binding var selectedTab: Int // 当前选中的Tab索引
    @StateObject private var sharedMapState = SharedMapState() // 地图状态共享对象
    @StateObject private var messageViewModel = MessageViewModel() // 全局聊天数据模型
    private let tabBarHeight: CGFloat = 68 // 增加底部Tab栏高度
    
    // 主体视图，渲染Tab内容和底部导航栏
    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case 0:
                    // 社区页面
                    CommunityView()
                        .padding(.bottom, tabBarHeight)
                case 1:
                    // 聊天页面
                    MessageView(sharedMapState: sharedMapState)
                        .environmentObject(messageViewModel)
                        .padding(.bottom, tabBarHeight)
                case 2:
                    // 我的页面
                    TripView()
                        .padding(.bottom, tabBarHeight)
                default:
                    CommunityView()
                        .padding(.bottom, tabBarHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 底部Tab栏
            HStack {
                TabBarButton(title: "社区", systemImage: "person.3", selected: selectedTab == 0) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = 0 }
                }
                Spacer()
                TabBarButton(title: "新的旅程", systemImage: "bubble.left.and.bubble.right", selected: selectedTab == 1) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = 1 }
                }
                    Spacer()
                TabBarButton(title: "我的", systemImage: "suitcase", selected: selectedTab == 2) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = 2 }
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 12)
            .frame(height: tabBarHeight)
            .background(
                Color(.systemBackground)
                    .clipShape(RoundedCorner(radius: 20, corners: [.topLeft, .topRight]))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: -4)
                    .ignoresSafeArea(.all, edges: .bottom)
            )
        }
    }
}

// 底部按钮样式组件
struct TabBarButton: View {
    let title: String
    let systemImage: String
    let selected: Bool
    let action: () -> Void
    // 渲染单个Tab按钮
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .regular))
                    .symbolVariant(selected ? .fill : .none)
                    .scaleEffect(selected ? 1.05 : 1.0)
                    .foregroundColor(selected ? .blue : .gray.opacity(0.8))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(selected ? .blue : .gray.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}


// 我的页面占位视图
struct MyPageView: View {
    var body: some View {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
    }
}

// 引入新社区页面UI
// CommunityView 已在 Views 文件夹单独实现 