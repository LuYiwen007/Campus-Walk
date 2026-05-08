import SwiftUI
import CoreLocation

/// 社区帖子详情（对齐原型 `PostDetail.tsx`：全宽头图、圆形返回、作者行、蓝色关注、底部分隔互动条）
struct PostDetailView: View {
    let post: CommunityPostItem
    var routeCoordinates: [CLLocationCoordinate2D] = []
    @Environment(\.dismiss) private var dismiss

    private var authorInitial: String {
        String(post.authorName.prefix(1))
    }

    var body: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                coverImageBlock
                    .frame(height: 384)
                    .frame(maxWidth: .infinity)
                    .clipped()

                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.33))
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(red: 0.88, green: 0.89, blue: 0.91), lineWidth: 1))
                }
                .padding(.top, 56)
                .padding(.leading, 16)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    authorAvatar

                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.authorName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.15))
                        Text("来自社区")
                            .font(.system(size: 12))
                            .foregroundStyle(CampusWalkUITheme.textMuted)
                    }

                    Spacer()

                    Button(action: {}) {
                        Text("关注")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(CampusWalkUITheme.brandBlue)
                            .clipShape(RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerPill, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)

                Text(post.title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.15))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
                    .padding(.top, 24)

                Text(post.body)
                    .font(.system(size: 15))
                    .foregroundStyle(CampusWalkUITheme.textSecondary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)

                HStack(spacing: 28) {
                    PostInteractionPill(icon: "heart.fill", count: post.likes, emphasized: true)
                    PostInteractionPill(icon: "bubble.right", count: 0, emphasized: false)
                    PostInteractionPill(icon: "star", count: 0, emphasized: false)
                    Spacer(minLength: 0)
                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(CampusWalkUITheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .padding(.bottom, 40)
            }
            .background(Color.white)
        }
        .background(Color.white)
        .ignoresSafeArea(edges: .top)
    }

    @ViewBuilder
    private var coverImageBlock: some View {
        AsyncImage(url: URL(string: post.coverImageURL)) { phase in
            switch phase {
            case .empty:
                Color.gray.opacity(0.15)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                Color.gray.opacity(0.2)
                    .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.tertiary))
            @unknown default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var authorAvatar: some View {
        AsyncImage(url: URL(string: post.authorAvatarURL)) { img in
            img.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Text(authorInitial)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CampusWalkUITheme.brandBlue)
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }
}

private struct PostInteractionPill: View {
    let icon: String
    let count: Int
    let emphasized: Bool

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                Text("\(count)")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(emphasized ? CampusWalkUITheme.brandBlue : CampusWalkUITheme.textMuted)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PostDetailView(
        post: CommunityPostItem(
            id: 1,
            title: "黄渤岛观行程",
            body: "这是我这个月在山上拍摄看最喜欢的一张...在这样的风景和空气里，整个人都觉得神清气爽。推荐大家有机会一定要来看看！",
            coverImageURL: "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&h=500&fit=crop",
            authorName: "黄渤明霞",
            authorAvatarURL: "https://picsum.photos/200/200",
            likes: 1250
        )
    )
}
