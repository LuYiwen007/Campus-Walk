import SwiftUI

/// 展示后端返回的「路线一 / 二 / 三」详情（数据来自 API，无前端 mock）。
struct SegmentedRouteView: View {
    let conversationId: Int
    @Environment(\.dismiss) private var dismiss

    @State private var batch: RouteBatchDTO?
    @State private var isLoading = true
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("加载路线…")
                } else if let err = errorText {
                    Text(err).foregroundStyle(.secondary).multilineTextAlignment(.center).padding()
                } else if let batch, !batch.variants.isEmpty {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(batch.variants, id: \.self) { v in
                                variantCard(v)
                            }
                        }
                        .padding()
                    }
                } else {
                    Text("暂无路线数据")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("可选路线")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func variantCard(_ v: RouteVariantDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(v.displayLabel)
                .font(.headline)
            Text("\(v.startLabel) → \(v.endLabel)")
                .font(.subheadline.weight(.semibold))
            HStack {
                Label("\(v.estimatedDurationSeconds / 60) 分钟", systemImage: "clock")
                Spacer()
                Label("\(v.estimatedDistanceMeters) m", systemImage: "figure.walk")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text("途经景点（\(v.scenicSpotCount) 处）")
                .font(.caption.weight(.semibold))
            if !v.scenicSpotExamples.isEmpty {
                ForEach(v.scenicSpotExamples, id: \.self) { ex in
                    Text("· \(ex)")
                        .font(.caption)
                }
            }
            Text(v.description)
                .font(.footnote)
                .foregroundStyle(.primary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func load() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            batch = try await APIClient.shared.latestRouteBatch(conversationId: conversationId)
            if batch == nil {
                errorText = "当前会话还没有生成的路线，请先发送一条出行需求。"
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    SegmentedRouteView(conversationId: 1)
}
