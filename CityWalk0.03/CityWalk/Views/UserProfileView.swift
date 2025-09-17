import SwiftUI
import MAMapKit
import AMapFoundationKit
import AMapSearchKit
import AMapLocationKit

// 用户视图模型，管理登录状态、用户名、头像等
class UserViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var username: String = "游客用户"
    @Published var userAvatar: Image = Image(systemName: "person.circle.fill")
    
    // 登录方法，模拟登录逻辑
    func login(username: String, password: String) -> Bool {
        // TODO: 实现实际的登录逻辑
        self.username = username
        self.isLoggedIn = true
        return true
    }
    
    // 登出方法，重置用户信息
    func logout() {
        self.username = "游客用户"
        self.isLoggedIn = false
        self.userAvatar = Image(systemName: "person.circle.fill")
    }
    
    // 更新头像方法
    func updateAvatar(_ image: Image) {
        self.userAvatar = image
    }
}

// 用户资料页，支持登录、登出、修改头像、查看历史等
struct UserProfileView: View {
    @Binding var isShowingProfile: Bool
    @StateObject private var userViewModel = UserViewModel()
    @State private var showSettingsDrawer = false
    @Environment(\.locale) var locale
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if !showSettingsDrawer {
                    VStack(alignment: .leading, spacing: 0) {
                        // 顶部头像区
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .center, spacing: 16) {
                                userViewModel.userAvatar
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                                HStack(spacing: 8) {
                                    Text(userViewModel.isLoggedIn ? userViewModel.username : NSLocalizedString("请登录", comment: ""))
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.black)
                                    Button(action: { withAnimation { showSettingsDrawer = true } }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.gray)
                                            .padding(8)
                                            .background(Color(.systemGray6))
                                            .clipShape(Circle())
                                    }
                                }
                                Spacer()
                            }
                            .padding(.top, 60)
                            .padding(.bottom, 18)
                            .padding(.horizontal, 20)
                        }
                        Divider().padding(.bottom, 2)
                        // 功能区
                        VStack(alignment: .leading, spacing: 0) {
                            DrawerItem(icon: "book", text: "联系人")
                            DrawerItem(icon: "bell", text: "通知")
                            DrawerItem(icon: "clock.arrow.circlepath", text: "版本历史", badge: "新")
                            DrawerItem(icon: "headphones", text: "联系我们")
                            DrawerItem(icon: "person.badge.plus", text: "添加团队成员", sub: "成员可访问公开信息...")
                            DrawerItem(icon: "gearshape", text: "设置")
                            DrawerItem(icon: "info.circle", text: "关于App")
                            DrawerItem(icon: "star", text: "我的收藏")
                            DrawerItem(icon: "doc.text", text: "我的文档")
                            DrawerItem(icon: "creditcard", text: "支付与订单")
                            DrawerItem(icon: "questionmark.circle", text: "帮助与反馈")
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(Color.white)
                    .ignoresSafeArea()
                    // 顶部右上角关闭按钮
                    .overlay(
                        Button(action: { withAnimation { isShowingProfile = false } }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Color(.systemGray3))
                                .padding(12)
                        }
                        .padding(.top, UIApplication.shared.windows.first?.safeAreaInsets.top ?? 44)
                        .padding(.trailing, 16)
                    , alignment: .topTrailing
                    )
                    .transition(.opacity)
                }
                if showSettingsDrawer {
                    SettingsDrawerView(isShowing: $showSettingsDrawer)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .background(Color(.systemBackground))
                        .ignoresSafeArea()
                        .padding(.top, UIApplication.shared.windows.first?.safeAreaInsets.top ?? 44)
                        .transition(.opacity)
                }
            }
        }
    }
}

struct DrawerItem: View {
    let icon: String
    let text: String
    var badge: String? = nil
    var sub: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.black)
                    .frame(width: 28)
                Text(text)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.15)))
                }
                Spacer()
            }
            .padding(.vertical, 14)
            if let sub = sub {
                Text(sub)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(.leading, 44)
                    .padding(.bottom, 8)
            }
            Divider()
                .padding(.leading, 44)
        }
        .padding(.horizontal, 12)
    }
}

// 设置抽屉内容，极简分组、分割线、右箭头、支持多语言
struct SettingsDrawerView: View {
    @Binding var isShowing: Bool
    @Environment(\.locale) var locale
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text(NSLocalizedString("设置", comment: ""))
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button(NSLocalizedString("完成", comment: "")) {
                    withAnimation { isShowing = false }
                }
                .foregroundColor(.gray)
            }
            .padding(.top, 60)
            .padding(.bottom, 8)
            .background(Color.white)
            Divider()
            Group {
                SettingsItem(icon: "person", text: NSLocalizedString("账号管理", comment: ""))
                SettingsItem(icon: "lock", text: NSLocalizedString("安全设置", comment: ""), trailing: Text(NSLocalizedString("关闭", comment: "")).foregroundColor(.gray))
                SettingsItem(icon: "key", text: NSLocalizedString("账号密码", comment: ""))
            }
            Divider().padding(.vertical, 2)
            Group {
                SettingsItem(icon: "lock.shield", text: NSLocalizedString("隐私设置", comment: ""))
                SettingsItem(icon: "character.book.closed", text: NSLocalizedString("多语言", comment: ""), trailing: Text(locale.identifier == "zh_CN" ? "简体中文" : "English").foregroundColor(.gray))
                SettingsItem(icon: "waveform", text: NSLocalizedString("Siri 捷径设置", comment: ""))
                SettingsItem(icon: "eraser", text: NSLocalizedString("清理缓存", comment: ""), trailing: Text("3.50 MB").foregroundColor(.gray))
            }
            Divider().padding(.vertical, 2)
            Group {
                SettingsItem(icon: "person.text.rectangle", text: NSLocalizedString("个人信息查询", comment: ""))
                SettingsItem(icon: "person.2", text: NSLocalizedString("共享个人信息清单", comment: ""))
                SettingsItem(icon: "info.circle", text: NSLocalizedString("关于 CityWalk", comment: ""))
            }
            Divider().padding(.vertical, 2)
            Group {
                SettingsItem(icon: "lightbulb", text: NSLocalizedString("实验室", comment: ""))
                SettingsItem(icon: "antenna.radiowaves.left.and.right", text: NSLocalizedString("切换至国际服务器", comment: ""))
            }
            Spacer()
        }
        .background(Color.white)
    }
}

struct SettingsItem: View {
    let icon: String
    let text: String
    var trailing: AnyView? = nil
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
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.gray)
                .frame(width: 28)
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.black)
            Spacer()
            if let trailing = trailing {
                trailing
            }
            Image(systemName: "chevron.right")
                .foregroundColor(.gray.opacity(0.5))
                .font(.system(size: 16, weight: .medium))
        }
        .padding(.vertical, 14)
        Divider().padding(.leading, 44)
        .background(Color.white)
    }
}

// 登录弹窗视图
struct LoginView: View {
    @ObservedObject var userViewModel: UserViewModel
    @Binding var isPresented: Bool
    @Binding var showRegister: Bool
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showingAlert = false
    
    // 主体视图，渲染登录表单
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("用户名", text: $username)
                    SecureField("密码", text: $password)
                }
                
                Section {
                    Button("登录") {
                        // 登录逻辑，成功则关闭弹窗
                        if userViewModel.login(username: username, password: password) {
                            isPresented = false
                        } else {
                            showingAlert = true
                        }
                    }
                    .disabled(username.isEmpty || password.isEmpty)
                    
                    Button("还没有账号？立即注册") {
                        // 跳转到注册弹窗
                        isPresented = false
                        showRegister = true
                    }
                }
            }
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        isPresented = false
                    }
                }
            }
            .alert("登录失败", isPresented: $showingAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("用户名或密码错误")
            }
        }
    }
}

// 注册弹窗视图
struct RegisterView: View {
    @Binding var isPresented: Bool
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // 主体视图，渲染注册表单
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("用户名", text: $username)
                    SecureField("密码", text: $password)
                    SecureField("确认密码", text: $confirmPassword)
                }
                
                Section {
                    Button("注册") {
                        // TODO: 实现注册逻辑
                        if password != confirmPassword {
                            alertMessage = "两次输入的密码不一致"
                            showingAlert = true
                            return
                        }
                        // 处理注册成功的情况
                        isPresented = false
                    }
                    .disabled(username.isEmpty || password.isEmpty || confirmPassword.isEmpty)
                }
            }
            .navigationTitle("注册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        isPresented = false
                    }
                }
            }
            .alert("注册失败", isPresented: $showingAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
}

// 历史记录视图
struct HistoryView: View {
    // 主体视图，渲染历史记录列表
    var body: some View {
        List {
            ForEach(0..<10) { i in
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

// 偏好设置视图
struct PreferencesView: View {
    @State private var autoReply = false
    @State private var language = "简体中文"
    @State private var fontSize: Double = 16
    
    // 主体视图，渲染偏好设置表单
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

// 聊天设置视图
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
                Button("清空聊天记录") {
                    // TODO: 实现清空聊天记录功能
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("聊天设置")
    }
} 