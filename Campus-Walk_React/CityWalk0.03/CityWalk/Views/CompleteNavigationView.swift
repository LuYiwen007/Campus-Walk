import SwiftUI
import CoreLocation

// 完整的导航视图 - 包含所有导航功能
struct CompleteNavigationView: View {
    @StateObject private var navManager = CompleteNavigationManager.shared
    @State private var destination: CLLocationCoordinate2D?
    @State private var isNavigationActive = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部状态栏
            NavigationHeaderView(
                isNavigating: navManager.isNavigating,
                onClose: {
                    navManager.stopNavigation()
                    presentationMode.wrappedValue.dismiss()
                }
            )
            
            // 导航信息显示
            NavigationInfoView(
                currentInstruction: navManager.currentInstruction,
                distanceToDestination: navManager.distanceToDestination,
                distanceToNext: navManager.distanceToNext,
                currentSpeed: navManager.currentSpeed,
                currentRoadName: navManager.currentRoadName,
                estimatedArrivalTime: navManager.estimatedArrivalTime
            )
            
            // 导航控制按钮
            NavigationControlView(
                isNavigating: navManager.isNavigating,
                onStart: startNavigation,
                onStop: stopNavigation,
                onPause: pauseNavigation,
                onResume: resumeNavigation
            )
            
            Spacer()
        }
        .background(Color.black.opacity(0.1))
        .onAppear {
            // 可以在这里设置默认目的地
        }
    }
    
    // MARK: - 导航控制方法
    
    private func startNavigation() {
        guard let destination = destination else { return }
        navManager.startNavigation(to: destination)
        isNavigationActive = true
    }
    
    private func stopNavigation() {
        navManager.stopNavigation()
        isNavigationActive = false
    }
    
    private func pauseNavigation() {
        navManager.pauseNavigation()
    }
    
    private func resumeNavigation() {
        navManager.resumeNavigation()
    }
}

// MARK: - 导航头部视图
struct NavigationHeaderView: View {
    let isNavigating: Bool
    let onClose: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            Text("实时导航")
                .font(.headline)
                .fontWeight(.bold)
            
            Spacer()
            
            // 占位符保持居中
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(.clear)
        }
        .padding()
        .background(Color.white)
        .shadow(radius: 2)
    }
}

// MARK: - 导航信息视图
struct NavigationInfoView: View {
    let currentInstruction: String
    let distanceToDestination: Double
    let distanceToNext: Double
    let currentSpeed: Double
    let currentRoadName: String
    let estimatedArrivalTime: Date?
    
    var body: some View {
        VStack(spacing: 20) {
            // 当前指令
            Text(currentInstruction)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            
            // 距离信息
            HStack(spacing: 30) {
                VStack {
                    Text("到目的地")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(Int(distanceToDestination)) 米")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack {
                    Text("下一段")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(Int(distanceToNext)) 米")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
            
            // 速度和道路信息
            HStack(spacing: 30) {
                VStack {
                    Text("当前速度")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(Int(currentSpeed * 3.6)) km/h")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack {
                    Text("当前道路")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(currentRoadName.isEmpty ? "未知道路" : currentRoadName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
            }
            
            // 预计到达时间
            if let arrivalTime = estimatedArrivalTime {
                VStack {
                    Text("预计到达")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(formatTime(arrivalTime))
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 5)
        .padding(.horizontal)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 导航控制视图
struct NavigationControlView: View {
    let isNavigating: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            if isNavigating {
                // 导航中显示停止和暂停按钮
                Button(action: onStop) {
                    Label("停止", systemImage: "stop.circle.fill")
                        .font(.title2)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: onPause) {
                    Label("暂停", systemImage: "pause.circle.fill")
                        .font(.title2)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            } else {
                // 未导航显示开始按钮
                Button(action: onStart) {
                    Label("开始导航", systemImage: "play.circle.fill")
                        .font(.title2)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: onResume) {
                    Label("恢复", systemImage: "play.circle.fill")
                        .font(.title2)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding(.bottom, 30)
    }
}

struct CompleteNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        CompleteNavigationView()
    }
}
