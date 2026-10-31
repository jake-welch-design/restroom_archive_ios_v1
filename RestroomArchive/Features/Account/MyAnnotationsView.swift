#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

public struct MyAnnotationsView: View {
    @Environment(AppState.self) private var appState

    @State private var items: [MyAnnotation] = []
    @State private var isLoading: Bool = true

    public init() {}

    public var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView().tint(ArchiveColor.ink)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                VStack(spacing: 8) {
                    Text("You haven't posted any spatial annotations yet.")
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.muted)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Button {
                                        appState.selectRestroom(slug: item.restroomSlug, initialAnnotationId: item.id)
                                        appState.requestTabSwitch(.catalog)
                                    } label: {
                                        Text(item.restroomName)
                                            .font(ArchiveFont.bold(12.5))
                                            .foregroundStyle(ArchiveColor.ink)
                                    }
                                    .buttonStyle(.plain)

                                    Spacer()

                                    Text(ArchiveDateFormatter.formatMonthDayYear(item.createdAt))
                                        .font(ArchiveFont.regular(11))
                                        .foregroundStyle(ArchiveColor.muted)
                                }

                                Text(item.body)
                                    .font(ArchiveFont.regular(12.5))
                                    .foregroundStyle(ArchiveColor.ink)

                                HStack(spacing: 14) {
                                    Button("Fly to Annotation →") {
                                        appState.selectRestroom(slug: item.restroomSlug, initialAnnotationId: item.id)
                                        appState.requestTabSwitch(.catalog)
                                    }
                                    .buttonStyle(ArchiveLinkButtonStyle())

                                    Button("Delete") {
                                        Task {
                                            try? await appState.apiClient.deleteAnnotation(
                                                slug: item.restroomSlug,
                                                annotationId: item.id
                                            )
                                            await reload()
                                        }
                                    }
                                    .font(ArchiveFont.regular(11))
                                    .foregroundStyle(ArchiveColor.danger)
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(ArchiveColor.rowRule).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
        .task { await reload() }
    }

    private func reload() async {
        isLoading = true
        items = (try? await appState.apiClient.fetchMyAnnotations()) ?? []
        isLoading = false
    }
}
#endif

