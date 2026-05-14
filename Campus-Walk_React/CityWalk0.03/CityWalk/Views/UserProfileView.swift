import SwiftUI

/// 侧栏用户菜单（对齐原型 `SideMenu.tsx`：蓝色顶栏、白字、分组列表、底链隐私政策）
struct UserProfileView: View {
    /// 蓝色顶栏内，头像/昵称相对**屏幕物理顶部**的留白（父级对抽屉 `ignoresSafeArea(.top)` 时系统安全区为 0，需手动留出状态栏/灵动岛高度）。**改这里即可调「用户页上边距」**。
    private let sideMenuHeaderTopSpacer: CGFloat = 95
    /// 右上角关闭按钮距顶部的间距
    private let sideMenuCloseButtonTopPadding: CGFloat = 75

    @Binding var isShowingProfile: Bool
    @EnvironmentObject private var auth: AuthViewModel
    @State private var showSettingsDrawer = false
    @State private var showMainSettings = false
    @Environment(\.locale) var locale

    private var profileTitle: String {
        guard auth.isLoggedIn else { return NSLocalizedString("请登录", comment: "") }
        if let n = auth.user?.nickname, !n.isEmpty { return n }
        return auth.user?.email ?? "已登录"
    }

    private var avatarInitial: String {
        let t = profileTitle
        guard let c = t.first else { return "用" }
        return String(c)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if !showSettingsDrawer {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            blueHeader

                            VStack(alignment: .leading, spacing: 4) {
                                SideMenuRow(icon: "book", title: "联系人", action: {})
                                SideMenuRow(icon: "bell", title: "通知", action: {})
                                SideMenuRow(icon: "clock.arrow.circlepath", title: "版本历史", badge: "新", action: {})
                                SideMenuRow(icon: "person.2", title: "联系我们", action: {})
                                SideMenuRow(
                                    icon: "person.badge.plus",
                                    title: "添加团队成员",
                                    subtitle: "成员可以加入并管理...",
                                    action: {}
                                )
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 24)

                            Rectangle()
                                .fill(CampusWalkUITheme.borderSubtle)
                                .frame(height: 1)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)

                            VStack(alignment: .leading, spacing: 4) {
                                SideMenuRow(icon: "gearshape", title: "设置") {
                                    showMainSettings = true
                                }
                                SideMenuRow(icon: "info.circle", title: "关于App", action: {})
                                SideMenuRow(icon: "star", title: "我的收藏", action: {})
                                SideMenuRow(icon: "doc.text", title: "我的文档", action: {})
                                SideMenuRow(icon: "creditcard", title: "支付与订单", action: {})
                                SideMenuRow(icon: "questionmark.circle", title: "帮助与反馈", action: {})
                            }
                            .padding(.horizontal, 16)

                            Rectangle()
                                .fill(CampusWalkUITheme.borderSubtle)
                                .frame(height: 1)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)

                            Button(action: {}) {
                                Text("隐私政策")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(CampusWalkUITheme.brandBlue)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 32)
                        }
                        .frame(minHeight: geometry.size.height, alignment: .top)
                        .background(Color.white)
                    }
                    .transition(.opacity)
                }

                if showSettingsDrawer {
                    SettingsDrawerView(isShowing: $showSettingsDrawer)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .background(Color(.systemBackground))
                        .transition(.opacity)
                }
            }
            .fullScreenCover(isPresented: $showMainSettings) {
                SettingsView(isShowingSettings: $showMainSettings)
            }
        }
    }

    private var blueHeader: some View {
        ZStack(alignment: .topTrailing) {
            CampusWalkUITheme.brandBlue

            Button {
                withAnimation { isShowingProfile = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(10)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(.top, sideMenuCloseButtonTopPadding)
            .padding(.trailing, 20)

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: sideMenuHeaderTopSpacer)

                HStack(alignment: .center, spacing: 16) {
                    Text(avatarInitial)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 8) {
                        Text(profileTitle)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)

                        Button {
                            withAnimation { showSettingsDrawer = true }
                        } label: {
                            HStack(spacing: 4) {
                                Text("编辑资料")
                                    .font(.system(size: 14))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.78))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }
}

private struct SideMenuRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    var badge: String?
    var action: () -> Void

    init(icon: String, title: String, subtitle: String? = nil, badge: String? = nil, action: @escaping () -> Void = {}) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: subtitle == nil ? .center : .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(CampusWalkUITheme.textMuted)
                    .frame(width: 20, alignment: .center)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.33))
                        if let badge {
                            Text(badge)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(CampusWalkUITheme.brandBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(CampusWalkUITheme.brandBlueMutedBg)
                                .clipShape(Capsule())
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(CampusWalkUITheme.textMuted)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SettingsDrawerView: View {
    /// 顶栏在安全区之下的额外留白（与 `safeAreaInsets.top` 相加）。**想微调「设置」标题与灵动岛/状态栏距离时改这里。**
    private let settingsDrawerTopExtraBelowSafeArea: CGFloat = 40
    /// 父级对抽屉使用 `ignoresSafeArea(.top)` 时，`safeAreaInsets.top` 常为 0，用此值模拟状态栏 + 一点间距（约等于原先用 `windows` 垫的高度）。
    private let settingsDrawerTopFallbackWhenNoSafeArea: CGFloat = 54

    @Binding var isShowing: Bool
    @Environment(\.locale) var locale

    var body: some View {
        GeometryReader { geo in
            let topInset = topPadding(safeTop: geo.safeAreaInsets.top)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text(NSLocalizedString("设置", comment: ""))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.33))
                    Spacer()
                    Button(NSLocalizedString("完成", comment: "")) {
                        withAnimation { isShowing = false }
                    }
                    .font(.system(size: 16))
                    .foregroundStyle(CampusWalkUITheme.textMuted)
                }
                .padding(.top, topInset)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .background(Color.white)

                Rectangle()
                    .fill(CampusWalkUITheme.borderSubtle)
                    .frame(height: 1)

                ScrollView {
                    VStack(spacing: 0) {
                        Group {
                            SettingsItem(icon: "person", text: NSLocalizedString("账号管理", comment: ""))
                            SettingsItem(icon: "lock", text: NSLocalizedString("安全设置", comment: ""), trailing: Text(NSLocalizedString("关闭", comment: "")).foregroundColor(CampusWalkUITheme.textMuted))
                            SettingsItem(icon: "key", text: NSLocalizedString("账号密码", comment: ""))
                        }
                        Divider().padding(.vertical, 8).padding(.horizontal, 16)
                        Group {
                            SettingsItem(icon: "lock.shield", text: NSLocalizedString("隐私设置", comment: ""))
                            SettingsItem(icon: "character.book.closed", text: NSLocalizedString("多语言", comment: ""), trailing: Text(locale.identifier == "zh_CN" ? "简体中文" : "English").foregroundColor(CampusWalkUITheme.textMuted))
                            SettingsItem(icon: "waveform", text: NSLocalizedString("Siri 捷径设置", comment: ""))
                            SettingsItem(icon: "eraser", text: NSLocalizedString("清理缓存", comment: ""), trailing: Text("3.50 MB").foregroundColor(CampusWalkUITheme.textMuted))
                        }
                        Divider().padding(.vertical, 8).padding(.horizontal, 16)
                        Group {
                            SettingsItem(icon: "person.text.rectangle", text: NSLocalizedString("个人信息查询", comment: ""))
                            SettingsItem(icon: "person.2", text: NSLocalizedString("共享个人信息清单", comment: ""))
                            SettingsItem(icon: "info.circle", text: NSLocalizedString("关于 CityWalk", comment: ""))
                        }
                        Divider().padding(.vertical, 8).padding(.horizontal, 16)
                        Group {
                            SettingsItem(icon: "lightbulb", text: NSLocalizedString("实验室", comment: ""))
                            SettingsItem(icon: "antenna.radiowaves.left.and.right", text: NSLocalizedString("切换至国际服务器", comment: ""))
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .background(Color.white)
        }
    }

    private func topPadding(safeTop: CGFloat) -> CGFloat {
        let base = safeTop > 1 ? safeTop : settingsDrawerTopFallbackWhenNoSafeArea
        return base + settingsDrawerTopExtraBelowSafeArea
    }
}

struct SettingsItem: View {
    let icon: String
    let text: String
    var trailing: AnyView?

    init(icon: String, text: String, trailing: AnyView? = nil) {
        self.icon = icon
        self.text = text
        self.trailing = trailing
    }

    init(icon: String, text: String, trailing: Text) {
        self.icon = icon
        self.text = text
        self.trailing = AnyView(trailing)
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(CampusWalkUITheme.textMuted)
                .frame(width: 28)
            Text(text)
                .font(.system(size: 16))
                .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.15))
            Spacer()
            if let trailing {
                trailing
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(CampusWalkUITheme.textMuted.opacity(0.6))
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        Divider()
            .padding(.leading, 60)
    }
}

struct HistoryView: View {
    var body: some View {
        List {
            ForEach(0..<10, id: \.self) { i in
                VStack(alignment: .leading) {
                    Text("历史记录 \(i + 1)")
                        .font(.headline)
                    Text("2024-04-28")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationTitle("历史记录")
    }
}

struct PreferencesView: View {
    @State private var autoReply = false
    @State private var language = "简体中文"
    @State private var fontSize: Double = 16

    var body: some View {
        Form {
            Section("基本设置") {
                Toggle("自动回复", isOn: $autoReply)
                Picker("语言", selection: $language) {
                    Text("简体中文").tag("简体中文")
                    Text("English").tag("English")
                }
            }

            Section("显示") {
                VStack {
                    Text("字体大小: \(Int(fontSize))")
                    Slider(value: $fontSize, in: 12...24, step: 1)
                }
            }
        }
        .navigationTitle("偏好设置")
    }
}

struct ChatSettingsView: View {
    @State private var enableSound = true
    @State private var enableVibration = true
    @State private var messagePreview = true

    var body: some View {
        Form {
            Section("通知") {
                Toggle("声音", isOn: $enableSound)
                Toggle("振动", isOn: $enableVibration)
                Toggle("消息预览", isOn: $messagePreview)
            }

            Section("聊天记录") {
                Button("清空聊天记录") {}
                    .foregroundColor(.red)
            }
        }
        .navigationTitle("聊天设置")
    }
}
