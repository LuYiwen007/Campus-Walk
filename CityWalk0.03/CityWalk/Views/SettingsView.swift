import SwiftUI

// 设置页面，包含主题、字体、通知、语言、隐私等设置项
struct SettingsView: View {
    @Binding var isShowingSettings: Bool // 控制设置页显示/隐藏
    @StateObject private var settings = SettingsManager.shared // 设置管理器
    @State private var showResetAlert = false // 是否显示清除聊天记录弹窗
    @State private var showPrivacyPolicy = false // 是否显示隐私政策弹窗
    @State private var showTerms = false // 是否显示服务条款弹窗
    
    // 主体视图，渲染所有设置项
    var body: some View {
        NavigationView {
            List {
                // 偏好设置分区
                Section("偏好设置") {
                    Toggle("跟随系统", isOn: $settings.useSystemTheme)
                        .onChange(of: settings.useSystemTheme) { _ in
                            // 切换跟随系统主题时触发触感反馈
                            settings.performHapticFeedback()
                        }
                    
                    if !settings.useSystemTheme {
                        Toggle("深色模式", isOn: $settings.isDarkMode)
                            .onChange(of: settings.isDarkMode) { _ in
                                // 切换深色模式时触发触感反馈
                                settings.performHapticFeedback()
                            }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("字体大小")
                            .font(.system(size: settings.fontSize))
                        Slider(value: $settings.fontSize, in: 12...24, step: 1)
                            .onChange(of: settings.fontSize) { _ in
                                // 调整字体大小时触发触感反馈并通知全局字体变化
                                settings.performHapticFeedback()
                                NotificationCenter.default.post(name: NSNotification.Name("FontSizeChanged"), object: nil)
                            }
                        Text("\(Int(settings.fontSize))")
                            .font(.system(size: settings.fontSize))
                    }
                }
                
                // 聊天设置分区
                Section("聊天设置") {
                    Toggle<Text>("通知", isOn: $settings.enableNotifications)
                        .onChange(of: settings.enableNotifications) { _ in
                            settings.performHapticFeedback()
                        }
                    
                    Toggle<Text>("声音", isOn: $settings.enableSound)
                        .onChange(of: settings.enableSound) { _ in
                            settings.performHapticFeedback()
                        }
                    
                    Toggle<Text>("触感", isOn: $settings.enableHaptics)
                        .onChange(of: settings.enableHaptics) { _ in
                            settings.performHapticFeedback()
                        }
                    
                    Picker("语言", selection: $settings.language) {
                        Text("简体中文").tag("简体中文")
                        Text("English").tag("English")
                    }
                    .onChange(of: settings.language) { _ in
                        // 切换语言时触发触感反馈并通知全局语言变化
                        settings.performHapticFeedback()
                        NotificationCenter.default.post(name: NSNotification.Name("LanguageChanged"), object: nil)
                    }
                }
                
                // 数据与存储分区
                Section("数据与存储") {
                    Button(action: {
                        // 点击清除聊天记录按钮，弹出确认弹窗
                        showResetAlert = true
                        settings.performHapticFeedback()
                    }) {
                        Text("清除聊天记录")
                            .foregroundColor(.red)
                    }
                }
                
                
                
                // 关于分区
                Section("关于") {
                    Button("隐私政策") {
                        // 显示隐私政策弹窗
                        showPrivacyPolicy = true
                        settings.performHapticFeedback()
                    }
                    Button("服务条款") {
                        // 显示服务条款弹窗
                        showTerms = true
                        settings.performHapticFeedback()
                    }
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                }
            }
            .font(.system(size: settings.fontSize))
            .navigationTitle("设置")
            .navigationBarItems(leading: Button("关闭") {
                // 关闭设置页
                isShowingSettings = false
            })
            .alert(isPresented: $showResetAlert) {
                // 清除聊天记录确认弹窗
                Alert(
                    title: Text("确认清除"),
                    message: Text("确定要清除所有聊天记录吗？此操作不可撤销。"),
                    primaryButton: .destructive(Text("清除")) {
                        settings.clearChatHistory()
                        settings.performHapticFeedback()
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView(isShowing: $showPrivacyPolicy)
            }
            .sheet(isPresented: $showTerms) {
                TermsView(isShowing: $showTerms)
            }
            .onChange(of: settings.isDarkMode) { newValue in
                // 切换深色/浅色模式时，动态修改全局界面风格
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    windowScene.windows.first?.overrideUserInterfaceStyle = newValue ? .dark : .light
                }
            }
        }
    }
}

// 隐私政策弹窗视图
struct PrivacyPolicyView: View {
    @Binding var isShowing: Bool // 控制弹窗显示/隐藏
    
    // 主体视图，显示隐私政策内容
    var body: some View {
        NavigationView {
            ScrollView {
                Text("隐私政策内容...")
                    .padding()
            }
            .navigationTitle("隐私政策")
            .navigationBarItems(trailing: Button("关闭") {
                // 关闭弹窗
                isShowing = false
            })
        }
    }
}

// 服务条款弹窗视图
struct TermsView: View {
    @Binding var isShowing: Bool // 控制弹窗显示/隐藏
    
    // 主体视图，显示服务条款内容
    var body: some View {
        NavigationView {
            ScrollView {
                Text("服务条款内容...")
                    .padding()
            }
            .navigationTitle("服务条款")
            .navigationBarItems(trailing: Button("关闭") {
                // 关闭弹窗
                isShowing = false
            })
        }
    }
} 