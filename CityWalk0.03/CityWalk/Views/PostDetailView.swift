import SwiftUI
import CoreLocation

struct PostDetailView: View {
    let post: CommunityPostItem
    // 可选：路线坐标
    var routeCoordinates: [CLLocationCoordinate2D] = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 顶部图片
                GeometryReader { geometry in
                    Image(post.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: 280)
                        .clipped()
                }
                .frame(height: 280)
                
                // 内容区域
                VStack(spacing: 0) {
                    // 用户信息栏
                    HStack(spacing: 12) {
                        Image(post.authorImageName)
                            .resizable()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.authorName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("2小时前")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Text("关注")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    LinearGradient(
                                        colors: [Color.pink, Color.orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // 标题
                    VStack(alignment: .leading, spacing: 12) {
                        Text("米亚罗风景区太后悔了！！！")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("后悔没早点来！米亚罗风景区真的真的真的太太太漂亮了！稻城亚丁雪山景平替，再也不用去那么远就能看到雪山了。")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // 攻略内容
                    VStack(alignment: .leading, spacing: 20) {
                        // 景点介绍
                        ContentSection(
                            icon: "📍",
                            title: "景点介绍",
                            content: "米亚罗，藏语意为\"好玩的坝子\"，位于四川省阿坝藏族羌族自治州理县境内，是中国最大的红叶风景区之一。每到秋天，这里的红叶如火，层林尽染，美不胜收。"
                        )
                        
                        // 交通指南
                        ContentSection(
                            icon: "🚗",
                            title: "交通指南",
                            content: "导航直接搜猛古村，到了之后分徒步和开车上山两种方式。徒步单边大概3小时，开车约40分钟。进山费用20元/人，需签协议书。山路较颠簸，建议SUV或越野车。"
                        )
                        
                        // 住宿推荐
                        ContentSection(
                            icon: "🏠",
                            title: "住宿推荐",
                            content: "猛古村住宿选择较少，建议前往米亚罗镇，从客栈到酒店应有尽有。旺季建议提前在网上预订。"
                        )
                        
                        // 美食贴士
                        ContentSection(
                            icon: "🍽️",
                            title: "美食贴士",
                            content: "进山后无餐厅，请自备食物和水。猛古村有小卖部，但商品有限。建议提前准备充足的食物。"
                        )
                        
                                                 // 温馨提示
                         VStack(alignment: .leading, spacing: 8) {
                             HStack(spacing: 8) {
                                 Text("💡")
                                     .font(.system(size: 16))
                                 Text("温馨提示")
                                     .font(.system(size: 16, weight: .semibold))
                                     .foregroundColor(.orange)
                             }
                             Text("米亚罗地处高海拔地区，气候多变，请务必带上足够的衣物以应对可能的低温天气。")
                                 .font(.system(size: 15))
                                 .foregroundColor(.secondary)
                                 .padding(.leading, 24)
                                 .fixedSize(horizontal: false, vertical: true)
                         }
                         .padding(.horizontal, 16)
                         .padding(.vertical, 12)
                         .background(Color.orange.opacity(0.1))
                         .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    
                    // 互动区域
                    HStack(spacing: 32) {
                        InteractionButton(icon: "heart", count: post.likes, color: .pink)
                        InteractionButton(icon: "bubble.right", count: 44, color: .blue)
                        InteractionButton(icon: "star", count: 208, color: .orange)
                        Spacer()
                        Button(action: {}) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                    .padding(.bottom, 40)
                }
                .background(Color(.systemBackground))
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .offset(y: -20)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color(.systemGroupedBackground))
    }
}

// 内容区块组件
struct ContentSection: View {
    let icon: String
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            Text(content)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .lineSpacing(3)
                .padding(.leading, 24)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// 互动按钮组件
struct InteractionButton: View {
    let icon: String
    let count: Int
    let color: Color
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text("\(count)")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(color)
        }
    }
}

// 预览
struct PostDetailView_Previews: PreviewProvider {
    static var previews: some View {
        PostDetailView(post: CommunityPostItem(imageName: "miya_luo_cover", title: "米亚罗霸王山2日", authorName: "浪迹川西", authorImageName: "avatar_langjichuanxi", likes: 45))
    }
} 