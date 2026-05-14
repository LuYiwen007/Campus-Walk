import SwiftUI

// 启动动画视图，显示应用Logo和名称，动画结束后回调isFinished
struct SplashView: View {
    let isFinished: () -> Void // 动画结束回调
    @State private var scale: CGFloat = 0.5 // Logo缩放比例
    @State private var opacity: CGFloat = 0 // Logo透明度
    
    // 主体视图，渲染启动动画内容
    var body: some View {
        ZStack {
            Color.blue
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "map.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.white)
                
                Text("CityWalk")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            // 启动时播放弹簧动画，Logo渐现
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // 2秒后渐隐，动画结束后回调isFinished
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut(duration: 0.3)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFinished()
                }
            }
        }
    }
} 