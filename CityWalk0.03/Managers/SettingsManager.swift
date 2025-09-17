import Foundation
import SwiftUI
import UIKit
import UserNotifications

// 设置管理器，负责主题、字体、通知、触感等全局设置
class SettingsManager: ObservableObject {
    @Published var useSystemTheme = true // 是否跟随系统主题
    @Published var isDarkMode = false // 是否为深色模式
    @Published var fontSize = 16.0 // 全局字体大小
    @Published var enableNotifications = true // 是否启用通知
    @Published var enableHaptics = true // 是否启用触感反馈
    
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium) // 触感反馈生成器
    
    // 初始化，监听系统主题变化
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemThemeChanged),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    // 触发一次触感反馈
    func performHapticFeedback() {
        guard enableHaptics else { return }
        feedbackGenerator.impactOccurred()
    }
    
    // 系统主题变化时自动切换
    @objc private func systemThemeChanged() {
        if useSystemTheme {
            updateThemeBasedOnSystem()
        }
    }
    
    // 根据系统设置更新深色/浅色模式
    private func updateThemeBasedOnSystem() {
        if UITraitCollection.current.userInterfaceStyle == .dark {
            isDarkMode = true
        } else {
            isDarkMode = false
        }
    }
    
    // 请求通知权限
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.enableNotifications = granted
            }
        }
    }
} 