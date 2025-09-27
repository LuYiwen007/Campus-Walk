import UIKit
import MAMapKit
import AMapSearchKit

class NavigationViewController: UIViewController {
    let mapView = MAMapView()
    var search: AMapSearchAPI?
    var currentRoute: AMapRouteSearchResponse?
    
    // 保留的社区和历史路线数据（不删除）
    let communityRoutes: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 23.128, longitude: 113.244),      // 恒宝广场
        CLLocationCoordinate2D(latitude: 23.114778, longitude: 113.237434),// 广州永庆坊
        CLLocationCoordinate2D(latitude: 23.13, longitude: 113.25),        // 陈家祠堂
        CLLocationCoordinate2D(latitude: 23.109819, longitude: 113.242222),// 沙面岛
        CLLocationCoordinate2D(latitude: 23.115, longitude: 113.26),       // 石室圣心大教堂
        CLLocationCoordinate2D(latitude: 23.118, longitude: 113.263)       // 赵记传承
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
        setupSearch()
        setupButton()
        showCommunityRoutes()
    }
    
    func setupSearch() {
        search = AMapSearchAPI()
        search?.delegate = self
    }

    func setupMapView() {
        mapView.frame = view.bounds
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)
        mapView.zoomLevel = 16
        mapView.delegate = self
    }

    func setupButton() {
        let button = UIButton(type: .system)
        button.setTitle("开始导航", for: .normal)
        button.addTarget(self, action: #selector(startNavigation), for: .touchUpInside)
        button.frame = CGRect(x: 40, y: view.bounds.height - 100, width: 200, height: 50)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
        view.addSubview(button)
    }

    @objc func startNavigation() {
        // 使用高德地图搜索API计算步行路线
        calculateWalkingRoute()
    }
    
    func calculateWalkingRoute() {
        guard let search = search else { return }
        
        // 计算从第一个点到最后一个点的步行路线
        let start = communityRoutes.first!
        let end = communityRoutes.last!
        
        let request = AMapWalkingRouteSearchRequest()
        request.origin = AMapGeoPoint.location(withLatitude: CGFloat(start.latitude), 
                                             longitude: CGFloat(start.longitude))
        request.destination = AMapGeoPoint.location(withLatitude: CGFloat(end.latitude), 
                                                   longitude: CGFloat(end.longitude))
        request.showFieldsType = AMapWalkingRouteShowFieldType.all
        
        search.aMapWalkingRouteSearch(request)
    }
    
    func showCommunityRoutes() {
        // 显示社区路线点
        for (index, coord) in communityRoutes.enumerated() {
            let annotation = MAPointAnnotation()
            annotation.coordinate = coord
            annotation.title = "景点 \(index + 1)"
            mapView.addAnnotation(annotation)
        }
        
        // 设置地图中心为第一个点
        if let firstCoord = communityRoutes.first {
            mapView.setCenter(firstCoord, animated: true)
        }
    }
}

extension NavigationViewController: MAMapViewDelegate {
    func mapView(_ mapView: MAMapView!, rendererFor overlay: MAOverlay!) -> MAOverlayRenderer! {
        if let polyline = overlay as? MAPolyline {
            let renderer = MAPolylineRenderer(polyline: polyline)
            renderer?.strokeColor = UIColor.systemBlue
            renderer?.lineWidth = 5
            return renderer
        }
        return nil
    }
    
    func mapView(_ mapView: MAMapView!, viewFor annotation: MAAnnotation!) -> MAAnnotationView! {
        if annotation is MAPointAnnotation {
            let identifier = "pointAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MAPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            }
            annotationView?.canShowCallout = true
            return annotationView
        }
        return nil
    }
}

// MARK: - AMapSearchDelegate
extension NavigationViewController: AMapSearchDelegate {
    func onRouteSearchDone(_ request: AMapRouteSearchBaseRequest!, response: AMapRouteSearchResponse!) {
        guard let path = response.route.paths.first else {
            print("步行路线计算失败")
            return
        }
        
        print("步行路线计算成功")
        currentRoute = response
        
        // 清除旧路线
        mapView.removeOverlays(mapView.overlays)
        
        // 绘制新路线
        if let steps = path.steps as? [AMapStep] {
            var coordinates: [CLLocationCoordinate2D] = []
            
            for step in steps {
                let polylineStr = step.polyline
                let points = polylineStr?.split(separator: ";").compactMap { pair -> CLLocationCoordinate2D? in
                    let comps = pair.split(separator: ",")
                    if comps.count == 2, let lon = Double(comps[0]), let lat = Double(comps[1]) {
                        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    }
                    return nil
                } ?? []
                coordinates.append(contentsOf: points)
            }
            
            if !coordinates.isEmpty {
                let polyline = MAPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
                mapView.add(polyline)
                print("步行路线已绘制，点数：\(coordinates.count)")
            }
        }
    }
} 