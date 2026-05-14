import SwiftUI
import UserNotifications
import AVFoundation

// 添加环境键
private struct FontSizeKey: EnvironmentKey {
    static let defaultValue: Double = 16
}

private struct LanguageKey: EnvironmentKey {
    static let defaultValue: String = "简体中文"
}

extension EnvironmentValues {
    var fontSize: Double {
        get { self[FontSizeKey.self] }
        set { self[FontSizeKey.self] = newValue }
    }
    
    var language: String {
        get { self[LanguageKey.self] }
        set { self[LanguageKey.self] = newValue }
    }
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @AppStorage("useSystemTheme") var useSystemTheme = true {
        didSet {
            if useSystemTheme {
                updateThemeBasedOnSystem()
            }
        }
    }
    @AppStorage("isDarkMode") var isDarkMode = false
    @AppStorage("fontSize") var fontSize: Double = 16
    @AppStorage("enableNotifications") var enableNotifications = true {
        didSet {
            if enableNotifications {
                requestNotificationPermission()
            }
        }
    }
    @AppStorage("enableSound") var enableSound = true
    @AppStorage("enableHaptics") var enableHaptics = true
    @AppStorage("language") var language = "简体中文"
    
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    private init() {
        if useSystemTheme {
            updateThemeBasedOnSystem()
        }
        
        // 监听系统主题变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemThemeChanged),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    func performHapticFeedback() {
        guard enableHaptics else { return }
        feedbackGenerator.impactOccurred()
    }
    
    func playSound() {
        // 由于音频播放器已被移除，此方法将不会执行
    }
    
    @objc private func systemThemeChanged() {
        if useSystemTheme {
            updateThemeBasedOnSystem()
        }
    }
    
    private func updateThemeBasedOnSystem() {
        if UITraitCollection.current.userInterfaceStyle == .dark {
            isDarkMode = true
        } else {
            isDarkMode = false
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.enableNotifications = granted
            }
        }
    }
    
    func clearChatHistory() {
        // 清除本地存储的聊天记录
        UserDefaults.standard.removeObject(forKey: "chatHistory")
        UserDefaults.standard.synchronize()
        
        // 发送通知，通知其他视图更新
        NotificationCenter.default.post(name: NSNotification.Name("ChatHistoryCleared"), object: nil)
        
        // 执行触觉反馈
        performHapticFeedback()
    }
} 
