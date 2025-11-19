import SwiftUI
import AMapNaviKit
import CoreLocation

// 地图导航视图 - 显示在地图上的导航功能
struct MapNavigationView: View {
    @StateObject private var navManager = CompleteNavigationManager.shared
    @State private var destination: CLLocationCoordinate2D?
    @State private var showARNavigation = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                Text("地图导航")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                // 切换到AR导航按钮
                Button(action: {
                    showARNavigation = true
                }) {
                    Image(systemName: "arkit")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color.white)
            .shadow(radius: 2)
            
            // 地图视图
            MapViewRepresentable(
                destination: destination,
                navigationManager: navManager
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 底部导航信息
            NavigationInfoPanel(
                currentInstruction: navManager.currentInstruction,
                distanceToDestination: navManager.distanceToDestination,
                distanceToNext: navManager.distanceToNext,
                currentSpeed: navManager.currentSpeed,
                currentRoadName: navManager.currentRoadName,
                estimatedArrivalTime: navManager.estimatedArrivalTime
            )
            
            // 导航控制按钮
            NavigationControlPanel(
                isNavigating: navManager.isNavigating,
                onStart: startNavigation,
                onStop: stopNavigation,
                onPause: pauseNavigation,
                onResume: resumeNavigation
            )
        }
        .onAppear {
            // 设置默认目的地
            if destination == nil {
                destination = CLLocationCoordinate2D(latitude: 23.135, longitude: 113.267)
            }
        }
        .sheet(isPresented: $showARNavigation) {
            if let destination = destination {
                ARNavigationView(destination: destination)
            }
        }
    }
    
    // MARK: - 导航控制方法
    
    private func startNavigation() {
        guard let destination = destination else { return }
        navManager.startNavigation(to: destination)
    }
    
    private func stopNavigation() {
        navManager.stopNavigation()
    }
    
    private func pauseNavigation() {
        navManager.pauseNavigation()
    }
    
    private func resumeNavigation() {
        navManager.resumeNavigation()
    }
}

// MARK: - 地图视图组件
struct MapViewRepresentable: UIViewRepresentable {
    let destination: CLLocationCoordinate2D?
    let navigationManager: CompleteNavigationManager
    
    func makeUIView(context: Context) -> MAMapView {
        let mapView = MAMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        
        // 设置地图中心
        if let destination = destination {
            mapView.setCenter(destination, animated: true)
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MAMapView, context: Context) {
        // 更新地图显示
        if let destination = destination {
            mapView.setCenter(destination, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MAMapViewDelegate {
        let parent: MapViewRepresentable
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MAMapView!, didUpdate userLocation: MAUserLocation!, updatingLocation: Bool) {
            // 更新用户位置
        }
        
        func mapView(_ mapView: MAMapView!, rendererFor overlay: MAOverlay!) -> MAOverlayRenderer! {
            // 渲染路线覆盖层
            if overlay is MAPolyline {
                let renderer = MAPolylineRenderer(polyline: overlay as! MAPolyline)
                renderer?.strokeColor = UIColor.blue
                renderer?.lineWidth = 5.0
                return renderer
            }
            return nil
        }
    }
}

// MARK: - 导航信息面板
struct NavigationInfoPanel: View {
    let currentInstruction: String
    let distanceToDestination: Double
    let distanceToNext: Double
    let currentSpeed: Double
    let currentRoadName: String
    let estimatedArrivalTime: Date?
    
    var body: some View {
        VStack(spacing: 15) {
            // 当前指令
            Text(currentInstruction)
                .font(.title3)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // 距离和速度信息
            HStack(spacing: 20) {
                VStack {
                    Text("到目的地")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(Int(distanceToDestination)) 米")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                VStack {
                    Text("下一段")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(Int(distanceToNext)) 米")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                VStack {
                    Text("当前速度")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(Int(currentSpeed * 3.6)) km/h")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            
            // 道路名称
            if !currentRoadName.isEmpty {
                Text("当前道路: \(currentRoadName)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 3)
        .padding(.horizontal)
    }
}

// MARK: - 导航控制面板
struct NavigationControlPanel: View {
    let isNavigating: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            if isNavigating {
                Button(action: onStop) {
                    Label("停止", systemImage: "stop.circle.fill")
                        .font(.title3)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: onPause) {
                    Label("暂停", systemImage: "pause.circle.fill")
                        .font(.title3)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            } else {
                Button(action: onStart) {
                    Label("开始导航", systemImage: "play.circle.fill")
                        .font(.title3)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: onResume) {
                    Label("恢复", systemImage: "play.circle.fill")
                        .font(.title3)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.bottom, 20)
    }
}

struct MapNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        MapNavigationView()
    }
}
