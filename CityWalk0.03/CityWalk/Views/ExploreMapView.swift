import SwiftUI
import MapKit

// 探索页面，全屏地图，状态与sharedMapState同步
struct ExploreMapView: View {
    @ObservedObject var sharedMapState: SharedMapState
    
    // 主体视图，渲染全屏地图和定位按钮
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 渲染地图，绑定摄像头位置，显示用户位置标注
                Map(position: $sharedMapState.cameraPosition) {
                    UserAnnotation()
                }
                .mapStyle(.standard)
                .mapControls {
                    // 显示指南针和比例尺控件
                    MapCompass()
                    MapScaleView()
                }
                .ignoresSafeArea()
                // 绝对定位的自定义定位按钮，点击后回到用户当前位置
                Button(action: {
                    // 设置摄像头位置为用户当前位置
                    sharedMapState.cameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
                }) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.95), Color.blue.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1.2))
                        .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 2)
                }
                // 按钮绝对定位在屏幕右上角，紧贴状态栏下方
                .position(x: geometry.size.width - 16 - 18, y: geometry.safeAreaInsets.top + 2 + 18)
            }
        }
    }
} 