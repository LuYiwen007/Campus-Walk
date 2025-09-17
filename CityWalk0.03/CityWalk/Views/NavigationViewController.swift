import UIKit
import MAMapKit

class NavigationViewController: UIViewController {
    let mapView = MAMapView()
    var navigationIndex = 0
    let mockCoords: [CLLocationCoordinate2D] = [
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
        setupButton()
        jumpToSegment(index: navigationIndex)
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
        button.setTitle("开始/继续导航", for: .normal)
        button.addTarget(self, action: #selector(nextSegment), for: .touchUpInside)
        button.frame = CGRect(x: 40, y: view.bounds.height - 100, width: 200, height: 50)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
        view.addSubview(button)
    }

    @objc func nextSegment() {
        if navigationIndex < mockCoords.count - 1 {
            navigationIndex += 1
            jumpToSegment(index: navigationIndex)
        }
    }

    func jumpToSegment(index: Int) {
        let coord = mockCoords[index]
        mapView.setCenter(coord, animated: true)
        // 清除旧路线，绘制新路线
        mapView.removeOverlays(mapView.overlays)
        if index < mockCoords.count - 1 {
            var coords = [coord, mockCoords[index + 1]]
            let polyline = MAPolyline(coordinates: &coords, count: 2)
            mapView.add(polyline)
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
} 