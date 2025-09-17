import Foundation
import UserNotifications

// 通知管理器，负责本地推送通知的授权与发送
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager() // 单例
    
    @Published var isAuthorized = false // 是否已授权通知
    
    // 初始化，设置通知代理并请求授权
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        requestAuthorization()
    }
    
    // 请求通知权限
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
            }
        }
    }
    
    // 发送通用推送通知
    func sendRouteNotification(title: String, body: String) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // 发送"开始导航"通知
    func sendRouteStartNotification(destination: String) {
        let title = NSLocalizedString("notification.route.start", comment: "")
        let formattedTitle = String(format: title, destination)
        sendRouteNotification(title: formattedTitle, body: "")
    }
    
    // 发送"转弯提示"通知
    func sendTurnNotification(direction: String, distance: Int) {
        let title = NSLocalizedString("notification.route.turn", comment: "")
        let formattedTitle = String(format: title, direction, distance)
        sendRouteNotification(title: formattedTitle, body: "")
    }
    
    // 发送"到达目的地"通知
    func sendArrivalNotification() {
        let title = NSLocalizedString("notification.route.arrived", comment: "")
        sendRouteNotification(title: title, body: "")
    }
    
    // 发送"重新规划路线"通知
    func sendRecalculatingNotification() {
        let title = NSLocalizedString("notification.route.recalculating", comment: "")
        sendRouteNotification(title: title, body: "")
    }
}

// 通知代理，处理通知在前台时的展示方式
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
} 