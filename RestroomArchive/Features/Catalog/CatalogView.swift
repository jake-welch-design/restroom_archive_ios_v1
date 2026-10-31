#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

public struct CatalogView: View {
    @Environment(AppState.self) private var appState

    public init() {}

    public var body: some View {
        let rows = appState.visibleRestrooms

        VStack(spacing: 0) {
            CatalogHeaderView()

            if appState.isLoadingCatalog && appState.restrooms.isEmpty {
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(ArchiveColor.ink)
                    Text("Loading catalog…")
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = appState.catalogError, appState.restrooms.isEmpty {
                VStack(spacing: 12) {
                    Text(error)
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.danger)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await appState.refreshCatalog(selectFirstIfEmpty: true) }
                    }
                    .buttonStyle(ArchiveOutlineButtonStyle())
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if rows.isEmpty {
                VStack(spacing: 10) {
                    Text("No restrooms match your current search or filters.")
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.muted)
                    Button("Reset Filters") {
                        appState.clearAllFilters()
                    }
                    .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch appState.viewMode {
                case .list:
                    CatalogListView(rows: rows)
                case .grid:
                    CatalogGridView(rows: rows)
                case .map:
                    ArchiveMapView(rows: rows)
                }
            }
        }
        .background(ArchiveColor.paper)
    }
}
#endif

