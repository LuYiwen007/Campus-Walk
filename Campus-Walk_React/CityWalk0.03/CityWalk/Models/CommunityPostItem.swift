import Foundation

/// 社区帖子（由后端 `GET /api/v1/community/posts` 填充）
struct CommunityPostItem: Identifiable, Equatable, Hashable {
    let id: Int
    let title: String
    let body: String
    let coverImageURL: String
    let authorName: String
    let authorAvatarURL: String
    let likes: Int

    static func from(dto: CommunityPostDTO) -> CommunityPostItem {
        CommunityPostItem(
            id: dto.id,
            title: dto.title,
            body: dto.body,
            coverImageURL: dto.coverImageUrl,
            authorName: dto.authorDisplayName,
            authorAvatarURL: dto.authorAvatarUrl,
            likes: dto.likesCount
        )
    }
}
