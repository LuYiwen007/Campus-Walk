import SwiftUI

/// 设置页（对齐原型 `SettingsPage.tsx`：白底、顶栏「关闭 / 设置」、分组小标题 + 圆角描边卡片）
struct SettingsView: View {
    @Binding var isShowingSettings: Bool
    @StateObject private var settings = SettingsManager.shared
    @State private var showResetAlert = false
    @State private var showPrivacyPolicy = false
    @State private var showTerms = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    sectionBlock(title: "个人设置") {
                        VStack(spacing: 0) {
                            settingsToggleRow(title: "跟随系统", isOn: $settings.useSystemTheme)
                            rowDivider
                            if !settings.useSystemTheme {
                                settingsToggleRow(title: "深色模式", isOn: $settings.isDarkMode)
                                rowDivider
                            }
                            fontSizeBlock
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerCard, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerCard, style: .continuous)
                                .stroke(CampusWalkUITheme.borderSubtle, lineWidth: 1)
                        )
                    }

                    sectionBlock(title: "聊天设置") {
                        VStack(spacing: 0) {
                            settingsToggleRow(title: "通知", isOn: $settings.enableNotifications)
                            rowDivider
                            settingsToggleRow(title: "声音", isOn: $settings.enableSound)
                            rowDivider
                            settingsToggleRow(title: "触感", isOn: $settings.enableHaptics)
                            rowDivider
                            languageRow
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerCard, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerCard, style: .continuous)
                                .stroke(CampusWalkUITheme.borderSubtle, lineWidth: 1)
                        )
                    }

                    sectionBlock(title: "数据与存储") {
                        Button {
                            showResetAlert = true
                            settings.performHapticFeedback()
                        } label: {
                            Text("清除聊天记录")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(red: 0.93, green: 0.27, blue: 0.27))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.plain)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerCard, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerCard, style: .continuous)
                                .stroke(CampusWalkUITheme.borderSubtle, lineWidth: 1)
                        )
                    }

                    sectionBlock(title: "关于") {
                        VStack(spacing: 0) {
                            Button {
                                showPrivacyPolicy = true
                                settings.performHapticFeedback()
                            } label: {
                                Text("隐私政策")
                                    .font(.system(size: 14))
                                    .foregroundStyle(CampusWalkUITheme.brandBlue)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                            }
                            .buttonStyle(.plain)
                            rowDivider
                            Button {
                                showTerms = true
                                settings.performHapticFeedback()
                            } label: {
                                Text("服务条款")
                                    .font(.system(size: 14))
                                    .foregroundStyle(CampusWalkUITheme.brandBlue)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                            }
                            .buttonStyle(.plain)
                            rowDivider
                            HStack {
                                Text("版本")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.33))
                                Spacer()
                                Text("1.0.0")
                                    .font(.system(size: 14))
                                    .foregroundStyle(CampusWalkUITheme.textMuted)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerCard, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerCard, style: .continuous)
                                .stroke(CampusWalkUITheme.borderSubtle, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .background(Color.white)
        .font(.system(size: settings.fontSize))
        .tint(CampusWalkUITheme.brandBlue)
        .onChange(of: settings.useSystemTheme) { _, followsSystem in
            settings.performHapticFeedback()
            if followsSystem, let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.first?.overrideUserInterfaceStyle = .unspecified
            }
        }
        .onChange(of: settings.isDarkMode) { newValue in
            settings.performHapticFeedback()
            guard !settings.useSystemTheme else { return }
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.first?.overrideUserInterfaceStyle = newValue ? .dark : .light
            }
        }
        .onChange(of: settings.fontSize) { _ in
            settings.performHapticFeedback()
            NotificationCenter.default.post(name: NSNotification.Name("FontSizeChanged"), object: nil)
        }
        .onChange(of: settings.enableNotifications) { _ in settings.performHapticFeedback() }
        .onChange(of: settings.enableSound) { _ in settings.performHapticFeedback() }
        .onChange(of: settings.enableHaptics) { _ in settings.performHapticFeedback() }
        .onChange(of: settings.language) { _ in
            settings.performHapticFeedback()
            NotificationCenter.default.post(name: NSNotification.Name("LanguageChanged"), object: nil)
        }
        .alert("确认清除", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                settings.clearChatHistory()
            }
        } message: {
            Text("确定要清除所有聊天记录吗？此操作不可撤销。")
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView(isShowing: $showPrivacyPolicy)
        }
        .sheet(isPresented: $showTerms) {
            TermsView(isShowing: $showTerms)
        }
    }

    private var headerBar: some View {
        HStack {
            Button("关闭") {
                isShowingSettings = false
            }
            .font(.system(size: 14))
            .foregroundStyle(Color(red: 0.45, green: 0.48, blue: 0.52))

            Spacer()

            Text("设置")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.33))

            Spacer()

            Color.clear.frame(width: 40, height: 1)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.white)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CampusWalkUITheme.borderSubtle)
                .frame(height: 1)
        }
    }

    private func sectionBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(CampusWalkUITheme.sectionTitle)
            content()
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(CampusWalkUITheme.borderSubtle)
            .frame(height: 1)
            .padding(.leading, 20)
    }

    private func settingsToggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.33))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(CampusWalkUITheme.brandBlue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var fontSizeBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("字体大小")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.33))
                Spacer()
                Text("\(Int(settings.fontSize))")
                    .font(.system(size: 14))
                    .foregroundStyle(CampusWalkUITheme.textMuted)
            }
            Slider(value: $settings.fontSize, in: 12...24, step: 1)
                .tint(CampusWalkUITheme.brandBlue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var languageRow: some View {
        HStack {
            Text("语言")
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.33))
            Spacer()
            Menu {
                Button("简体中文") { settings.language = "简体中文" }
                Button("English") { settings.language = "English" }
                Button("繁體中文") { settings.language = "繁體中文" }
            } label: {
                Text(settings.language)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.33))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(CampusWalkUITheme.surfaceGray50)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(CampusWalkUITheme.borderSubtle, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

struct PrivacyPolicyView: View {
    @Binding var isShowing: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                Text("隐私政策内容...")
                    .font(.system(size: 15))
                    .foregroundStyle(CampusWalkUITheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color.white)
            .navigationTitle("隐私政策")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { isShowing = false }
                }
            }
        }
    }
}

struct TermsView: View {
    @Binding var isShowing: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                Text("服务条款内容...")
                    .font(.system(size: 15))
                    .foregroundStyle(CampusWalkUITheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color.white)
            .navigationTitle("服务条款")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { isShowing = false }
                }
            }
        }
    }
}
