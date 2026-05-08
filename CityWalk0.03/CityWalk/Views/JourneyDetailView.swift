import SwiftUI

// MARK: - Models（与原型 JourneyDetail.tsx 数据结构一致）

private struct JourneyParticipant: Hashable {
    let name: String
}

private struct JourneyActivity: Hashable {
    let time: String
    let title: String
    let location: String
}

private struct JourneyDayPlan: Hashable {
    let day: String
    let date: String
    let activities: [JourneyActivity]
}

private struct JourneyPhoto: Hashable {
    let url: String
    let likes: Int
}

private struct JourneyNote: Hashable {
    let title: String
    let content: String
    let time: String
}

private struct JourneyDetailPayload: Hashable {
    let title: String
    let dates: String
    let location: String
    let coverImage: String
    let description: String
    let participants: [JourneyParticipant]
    let itinerary: [JourneyDayPlan]
    let photos: [JourneyPhoto]
    let notes: [JourneyNote]
}

// MARK: - 静态数据（由 JourneyDetail.tsx 逐条迁移）

private enum JourneyDetailStore {
    static let all: [String: JourneyDetailPayload] = [
        "1": .init(
            title: "苏州园林 3日游",
            dates: "2026年5月1日 - 5月3日",
            location: "江苏省苏州市",
            coverImage: "https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=800&h=400&fit=crop",
            description: "探索苏州古典园林的魅力，感受江南水乡的诗意。本次行程将游览拙政园、留园、虎丘等著名景点，品尝地道的苏州美食。",
            participants: [
                .init(name: "张伟"),
                .init(name: "李娜"),
                .init(name: "王强"),
            ],
            itinerary: [
                .init(day: "Day 1", date: "5月1日", activities: [
                    .init(time: "09:00", title: "抵达苏州", location: "苏州站"),
                    .init(time: "10:30", title: "游览拙政园", location: "拙政园"),
                    .init(time: "14:00", title: "午餐", location: "得月楼"),
                    .init(time: "15:30", title: "游览苏州博物馆", location: "苏州博物馆"),
                    .init(time: "18:00", title: "晚餐 & 平江路夜游", location: "平江路"),
                ]),
                .init(day: "Day 2", date: "5月2日", activities: [
                    .init(time: "09:00", title: "游览留园", location: "留园"),
                    .init(time: "12:00", title: "午餐", location: "松鹤楼"),
                    .init(time: "14:00", title: "游览虎丘", location: "虎丘风景区"),
                    .init(time: "17:00", title: "山塘街漫步", location: "山塘街"),
                ]),
                .init(day: "Day 3", date: "5月3日", activities: [
                    .init(time: "09:00", title: "游览狮子林", location: "狮子林"),
                    .init(time: "11:30", title: "观前街购物", location: "观前街"),
                    .init(time: "14:00", title: "返程", location: "苏州站"),
                ]),
            ],
            photos: [
                .init(url: "https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=400&h=300&fit=crop", likes: 45),
                .init(url: "https://images.unsplash.com/photo-1580837119756-563d608dd119?w=400&h=300&fit=crop", likes: 32),
                .init(url: "https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=400&h=300&fit=crop", likes: 28),
                .init(url: "https://images.unsplash.com/photo-1559628376-f3fe5f782a2e?w=400&h=300&fit=crop", likes: 51),
            ],
            notes: [
                .init(title: "拙政园游览笔记", content: "园林设计精妙，移步换景。建议预留2-3小时游览时间。", time: "5月1日 11:30"),
                .init(title: "美食推荐", content: "得月楼的松鼠桂鱼和响油鳝糊值得一试！", time: "5月1日 14:45"),
            ]
        ),
        "2": .init(
            title: "杭州西湖 2日游",
            dates: "2026年4月15日 - 4月16日",
            location: "浙江省杭州市",
            coverImage: "https://images.unsplash.com/photo-1545893835-abaa50cbe628?w=800&h=400&fit=crop",
            description: "漫步西湖，感受杭州的诗情画意。游览雷峰塔、灵隐寺等著名景点，品尝龙井茶和杭州特色美食。",
            participants: [.init(name: "陈明"), .init(name: "刘芳")],
            itinerary: [
                .init(day: "Day 1", date: "4月15日", activities: [
                    .init(time: "09:00", title: "西湖游船", location: "西湖"),
                    .init(time: "11:00", title: "雷峰塔", location: "雷峰塔"),
                    .init(time: "14:00", title: "午餐", location: "楼外楼"),
                    .init(time: "15:30", title: "灵隐寺", location: "灵隐寺"),
                ]),
                .init(day: "Day 2", date: "4月16日", activities: [
                    .init(time: "08:00", title: "龙井村品茶", location: "龙井村"),
                    .init(time: "11:00", title: "南宋御街", location: "南宋御街"),
                    .init(time: "14:00", title: "返程", location: "杭州东站"),
                ]),
            ],
            photos: [
                .init(url: "https://images.unsplash.com/photo-1545893835-abaa50cbe628?w=400&h=300&fit=crop", likes: 67),
                .init(url: "https://images.unsplash.com/photo-1591948582167-cf92194c4454?w=400&h=300&fit=crop", likes: 43),
            ],
            notes: [.init(title: "西湖美景", content: "四月的西湖美不胜收，桃花盛开。", time: "4月15日 10:00")]
        ),
        "3": .init(
            title: "北京故宫 1日游",
            dates: "2026年5月7日",
            location: "北京市东城区",
            coverImage: "https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=800&h=400&fit=crop",
            description: "探访紫禁城，感受中华文化的博大精深。游览故宫博物院，欣赏古代建筑艺术的瑰宝。",
            participants: [.init(name: "王磊")],
            itinerary: [
                .init(day: "Day 1", date: "5月7日", activities: [
                    .init(time: "08:30", title: "抵达故宫", location: "午门"),
                    .init(time: "09:00", title: "太和殿参观", location: "太和殿"),
                    .init(time: "11:00", title: "珍宝馆", location: "珍宝馆"),
                    .init(time: "13:00", title: "午餐", location: "故宫餐厅"),
                    .init(time: "14:30", title: "御花园", location: "御花园"),
                    .init(time: "16:00", title: "离开故宫", location: "神武门"),
                ]),
            ],
            photos: [.init(url: "https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=400&h=300&fit=crop", likes: 89)],
            notes: [.init(title: "参观提示", content: "建议提前网上预约门票，避免排队等候。", time: "5月7日 08:00")]
        ),
        "4": .init(
            title: "上海外滩 2日游",
            dates: "2026年5月20日 - 5月21日",
            location: "上海市黄浦区",
            coverImage: "https://images.unsplash.com/photo-1537981576259-a1a7d4d06a5f?w=800&h=400&fit=crop",
            description: "感受魔都的繁华与魅力，漫步外滩，欣赏浦江两岸的美景，品味上海的独特韵味。",
            participants: [.init(name: "赵丽"), .init(name: "孙军"), .init(name: "周芳"), .init(name: "吴强")],
            itinerary: [
                .init(day: "Day 1", date: "5月20日", activities: [
                    .init(time: "10:00", title: "外滩漫步", location: "外滩"),
                    .init(time: "12:00", title: "南京路购物", location: "南京路步行街"),
                    .init(time: "14:00", title: "午餐", location: "老上海菜馆"),
                    .init(time: "16:00", title: "豫园游览", location: "豫园"),
                    .init(time: "19:00", title: "浦东夜景", location: "东方明珠"),
                ]),
                .init(day: "Day 2", date: "5月21日", activities: [
                    .init(time: "09:00", title: "田子坊", location: "田子坊"),
                    .init(time: "12:00", title: "新天地", location: "新天地"),
                    .init(time: "15:00", title: "返程", location: "上海虹桥站"),
                ]),
            ],
            photos: [
                .init(url: "https://images.unsplash.com/photo-1537981576259-a1a7d4d06a5f?w=400&h=300&fit=crop", likes: 124),
                .init(url: "https://images.unsplash.com/photo-1548919973-5cef591cdbc9?w=400&h=300&fit=crop", likes: 98),
            ],
            notes: [.init(title: "外滩夜景", content: "晚上的外滩灯火辉煌，非常适合拍照。", time: "5月20日 20:00")]
        ),
    ]

    static func payload(for journeyId: String) -> JourneyDetailPayload? {
        all[journeyId]
    }
}

// MARK: - View

struct JourneyDetailView: View {
    /// 返回按钮在安全区之下的额外间距。**调「历史行程详情」顶栏返回键上边距主要改这里。**
    private let journeyDetailBackButtonExtraBelowSafeArea: CGFloat = 28
    /// 当 `ScrollView` 使用 `ignoresSafeArea(.top)` 时，`GeometryReader.safeAreaInsets.top` 可能为 0，用此值垫出状态栏/灵动岛高度。
    private let journeyDetailBackButtonTopFallback: CGFloat = 50

    let journeyId: String
    var onDismiss: () -> Void

    private var journey: JourneyDetailPayload? {
        JourneyDetailStore.payload(for: journeyId)
    }

    var body: some View {
        Group {
            if let journey {
                journeyContent(journey)
            } else {
                Text("未找到旅程")
                    .foregroundStyle(CampusWalkUITheme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
            }
        }
    }

    @ViewBuilder
    private func journeyContent(_ journey: JourneyDetailPayload) -> some View {
        ScrollView {
            GeometryReader { geo in
                let backTop = journeyDetailBackButtonTopInset(safeTop: geo.safeAreaInsets.top)

                ZStack(alignment: .topLeading) {
                    AsyncImage(url: URL(string: journey.coverImage)) { phase in
                        switch phase {
                        case .empty:
                            Color.gray.opacity(0.2).frame(height: 288)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 288)
                                .clipped()
                        case .failure:
                            Color.gray.opacity(0.25)
                                .frame(height: 288)
                                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                        @unknown default:
                            EmptyView()
                        }
                    }

                    LinearGradient(
                        colors: [.black.opacity(0.5), .clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 288)
                    .allowsHitTesting(false)

                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.33))
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(CampusWalkUITheme.cardStroke, lineWidth: 1))
                    }
                    .padding(.top, backTop)
                    .padding(.leading, 16)

                    VStack(alignment: .leading, spacing: 12) {
                        Spacer()
                        Text(journey.title)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                        HStack(spacing: 16) {
                            Label(journey.dates, systemImage: "calendar")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.95))
                            Label(journey.location, systemImage: "mappin.and.ellipse")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.95))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, minHeight: 288, alignment: .bottomLeading)
                }
                .frame(width: geo.size.width, height: 288, alignment: .top)
            }
            .frame(height: 288)

            VStack(alignment: .leading, spacing: 32) {
                participantsSection(journey)
                descriptionSection(journey)
                itinerarySection(journey)
                photosSection(journey)
                notesSection(journey)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .background(Color.white)
        .ignoresSafeArea(edges: .top)
    }

    private func journeyDetailBackButtonTopInset(safeTop: CGFloat) -> CGFloat {
        let base = safeTop > 1 ? safeTop : journeyDetailBackButtonTopFallback
        return base + journeyDetailBackButtonExtraBelowSafeArea
    }

    private func participantsSection(_ journey: JourneyDetailPayload) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("参与者 (\(journey.participants.count))", systemImage: "person.2")
                .font(.system(size: 13))
                .foregroundStyle(CampusWalkUITheme.sectionTitle)
            HStack(spacing: 16) {
                ForEach(Array(journey.participants.enumerated()), id: \.offset) { _, p in
                    VStack(spacing: 8) {
                        Text(String(p.name.prefix(1)))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(CampusWalkUITheme.brandBlue)
                            .clipShape(Circle())
                        Text(p.name)
                            .font(.system(size: 12))
                            .foregroundStyle(CampusWalkUITheme.textSecondary)
                    }
                }
            }
        }
    }

    private func descriptionSection(_ journey: JourneyDetailPayload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("行程简介")
                .font(.system(size: 13))
                .foregroundStyle(CampusWalkUITheme.sectionTitle)
            Text(journey.description)
                .font(.system(size: 14))
                .foregroundStyle(CampusWalkUITheme.textSecondary)
                .lineSpacing(4)
        }
    }

    private func itinerarySection(_ journey: JourneyDetailPayload) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("详细行程", systemImage: "map")
                .font(.system(size: 13))
                .foregroundStyle(CampusWalkUITheme.sectionTitle)

            ForEach(Array(journey.itinerary.enumerated()), id: \.offset) { _, day in
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Text(day.day)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(CampusWalkUITheme.brandBlue)
                            .clipShape(RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerPill, style: .continuous))
                        Text(day.date)
                            .font(.system(size: 12))
                            .foregroundStyle(CampusWalkUITheme.textMuted)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(day.activities.enumerated()), id: \.offset) { _, act in
                            HStack(alignment: .top, spacing: 0) {
                                ZStack {
                                    Circle()
                                        .fill(CampusWalkUITheme.brandBlue)
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 6)
                                }
                                .frame(width: 20)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(act.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.33))
                                    HStack(spacing: 6) {
                                        Text(act.time)
                                        Text("·")
                                        Text(act.location)
                                    }
                                    .font(.system(size: 12))
                                    .foregroundStyle(CampusWalkUITheme.textMuted)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(CampusWalkUITheme.surfaceGray50)
                                .clipShape(RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerCard, style: .continuous))
                            }
                            .padding(.leading, 4)
                        }
                    }
                }
            }
        }
    }

    private func photosSection(_ journey: JourneyDetailPayload) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("照片回忆 (\(journey.photos.count))", systemImage: "camera")
                .font(.system(size: 13))
                .foregroundStyle(CampusWalkUITheme.sectionTitle)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Array(journey.photos.enumerated()), id: \.offset) { _, photo in
                    ZStack(alignment: .bottomTrailing) {
                        AsyncImage(url: URL(string: photo.url)) { phase in
                            switch phase {
                            case .empty:
                                Color.gray.opacity(0.15)
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure:
                                Color.gray.opacity(0.2)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(height: 176)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerCard, style: .continuous))

                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(CampusWalkUITheme.brandBlue)
                            Text("\(photo.likes)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(CampusWalkUITheme.textSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(8)
                    }
                }
            }
        }
    }

    private func notesSection(_ journey: JourneyDetailPayload) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("行程笔记 (\(journey.notes.count))", systemImage: "doc.text")
                .font(.system(size: 13))
                .foregroundStyle(CampusWalkUITheme.sectionTitle)

            VStack(spacing: 12) {
                ForEach(Array(journey.notes.enumerated()), id: \.offset) { _, note in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(note.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.33))
                        Text(note.content)
                            .font(.system(size: 14))
                            .foregroundStyle(CampusWalkUITheme.textSecondary)
                            .lineSpacing(4)
                        Text(note.time)
                            .font(.system(size: 12))
                            .foregroundStyle(CampusWalkUITheme.textMuted)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CampusWalkUITheme.brandBlueMutedBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerCard, style: .continuous)
                            .stroke(CampusWalkUITheme.brandBlueBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerCard, style: .continuous))
                }
            }
        }
        .padding(.bottom, 24)
    }
}

#Preview {
    JourneyDetailView(journeyId: "1", onDismiss: {})
}
