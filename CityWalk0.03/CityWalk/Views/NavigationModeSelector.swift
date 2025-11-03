import SwiftUI
import CoreLocation

// 导航模式选择器 - 让用户选择地图导航或AR导航
struct NavigationModeSelector: View {
    @State private var destinationLatitude: String = "23.135"
    @State private var destinationLongitude: String = "113.267"
    @State private var showMapNavigation = false
    @State private var showARNavigation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("选择导航模式")
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
                
                // 导航模式选择
                VStack(spacing: 20) {
                    Text("选择导航模式")
                        .font(.headline)
                    
                    // 地图导航按钮
                    Button(action: {
                        if Double(destinationLatitude) != nil,
                           Double(destinationLongitude) != nil {
                            showMapNavigation = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "map.fill")
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text("地图导航")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Text("传统地图导航，显示路线和位置")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                    }
                    .foregroundColor(.primary)
                    
                    // AR导航按钮
                    Button(action: {
                        if Double(destinationLatitude) != nil,
                           Double(destinationLongitude) != nil {
                            showARNavigation = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "arkit")
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text("AR导航")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Text("增强现实导航，AR箭头指引")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                    }
                    .foregroundColor(.primary)
                    
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("导航选择")
        }
        .sheet(isPresented: $showMapNavigation) {
            if Double(destinationLatitude) != nil,
               Double(destinationLongitude) != nil {
                MapNavigationView()
            }
        }
        .sheet(isPresented: $showARNavigation) {
            if let lat = Double(destinationLatitude),
               let lon = Double(destinationLongitude) {
                ARNavigationView(destination: CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
        }
    }
}

struct NavigationModeSelector_Previews: PreviewProvider {
    static var previews: some View {
        NavigationModeSelector()
    }
}
