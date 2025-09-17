//
//  ContentView.swift
//  CityWalk
//
//  Created by 卢绎文 on 2025/4/25.
//

import SwiftUI

// 应用主入口视图，负责启动动画与主界面切换
struct ContentView: View {
    @State private var showSplash = true // 是否显示启动动画
    @State private var selectedTab = 0 // 默认选中"社区"Tab
    
    // 主体视图，先显示SplashView，动画结束后切换到主Tab界面
    var body: some View {
        ZStack {
            if showSplash {
                SplashView {
                    // 启动动画结束后切换到主界面
                    withAnimation {
                        showSplash = false
                    }
                }
            } else {
                MainTabView(selectedTab: $selectedTab)
            }
        }
    }
}

#Preview {
    ContentView()
}
