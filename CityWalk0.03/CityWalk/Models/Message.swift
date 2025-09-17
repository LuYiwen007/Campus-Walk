import Foundation

struct Message: Identifiable {
    let id = UUID()
    var content: String
    let isUser: Bool
    let timestamp: Date
    var isRouteRecommendation: Bool = false
    var imageData: Data? = nil
    var options: [String]? = nil
}