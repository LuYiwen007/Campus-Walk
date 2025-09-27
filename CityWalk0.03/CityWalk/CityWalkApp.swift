//
//  CityWalkApp.swift
//  CityWalk
//
//  Created by 卢绎文 on 2025/4/25.
//

import SwiftUI
import SwiftData
import AMapFoundationKit
import AMapSearchKit
import AMapLocationKit
import MAMapKit

// 新增AppDelegate类用于高德Key初始化
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 新版高德SDK隐私合规接口，必须在任何高德SDK对象初始化前调用
        AMapLocationManager.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        AMapLocationManager.updatePrivacyAgree(.didAgree)
        AMapSearchAPI.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        AMapSearchAPI.updatePrivacyAgree(.didAgree)
        // 地图组件也需在实例化前进行隐私合规设置
        MAMapView.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        MAMapView.updatePrivacyAgree(.didAgree)
        // 统一设置 Key 与 HTTPS
        AMapServices.shared().enableHTTPS = true
        AMapServices.shared().apiKey = "4c6e7aa728f408e1fc754200f5bed2e4"
        return true
    }
}

// 应用程序主入口，负责全局数据容器和主窗口
@main
struct CityWalkApp: App {
    // 全局数据模型容器，负责数据持久化
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            // 创建数据容器
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // 主体视图，渲染主窗口和注入数据容器
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
