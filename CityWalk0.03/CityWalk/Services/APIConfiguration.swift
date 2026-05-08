import Foundation

/// 后端基地址：模拟器连本机用 127.0.0.1；真机请改为电脑的局域网 IP，上服务器时改为 HTTPS 域名。
enum APIConfiguration {
    /// 与后端默认端口一致：`PythonProject`（uvicorn）或仓库根目录 `backend`（Spring Boot），见 `application.yml` 的 `API_PORT`
    static var baseURL: String {
        #if targetEnvironment(simulator)
        return "http://127.0.0.1:8081"
        #else
        // 真机调试：改为你电脑的局域网 IP + 与后端一致的端口，例如 http://192.168.3.39:8081
        return "http://192.168.3.39:8081"
        #endif
    }
}
