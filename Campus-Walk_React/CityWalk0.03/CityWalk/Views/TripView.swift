import SwiftUI
import CoreLocation

// MARK: - 行程模型（与 JourneyPage / JourneyDetail 原型数据对齐）

struct Trip: Identifiable, Hashable {
    let id: String
    let title: String
    let datesLabel: String
    let locationsLabel: String
    let startDate: Date
    let endDate: Date
    let participantCount: Int
    /// 对应 `JourneyDetailView` 的静态数据 id；`nil` 则无详情全屏页
    let detailId: String?
    let coverImageURL: String?
    let assetImageName: String?

    private static let cal = Calendar.current

    static func makeDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d)) ?? Date()
    }
}

private struct JourneyDetailSheetPayload: Identifiable {
    var id: String { journeyId }
    let journeyId: String
}

// MARK: - 我的旅程（Trip / Journey 列表 + 日历）

struct TripView: View {
    @State private var calendarYear: Int
    @State private var calendarMonth: Int
    @State private var selectedCalendarDay: Int?

    @State private var showProfileDrawer = false

    @State private var showStats: Bool = false
    @State private var statsRouteCoordinates: [CLLocationCoordinate2D] = []
    @State private var statsDuration: TimeInterval = 3600
    @State private var statsDistance: Double = 5.2
    @State private var statsCalories: Double = 320

    @State private var journeyDetailPayload: JourneyDetailSheetPayload?

    private let cal = Calendar.current

    private var allTrips: [Trip] {
        [
            Trip(
                id: "jp",
                title: "日本历史8天行程",
                datesLabel: "8天7晚",
                locationsLabel: "30个地点",
                startDate: Trip.makeDate(2026, 5, 6),
                endDate: Trip.makeDate(2026, 5, 13),
                participantCount: 1,
                detailId: nil,
                coverImageURL: nil,
                assetImageName: "Japan"
            ),
            Trip(
                id: "1",
                title: "苏州园林 3日游",
                datesLabel: "5月1日 - 5月3日, 2026",
                locationsLabel: "9个地点",
                startDate: Trip.makeDate(2026, 5, 1),
                endDate: Trip.makeDate(2026, 5, 3),
                participantCount: 3,
                detailId: "1",
                coverImageURL: "https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=400&h=200&fit=crop",
                assetImageName: "SuzhouGarden"
            ),
            Trip(
                id: "2",
                title: "杭州西湖 2日游",
                datesLabel: "4月15日 - 4月16日, 2026",
                locationsLabel: "8个地点",
                startDate: Trip.makeDate(2026, 4, 15),
                endDate: Trip.makeDate(2026, 4, 16),
                participantCount: 2,
                detailId: "2",
                coverImageURL: "https://images.unsplash.com/photo-1545893835-abaa50cbe628?w=400&h=200&fit=crop",
                assetImageName: "HangzhouWestlake"
            ),
            Trip(
                id: "3",
                title: "北京故宫 1日游",
                datesLabel: "5月7日, 2026",
                locationsLabel: "6个地点",
                startDate: Trip.makeDate(2026, 5, 7),
                endDate: Trip.makeDate(2026, 5, 7),
                participantCount: 1,
                detailId: "3",
                coverImageURL: "https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=400&h=200&fit=crop",
                assetImageName: nil
            ),
            Trip(
                id: "4",
                title: "上海外滩 2日游",
                datesLabel: "5月20日 - 5月21日, 2026",
                locationsLabel: "10个地点",
                startDate: Trip.makeDate(2026, 5, 20),
                endDate: Trip.makeDate(2026, 5, 21),
                participantCount: 4,
                detailId: "4",
                coverImageURL: "https://images.unsplash.com/photo-1537981576259-a1a7d4d06a5f?w=400&h=200&fit=crop",
                assetImageName: nil
            ),
        ]
    }

    private var occupiedDaysInVisibleMonth: [Int] {
        var set = Set<Int>()
        var c = DateComponents()
        c.year = calendarYear
        c.month = calendarMonth
        c.day = 1
        guard let monthStart = cal.date(from: c),
              let dayRange = cal.range(of: .day, in: .month, for: monthStart) else { return [] }

        for day in dayRange {
            c.day = day
            guard let dayDate = cal.date(from: c) else { continue }
            let dayStart = cal.startOfDay(for: dayDate)
            for trip in allTrips {
                let s = cal.startOfDay(for: trip.startDate)
                let e = cal.startOfDay(for: trip.endDate)
                if dayStart >= s, dayStart <= e {
                    set.insert(day)
                    break
                }
            }
        }
        return set.sorted()
    }

    private var filteredTrips: [Trip] {
        guard let day = selectedCalendarDay else {
            return allTrips.sorted { $0.startDate > $1.startDate }
        }
        var c = DateComponents()
        c.year = calendarYear
        c.month = calendarMonth
        c.day = day
        guard let tapped = cal.date(from: c) else {
            return allTrips.sorted { $0.startDate > $1.startDate }
        }
        let t0 = cal.startOfDay(for: tapped)
        return allTrips.filter { trip in
            let s = cal.startOfDay(for: trip.startDate)
            let e = cal.startOfDay(for: trip.endDate)
            return t0 >= s && t0 <= e
        }
        .sorted { $0.startDate > $1.startDate }
    }

    private var filterSectionTitle: String {
        guard let day = selectedCalendarDay else { return "所有行程" }
        return "\(calendarMonth)月\(day)日的行程"
    }

    init() {
        let y = Calendar.current.component(.year, from: Date())
        let m = Calendar.current.component(.month, from: Date())
        _calendarYear = State(initialValue: y)
        _calendarMonth = State(initialValue: m)
        _selectedCalendarDay = State(initialValue: nil)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white.ignoresSafeArea()

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
                HStack {
                    Button {
                        withAnimation { showProfileDrawer = true }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(Color(red: 0.45, green: 0.48, blue: 0.52))
                    }
                    Spacer()
                    Text("我的旅程")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.33))
                    Spacer()
                    Color.clear.frame(width: 28, height: 28)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)

                Rectangle()
                    .fill(CampusWalkUITheme.borderSubtle)
                    .frame(height: 1)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("日历视图")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.33))

                            CityWalkCalendarView(
                                year: $calendarYear,
                                month: $calendarMonth,
                                selectedFilterDay: $selectedCalendarDay,
                                occupiedDaysInMonth: occupiedDaysInVisibleMonth
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)

                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(filterSectionTitle)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.33))
                                Spacer()
                                if selectedCalendarDay != nil {
                                    Button("查看全部") {
                                        selectedCalendarDay = nil
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(CampusWalkUITheme.brandBlue)
                                }
                            }

                            if filteredTrips.isEmpty {
                                Text("该日期没有行程")
                                    .font(.system(size: 14))
                                    .foregroundStyle(CampusWalkUITheme.textMuted)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 48)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(filteredTrips) { trip in
                                        JourneyListRowView(trip: trip) {
                                            statsRouteCoordinates = []
                                            statsDuration = 3600
                                            statsDistance = 5.2
                                            statsCalories = 320
                                            showStats = true
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            if let did = trip.detailId {
                                                journeyDetailPayload = JourneyDetailSheetPayload(journeyId: did)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 120)
                    }
                }
            }
        }
        .fullScreenCover(item: $journeyDetailPayload) { payload in
            JourneyDetailView(journeyId: payload.journeyId) {
                journeyDetailPayload = nil
            }
        }
        .sheet(isPresented: $showStats) {
            TripStatsView(routeCoordinates: statsRouteCoordinates, duration: statsDuration, distance: statsDistance, calories: statsCalories)
        }
    }
}

// MARK: - 行程列表行（对齐 JourneyPage 卡片）

private struct JourneyListRowView: View {
    let trip: Trip
    var onStats: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            tripThumbnail
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerCard, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(trip.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.15))
                    .lineLimit(2)

                Text(trip.datesLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(CampusWalkUITheme.textMuted)

                Spacer(minLength: 4)

                HStack {
                    participantStack
                    Spacer()
                    HStack(spacing: 4) {
                        Button(action: onStats) {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 15))
                                .foregroundStyle(CampusWalkUITheme.brandBlue)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        Button(action: {}) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15))
                                .foregroundStyle(CampusWalkUITheme.textMuted)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerCard, style: .continuous)
                .stroke(CampusWalkUITheme.borderSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var tripThumbnail: some View {
        if let urlStr = trip.coverImageURL, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Color.gray.opacity(0.12)
                case .success(let img):
                    img.resizable().scaledToFill()
                case .failure:
                    assetOrPlaceholder
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            assetOrPlaceholder
        }
    }

    @ViewBuilder
    private var assetOrPlaceholder: some View {
        if let name = trip.assetImageName, UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFill()
        } else {
            Color.gray.opacity(0.12)
                .overlay(Image(systemName: "photo").foregroundStyle(.tertiary))
        }
    }

    private var participantStack: some View {
        let shown = min(trip.participantCount, 3)
        return HStack(spacing: -6) {
            ForEach(0..<shown, id: \.self) { _ in
                Circle()
                    .fill(CampusWalkUITheme.brandBlue)
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
            }
            if trip.participantCount > 3 {
                Text("+\(trip.participantCount - 3)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(red: 0.45, green: 0.48, blue: 0.52))
                    .frame(width: 20, height: 20)
                    .background(Color(red: 0.90, green: 0.91, blue: 0.92))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
            }
        }
    }
}

// 复合详情页：上地图下详情（保留供其他入口使用）
struct RouteFullDetailView: View {
    @State private var selectedPlaceIndex: Int = 0

    let route: Route

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                AMapViewRepresentable(startCoordinate: nil, destination: nil, showSearchBar: false)
                    .frame(height: geometry.size.height * 0.4)
                    .clipped()

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
