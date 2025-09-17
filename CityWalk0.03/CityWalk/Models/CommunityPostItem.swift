 import Foundation
 
 // 为帖子创建一个数据模型
struct CommunityPostItem: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
    let authorName: String
    let authorImageName: String
    let likes: Int
}