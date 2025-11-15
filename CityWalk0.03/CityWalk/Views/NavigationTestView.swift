import SwiftUI
import CoreLocation

// 导航测试界面 - 用于测试完整的导航功能
struct NavigationTestView: View {
    @StateObject private var navManager = CompleteNavigationManager.shared
    @State private var destinationLatitude: String = "23.135"
    @State private var destinationLongitude: String = "113.267"
    @State private var showNavigationView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("导航功能测试")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // 目的地输入
                VStack(spacing: 15) {
                    Text("设置目的地坐标")
                        .font(.headline)
                    
                    HStack {
                        Text("纬度:")
                        TextField("纬度", text: $destinationLatitude)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("经度:")
                        TextField("经度", text: $destinationLongitude)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // 导航状态显示
                NavigationStatusDisplay(
                    isNavigating: navManager.isNavigating,
                    currentInstruction: navManager.currentInstruction,
                    distanceToDestination: navManager.distanceToDestination,
                    currentSpeed: navManager.currentSpeed
                )
                
                // 控制按钮
                VStack(spacing: 15) {
                    Button("开始导航测试") {
                        if let lat = Double(destinationLatitude),
                           let lon = Double(destinationLongitude) {
                            let destination = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                            navManager.startNavigation(to: destination)
                        }
                    }
                    .font(.title2)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("停止导航") {
                        navManager.stopNavigation()
                    }
                    .font(.title2)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("暂停导航") {
                        navManager.pauseNavigation()
                    }
                    .font(.title2)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("恢复导航") {
                        navManager.resumeNavigation()
                    }
                    .font(.title2)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // 打开完整导航界面
                Button("打开完整导航界面") {
                    showNavigationView = true
                }
                .font(.title2)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Spacer()
            }
            .padding()
            .navigationTitle("导航测试")
        }
        .sheet(isPresented: $showNavigationView) {
            CompleteNavigationView()
        }
    }
}

// 导航状态显示组件
struct NavigationStatusDisplay: View {
    let isNavigating: Bool
    let currentInstruction: String
    let distanceToDestination: Double
    let currentSpeed: Double
    
    var body: some View {
        VStack(spacing: 10) {
            Text("导航状态")
                .font(.headline)
                .padding(.bottom, 5)
            
            HStack {
                Text("状态:")
                Text(isNavigating ? "导航中" : "未导航")
                    .foregroundColor(isNavigating ? .green : .red)
                    .fontWeight(.bold)
            }
            
            Text("指令: \(currentInstruction)")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack {
                Text("距离: \(Int(distanceToDestination)) 米")
                Spacer()
                Text("速度: \(Int(currentSpeed * 3.6)) km/h")
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct NavigationTestView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationTestView()
    }
}
