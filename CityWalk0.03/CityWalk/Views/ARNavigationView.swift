import SwiftUI
import ARKit
import RealityKit
import CoreLocation

// 基础AR导航骨架：后续将路线点转换为锚点并放置箭头
struct ARNavigationView: View {
    let routeCoordinates: [CLLocationCoordinate2D]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            // 这里后续替换为自定义 ARViewRepresentable
            Text("AR 导航预览（占位）")
                .foregroundColor(.white)
                .padding(.top, 80)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}

#Preview {
    ARNavigationView(routeCoordinates: [])
}


