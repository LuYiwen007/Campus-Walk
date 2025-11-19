import SwiftUI
import CoreLocation

// 分段路线显示视图
struct SegmentedRouteView: View {
    let conversationId: Int
    @State private var currentSegmentIndex: Int = 0
    @State private var routeSegments: [RouteSegment] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showMap: Bool = false
    @State private var currentRouteData: [CLLocationCoordinate2D] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部控制栏（新增 AR/高德 切换）
            HStack {
                Button("返回") {
                    // 返回逻辑
                }
                .foregroundColor(.blue)
                
                Spacer()
                
                Text("分段导航")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Menu {
                    Button("打开地图导航（高德）") { showMap.toggle() }
                    Button("打开AR导航") { openAR() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            if isLoading {
                VStack {
                    ProgressView("加载路线数据...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if let error = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("加载失败")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if routeSegments.isEmpty {
                VStack {
                    Image(systemName: "map")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("暂无路线数据")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 路线信息卡片
                VStack(spacing: 16) {
                    // 当前路段信息
                    RouteSegmentCard(
                        segment: routeSegments[currentSegmentIndex],
                        isCurrent: true
                    )
                    
                    // 导航控制
                    HStack(spacing: 20) {
                        Button(action: previousSegment) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(currentSegmentIndex > 0 ? .blue : .gray)
                        }
                        .disabled(currentSegmentIndex <= 0)
                        
                        VStack {
                            Text("\(currentSegmentIndex + 1) / \(routeSegments.count)")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("路段")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: nextSegment) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                                .foregroundColor(currentSegmentIndex < routeSegments.count - 1 ? .blue : .gray)
                        }
                        .disabled(currentSegmentIndex >= routeSegments.count - 1)
                    }
                    .padding()
                    
                    // 路线预览列表
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(routeSegments.enumerated()), id: \.offset) { index, segment in
                                RouteSegmentCard(
                                    segment: segment,
                                    isCurrent: index == currentSegmentIndex
                                )
                                .onTapGesture {
                                    currentSegmentIndex = index
                                    loadRouteData(for: index)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .onAppear {
            loadRouteSegments()
            NotificationCenter.default.addObserver(forName: NSNotification.Name("OpenARNavigation"), object: nil, queue: .main) { _ in
                openAR()
            }
        }
        .sheet(isPresented: $showMap) {
            if !currentRouteData.isEmpty {
                MapView(
                    isExpanded: .constant(true),
                    isShowingProfile: .constant(false),
                    destinationLocation: .constant(nil),
                    routeCoordinates: currentRouteData,
                    selectedPlaceIndex: .constant(0),
                    startCoordinateBinding: .constant(nil),
                    isNavigationMode: .constant(false)
                )
            }
        }
    }
    
    // 打开 AR 导航（把当前段坐标传入占位 AR 视图）
    private func openAR() {
        // 使用当前段的终点作为 AR 目的地；若无则使用起点；若都无则不弹出
        guard let dest = currentRouteData.last ?? currentRouteData.first else { return }
        let vc = UIHostingController(rootView: ARNavigationView(destination: dest))
        UIApplication.shared.windows.first?.rootViewController?.present(vc, animated: true)
    }
    
    // 加载路线分段数据
    private func loadRouteSegments() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let endpoint = "http://192.168.3.39:8000/route-locations/get.json"
                guard let url = URL(string: endpoint) else {
                    throw QianwenError.invalidURL
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw QianwenError.invalidResponse
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success,
                   let dataDict = json["data"] as? [String: Any],
                   let locations = dataDict["locations"] as? String {
                    
                    // 解析地点并创建分段
                    let locationNames = locations.components(separatedBy: "--")
                    var segments: [RouteSegment] = []
                    
                    for i in 0..<locationNames.count - 1 {
                        let segment = RouteSegment(
                            index: i,
                            fromLocation: locationNames[i],
                            toLocation: locationNames[i + 1],
                            routeData: nil
                        )
                        segments.append(segment)
                    }
                    
                    DispatchQueue.main.async {
                        self.routeSegments = segments
                        self.isLoading = false
                        if !segments.isEmpty {
                            self.loadRouteData(for: 0)
                        }
                    }
                } else {
                    throw QianwenError.invalidResponse
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    // 加载指定分段的路线数据
    private func loadRouteData(for segmentIndex: Int) {
        guard segmentIndex < routeSegments.count else { return }
        
        Task {
            do {
                let endpoint = "http://192.168.3.39:8000/route-segments/get.json"
                guard let url = URL(string: endpoint) else {
                    throw QianwenError.invalidURL
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let body: [String: Any] = [
                    "conversationId": conversationId,
                    "segmentIndex": segmentIndex
                ]
                
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw QianwenError.invalidResponse
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success,
                   let dataDict = json["data"] as? [String: Any],
                   let routeData = dataDict["routeData"] as? [String: Any] {
                    
                    // 解析路线坐标数据
                    let coordinates = parseRouteCoordinates(from: routeData)
                    
                    DispatchQueue.main.async {
                        self.currentRouteData = coordinates
                        // 更新对应分段的路线数据
                        if segmentIndex < self.routeSegments.count {
                            self.routeSegments[segmentIndex].routeData = routeData
                        }
                    }
                }
            } catch {
                print("加载路线数据失败: \(error)")
            }
        }
    }
    
    // 解析路线坐标
    private func parseRouteCoordinates(from routeData: [String: Any]) -> [CLLocationCoordinate2D] {
        // 这里需要根据高德地图API返回的数据结构来解析坐标
        // 暂时返回空数组，实际实现需要根据API响应格式调整
        return []
    }
    
    // 上一个分段
    private func previousSegment() {
        if currentSegmentIndex > 0 {
            currentSegmentIndex -= 1
            loadRouteData(for: currentSegmentIndex)
        }
    }
    
    // 下一个分段
    private func nextSegment() {
        if currentSegmentIndex < routeSegments.count - 1 {
            currentSegmentIndex += 1
            loadRouteData(for: currentSegmentIndex)
        }
    }
}

// 路线分段数据模型
struct RouteSegment {
    let index: Int
    let fromLocation: String
    let toLocation: String
    var routeData: [String: Any]?
}

// 路线分段卡片视图
struct RouteSegmentCard: View {
    let segment: RouteSegment
    let isCurrent: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("路段 \(segment.index + 1)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isCurrent {
                    Text("当前")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("起点")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(segment.fromLocation)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.blue)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("终点")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(segment.toLocation)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrent ? Color.blue.opacity(0.1) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrent ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    SegmentedRouteView(conversationId: 1)
}
