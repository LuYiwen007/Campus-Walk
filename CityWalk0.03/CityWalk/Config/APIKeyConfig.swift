import Foundation

// API Key配置管理
struct APIKeyConfig {
    // 开发者1的API Key
    static let developer1Key = "4c6e7aa728f408e1fc754200f5bed2e4"
    
    // 开发者2的API Key  
    static let developer2Key = "ea6ffe534577fb90a8ce52a72c0aa121"
    
    // 当前使用的API Key（可以根据需要切换）
    static var currentKey: String {
        // 可以通过环境变量、配置文件或其他方式来决定使用哪个Key
        // 这里默认使用开发者1的Key，你可以根据需要修改
        return developer1Key
        
        // 如果需要使用开发者2的Key，可以改为：
        // return developer2Key
    }
    
    // 获取当前API Key的便捷方法
    static func getCurrentAPIKey() -> String {
        return currentKey
    }
}
