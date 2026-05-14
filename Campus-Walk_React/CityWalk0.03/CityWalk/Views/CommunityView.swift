import SwiftUI

/// 社区首页（对齐原型 `Home.tsx`：纵向卡片、细边框、大图 h-56 比例）
struct CommunityView: View {
    @State private var showMenu = false

    @State private var posts: [CommunityPostItem] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var selectedPost: CommunityPostItem?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white.ignoresSafeArea()

            if showMenu {
                HStack(spacing: 0) {
                    UserProfileView(isShowingProfile: $showMenu)
                        .frame(width: UIScreen.main.bounds.width * 0.7)
                        .background(Color(.systemBackground))
                        .ignoresSafeArea(edges: .top)
                        .transition(.move(edge: .leading))
                    Spacer(minLength: 0)
                }
                .background(
                    Color.black.opacity(0.18)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation { showMenu = false }
                        }
                )
                .ignoresSafeArea()
                .zIndex(2)
            }

            VStack(spacing: 0) {
                HStack {
                    Button {
                        withAnimation { showMenu = true }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(Color(red: 0.45, green: 0.48, blue: 0.52))
                    }
                    Spacer()
                    Text("社区")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.33))
                    Spacer()
                    Color.clear.frame(width: 28, height: 28)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)

                Rectangle()
                    .fill(CampusWalkUITheme.borderSubtle)
                    .frame(height: 1)

                if isLoading {
                    Spacer()
                    ProgressView("加载中…")
                    Spacer()
                } else if let err = loadError {
                    Spacer()
                    Text(err)
                        .foregroundStyle(CampusWalkUITheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 32) {
                            ForEach(posts) { post in
                                HomeStylePostCard(post: post)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedPost = post }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)
                        .padding(.bottom, 100)
                    }
                }
            }
            .sheet(item: $selectedPost) { post in
                PostDetailView(post: post)
            }
            .task {
                await loadPosts()
            }
        }
    }

    private func loadPosts() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let rows = try await APIClient.shared.communityPosts()
            posts = rows.map(CommunityPostItem.from(dto:))
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private struct HomeStylePostCard: View {
    let post: CommunityPostItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AsyncImage(url: URL(string: post.coverImageURL)) { phase in
                switch phase {
                case .empty:
                    Color.gray.opacity(0.12)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Color.gray.opacity(0.2)
                        .overlay(Image(systemName: "photo").foregroundStyle(.tertiary))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(height: 224)
            .clipped()

            VStack(alignment: .leading, spacing: 16) {
                Text(post.title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.15))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text(post.authorName)
                        .font(.system(size: 14))
                        .foregroundStyle(CampusWalkUITheme.textMuted)
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: 20) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart")
                                .font(.system(size: 14))
                            Text("\(post.likes)")
                                .font(.system(size: 14))
                        }
                        .foregroundStyle(CampusWalkUITheme.textMuted)

                        Image(systemName: "star")
                            .font(.system(size: 14))
                            .foregroundStyle(CampusWalkUITheme.textMuted)
                    }
                }
            }
            .padding(24)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CampusWalkUITheme.cornerCard, style: .continuous)
                .stroke(CampusWalkUITheme.borderSubtle, lineWidth: 1)
        )
    }
}
