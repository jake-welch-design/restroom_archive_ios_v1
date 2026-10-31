#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

public struct CatalogGridView: View {
    @Environment(AppState.self) private var appState
    let rows: [RestroomSummary]

    private let columns = [
        GridItem(.adaptive(minimum: 155, maximum: 240), spacing: 10)
    ]

    public init(rows: [RestroomSummary]) {
        self.rows = rows
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let selected = appState.selectedRestroom,
                   rows.contains(where: { $0.slug == selected.slug }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(selected.name)
                                .font(ArchiveFont.bold(13))
                                .foregroundStyle(ArchiveColor.ink)
                            Spacer()
                            Text("\(selected.location) · \(ArchiveDateFormatter.formatDayMonthYear(selected.isoDate))")
                                .font(ArchiveFont.regular(11))
                                .foregroundStyle(ArchiveColor.muted)
                        }
                        EntryDetailBlockView(entry: selected)
                    }
                    .padding(12)
                    .background(ArchiveColor.hoverFill)
                    .overlay(Rectangle().stroke(ArchiveColor.ink, lineWidth: 1))
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(rows) { entry in
                        let isSelected = appState.selectedSlug == entry.slug
                        Button {
                            appState.selectRestroom(slug: entry.slug)
                        } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                AsyncCachedImage(
                                    remotePath: entry.thumbUrl,
                                    apiClient: appState.apiClient,
                                    diskCache: appState.diskCache,
                                    contentMode: .fill
                                ) {
                                    ZStack {
                                        Color.black
                                        Text("3D")
                                            .font(ArchiveFont.mono(11))
                                            .foregroundStyle(.white.opacity(0.45))
                                    }
                                }
                                .frame(height: 132)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .overlay(alignment: .bottom) {
                                    Rectangle().fill(ArchiveColor.ink).frame(height: 1)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name)
                                        .font(isSelected ? ArchiveFont.bold(12) : ArchiveFont.regular(12))
                                        .foregroundStyle(isSelected ? ArchiveColor.paper : ArchiveColor.ink)
                                        .lineLimit(1)

                                    HStack {
                                        Text(entry.location)
                                            .lineLimit(1)
                                        Spacer(minLength: 4)
                                        Text(ArchiveDateFormatter.formatDayMonthYear(entry.isoDate))
                                    }
                                    .font(ArchiveFont.regular(10.5))
                                    .foregroundStyle(isSelected ? ArchiveColor.paper.opacity(0.8) : ArchiveColor.muted)
                                }
                                .padding(8)
                                .background(isSelected ? ArchiveColor.ink : ArchiveColor.paper)
                            }
                            .overlay(
                                Rectangle()
                                    .stroke(ArchiveColor.ink, lineWidth: isSelected ? 2 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
        }
    }
}
#endif

