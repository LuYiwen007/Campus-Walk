import SwiftUI
import AVFoundation
import CoreLocation

// 基础AR识别骨架：先打通入口与后端 /poi/nearby
struct ARBuildingInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var infoText: String = "正在识别前方建筑…"
    private let locationManager = CLLocationManager()
    @State private var session: AVCaptureSession = AVCaptureSession()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CameraPreview(session: session)
                .ignoresSafeArea()
            Text(infoText)
                .foregroundColor(.white)
                .padding(.top, 80)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .onAppear {
            startCamera()
            requestPOI()
        }
    }

    private func requestPOI() {
        // 简化示例：用一个固定点调用后端，等集成定位与朝向后替换
        let urlStr = "http://192.168.3.39:8000/poi/nearby?lat=23.132&lon=113.264&heading=0&radius=150&fov=60"
        guard let url = URL(string: urlStr) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool, success,
                  let dataDict = json["data"] as? [String: Any],
                  let name = dataDict["name"] as? String else {
                return
            }
            DispatchQueue.main.async {
                self.infoText = "识别到：\(name)"
            }
        }.resume()
    }

    private func startCamera() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else { return }
            session.beginConfiguration()
            session.sessionPreset = .high
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: device) {
                if session.canAddInput(input) { session.addInput(input) }
            }
            let output = AVCaptureVideoDataOutput()
            if session.canAddOutput(output) { session.addOutput(output) }
            session.commitConfiguration()
            session.startRunning()
        }
    }
}

#Preview {
    ARBuildingInfoView()
}


