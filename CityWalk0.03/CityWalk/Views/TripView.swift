import SwiftUI
import CoreLocation

struct Trip: Identifiable {
    let id = UUID()
    let title: String
    let days: String
    let locations: String
    let image: Image?
    let avatar: Image?
    let date: Date
}

struct TripView: View {
    // 示例数据
    @State private var currentTrip = Trip(title: "日本历史8天行程", days: "8天7晚", locations: "30个地点", image: Image("Japan"), avatar: Image("avatar_sample"), date: Date())
    @State private var historyTrips: [Trip] = [
        Trip(title: "苏州园林3日游", days: "3天2晚", locations: "9个地点", image: Image("SuzhouGarden"), avatar: nil, date: Date().addingTimeInterval(-86400*10)),
        Trip(title: "杭州西湖2日游", days: "2天1晚", locations: "8个地点", image: Image("HangzhouWestlake"), avatar: nil, date: Date().addingTimeInterval(-86400*20))
    ]

    // 新增状态变量
    @State private var showUserProfile = false // 是否显示用户资料页
    @State private var showSettings = false // 是否显示设置页
    @State private var showProfileDrawer = false // 控制侧边抽屉
    @StateObject private var settings = SettingsManager.shared // 设置管理器
    @State private var selectedRoute: Route? = nil
    @State private var showStats: Bool = false
    @State private var statsRouteCoordinates: [CLLocationCoordinate2D] = []
    @State private var statsDuration: TimeInterval = 3600
    @State private var statsDistance: Double = 5.2
    @State private var statsCalories: Double = 320

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 背景渐变 - 更现代的配色
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.92, green: 0.95, blue: 1.0),
                    Color(red: 0.96, green: 0.98, blue: 1.0),
                    Color.white
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // 装饰性背景元素
            VStack {
                HStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 200, height: 200)
                        .offset(x: -100, y: -50)
                    Spacer()
                }
                Spacer()
            }
            .ignoresSafeArea()

            // 侧边抽屉
            if showProfileDrawer {
                HStack(spacing: 0) {
                    UserProfileView(isShowingProfile: $showProfileDrawer)
                        .frame(width: UIScreen.main.bounds.width * 0.7)
                        .background(Color(.systemBackground))
                        .ignoresSafeArea(edges: .top)
                        .transition(.move(edge: .leading))
                    Spacer(minLength: 0)
                }
                .background(
                    Color.black.opacity(0.18)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation { showProfileDrawer = false }
                        }
                )
                .ignoresSafeArea()
                .zIndex(2)
            }

            VStack(spacing: 0) {
                // 顶部栏 - 参考CommunityView设计
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
                        Text("我的旅程")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Journey")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    .sheet(isPresented: $showSettings) {
                        SettingsView(isShowingSettings: $showSettings)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(Color.white)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("日历视图")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 24)
                                .padding(.top, 36)
                                // 日历视图
                                CityWalkCalendarView(
                                    year: 2025,
                                    month: 7,
                                    historyDays: [2,3,4,5], // mock: 这些天有CityWalk
                                    selectedDay: 5 // mock: 当前高亮
                                )    
                        }
                        // 历史行程
                        VStack(alignment: .leading, spacing: 20) {
                            Text("历史行程")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 24)
                                .padding(.top, 8)

                            VStack(spacing: 24) {
                                ForEach(historyTrips.sorted(by: { $0.date > $1.date })) { trip in
                                    TripCardView(trip: trip, isCurrent: false, onStats: {
                                        // 这里用mock数据，实际可根据trip生成
                                        statsRouteCoordinates = []
                                        statsDuration = 3600
                                        statsDistance = 5.2
                                        statsCalories = 320
                                        showStats = true
                                    })
                                    .onTapGesture {
                                        selectedRoute = RouteDetailView_Previews.mockRoute
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        // 底部间距
                        Spacer(minLength: 120)
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedRoute) { route in
            RouteFullDetailView(route: route)
        }
        .sheet(isPresented: $showStats) {
            TripStatsView(routeCoordinates: statsRouteCoordinates, duration: statsDuration, distance: statsDistance, calories: statsCalories)
        }
    }
}

struct TripCardView: View {
    let trip: Trip
    let isCurrent: Bool
    var onStats: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 主卡片背景
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: isCurrent ?
                            [Color(red: 0.2, green: 0.6, blue: 1.0), Color(red: 0.1, green: 0.4, blue: 0.9)] :
                            [Color.white, Color(red: 0.98, green: 0.98, blue: 0.98)]
                        ),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: isCurrent ? Color.blue.opacity(0.25) : Color.black.opacity(0.08),
                       radius: isCurrent ? 16 : 12, x: 0, y: isCurrent ? 8 : 6)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(trip.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(isCurrent ? .white : .primary)
                            .lineLimit(2)

                        HStack(spacing: 20) {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14))
                                    .foregroundColor(isCurrent ? .white.opacity(0.8) : .gray)
                                Text(trip.days)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(isCurrent ? .white.opacity(0.9) : .gray)
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 14))
                                    .foregroundColor(isCurrent ? .white.opacity(0.8) : .gray)
                                Text(trip.locations)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(isCurrent ? .white.opacity(0.9) : .gray)
                            }
                        }
                    }
                    Spacer()

                    // 右上图片区域
                    if let img = trip.image {
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .onAppear {
                                // 如果图片加载失败，会显示占位符
                            }
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.2)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 100)
                            .overlay(
                                VStack(spacing: 4) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 20))
                                        .foregroundColor(.gray.opacity(0.5))
                                    Text("暂无图片")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                            )
                    }
                }

                Spacer(minLength: 0)

                // 底部操作区域
                HStack(spacing: 12) {
                    // 头像区域
                    if let avatar = trip.avatar {
                        avatar
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray)
                            )
                    }

                    Spacer()

                    // 状态指示器
                    if isCurrent {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                            Text("进行中")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
            }
            .padding(20)
            // 右下角统计和分享按钮
            if !isCurrent {
                HStack(spacing: 16) {
                    Button(action: {
                        onStats?()
                    }) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(10)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                    }
                    Button(action: {
                        // TODO: 分享操作
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(10)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .frame(height: 200)
    }
}

// 复合详情页：上地图下详情
struct RouteFullDetailView: View {
    @State private var selectedPlaceIndex: Int = 0

    let route: Route
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 上部地图区域（2/5）
                AMapViewRepresentable(routeCoordinates: nil, startCoordinate: nil, destination: nil, showSearchBar: false)
                    .frame(height: geometry.size.height * 0.4)
                    .clipped()

                // 下部详情内容（3/5）
                ZStack(alignment: .bottom) {
                    RouteDetailView(
                        route: route,
                        selectedPlaceIndex: $selectedPlaceIndex,
                        onPlaceChange: { _, _ in },
                        onSegmentChange: { _ in }
                    )
                    .frame(height: geometry.size.height * 0.6)
                    .background(Color.white)
                }
            }
            .edgesIgnoringSafeArea(.top)
        }
    }
} 