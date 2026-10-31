#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

public struct CatalogListView: View {
    @Environment(AppState.self) private var appState
    let rows: [RestroomSummary]

    public init(rows: [RestroomSummary]) {
        self.rows = rows
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(rows) { entry in
                            let isSelected = appState.selectedSlug == entry.slug
                            VStack(alignment: .leading, spacing: 0) {
                                Button {
                                    appState.selectRestroom(slug: entry.slug)
                                } label: {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(entry.name)
                                            .font(isSelected ? ArchiveFont.bold(13) : ArchiveFont.regular(13))
                                            .foregroundStyle(ArchiveColor.ink)
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Text(entry.location)
                                            .font(ArchiveFont.regular(12))
                                            .foregroundStyle(ArchiveColor.muted)
                                            .lineLimit(1)
                                            .frame(width: 112, alignment: .leading)

                                        Text(trailingMetric(for: entry))
                                            .font(ArchiveFont.mono(11))
                                            .foregroundStyle(ArchiveColor.muted)
                                            .lineLimit(1)
                                            .frame(width: 82, alignment: .trailing)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(isSelected ? ArchiveColor.subtleFill : ArchiveColor.paper)
                                    .overlay(alignment: .leading) {
                                        if isSelected {
                                            Rectangle()
                                                .fill(ArchiveColor.ink)
                                                .frame(width: 3)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if isSelected {
                                    EntryDetailBlockView(entry: entry)
                                        .padding(.horizontal, 14)
                                        .padding(.bottom, 6)
                                        .background(ArchiveColor.hoverFill)
                                }

                                Rectangle()
                                    .fill(ArchiveColor.rowRule)
                                    .frame(height: 1)
                            }
                            .id(entry.slug)
                        }
                    } header: {
                        columnHeaderBar
                    }
                }
            }
            .onChange(of: appState.selectedSlug) { _, newSlug in
                if let newSlug {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        proxy.scrollTo(newSlug, anchor: .top)
                    }
                }
            }
        }
    }

    private var columnHeaderBar: some View {
        HStack(spacing: 8) {
            sortHeaderButton(field: .name, title: "Name", alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            sortHeaderButton(field: .location, title: "Location", alignment: .leading)
                .frame(width: 112, alignment: .leading)

            if appState.sortField == .distance && appState.locationService.currentCoordinate != nil {
                sortHeaderButton(field: .distance, title: "Distance", alignment: .trailing)
                    .frame(width: 82, alignment: .trailing)
            } else {
                sortHeaderButton(field: .date, title: "Date", alignment: .trailing)
                    .frame(width: 82, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(ArchiveColor.paper)
        .overlay(alignment: .bottom) {
            Rectangle().fill(ArchiveColor.ink).frame(height: 1)
        }
    }

    private func sortHeaderButton(field: CatalogSortField, title: String, alignment: Alignment) -> some View {
        let active = appState.sortField == field
        let arrow = active ? (appState.sortDirection == .asc ? " ↑" : " ↓") : ""
        return Button {
            if appState.sortField == field {
                appState.sortDirection.toggle()
            } else {
                appState.sortField = field
                appState.sortDirection = (field == .date) ? .desc : .asc
            }
        } label: {
            Text("\(title)\(arrow)")
                .font(active ? ArchiveFont.bold(11) : ArchiveFont.regular(11))
                .foregroundStyle(active ? ArchiveColor.ink : ArchiveColor.muted)
                .frame(maxWidth: .infinity, alignment: alignment)
        }
        .buttonStyle(.plain)
    }

    private func trailingMetric(for entry: RestroomSummary) -> String {
        if appState.sortField == .distance,
           let origin = appState.locationService.currentCoordinate,
           let meters = CatalogFiltering.distanceMeters(from: origin, to: entry) {
            return CatalogFiltering.formatDistance(meters)
        }
        return ArchiveDateFormatter.formatDayMonthYear(entry.isoDate)
    }
}
#endif

