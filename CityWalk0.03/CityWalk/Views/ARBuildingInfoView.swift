import SwiftUI
import AVFoundation
import CoreLocation

/// AR 建筑识别：调用后端 `/api/v1/ar/recognize`；建筑数据与坐标匹配在后端（种子库）。
struct ARBuildingInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var infoText: String = "正在识别前方建筑…"
    @StateObject private var locationFetcher = ARBuildingLocationFetcher()
    @State private var session: AVCaptureSession = AVCaptureSession()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                CameraPreview(session: session)
                    .ignoresSafeArea()
                Text(infoText)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .padding(.top, 80)

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                        .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                startCamera()
                requestPOI()
            }
        }
    }

    private func requestPOI() {
        locationFetcher.fetchOnce { coord in
            Task {
                let lat = coord?.latitude ?? ARBuildingLocationFetcher.fallbackSeed.latitude
                let lon = coord?.longitude ?? ARBuildingLocationFetcher.fallbackSeed.longitude
                let heading = locationFetcher.lastHeadingDegrees
                do {
                    let res = try await APIClient.shared.arRecognize(
                        latitude: lat,
                        longitude: lon,
                        heading: heading,
                        sessionId: nil
                    )
                    await MainActor.run {
                        if let b = res.building {
                            infoText = "识别到：\(b.name)\n\(res.matchNote)"
                        } else {
                            infoText = res.matchNote.isEmpty ? "未匹配到建筑" : res.matchNote
                        }
                    }
                } catch {
                    await MainActor.run {
                        infoText = "识别请求失败：\(error.localizedDescription)"
                    }
                }
            }
        }
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

// MARK: - 单次定位（与后端种子建筑坐标同量级，作无权限/失败时回退）
private final class ARBuildingLocationFetcher: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let fallbackSeed = CLLocationCoordinate2D(latitude: 23.13219, longitude: 113.264385)

    private let manager = CLLocationManager()
    private var completion: ((CLLocationCoordinate2D?) -> Void)?
    private var timeoutWorkItem: DispatchWorkItem?
    var lastHeadingDegrees: Double = 0

    func fetchOnce(completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        self.completion = completion
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        if CLLocationManager.locationServicesEnabled() {
            switch manager.authorizationStatus {
            case .denied, .restricted:
                completion(nil)
                self.completion = nil
                return
            default:
                break
            }
        }
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.completion != nil else { return }
            self.manager.stopUpdatingLocation()
            self.manager.stopUpdatingHeading()
            self.completion?(nil)
            self.completion = nil
        }
        timeoutWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: work)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        case .denied, .restricted:
            finish(nil)
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let c = locations.last?.coordinate else { return }
        finish(c)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(nil)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        lastHeadingDegrees = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }

    private func finish(_ coord: CLLocationCoordinate2D?) {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        guard let done = completion else { return }
        completion = nil
        done(coord)
    }
}

#Preview {
    ARBuildingInfoView()
}
