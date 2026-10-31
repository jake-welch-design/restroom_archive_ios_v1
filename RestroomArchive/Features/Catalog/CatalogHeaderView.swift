#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

public struct CatalogHeaderView: View {
    @Environment(AppState.self) private var appState
    @State private var showTagDrawer: Bool = false

    public init() {}

    public var body: some View {
        @Bindable var state = appState
        let tagCounts = CatalogFiltering.allDescriptorCounts(in: appState.restrooms)

        VStack(alignment: .leading, spacing: 8) {
            // Row 1: Search input + Tag filter toggle + Date filter menu
            HStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(ArchiveColor.muted)

                    TextField("Search name, city, decor, tag…", text: $state.searchQuery)
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.ink)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if !appState.searchQuery.isEmpty {
                        Button {
                            appState.searchQuery = ""
                        } label: {
                            Text("×")
                                .font(ArchiveFont.regular(15))
                                .foregroundStyle(ArchiveColor.muted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(ArchiveColor.paper)
                .overlay(Rectangle().stroke(ArchiveColor.inputBorder, lineWidth: 1))

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showTagDrawer.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Tags")
                        if !appState.selectedTags.isEmpty {
                            Text("\(appState.selectedTags.count)")
                                .font(ArchiveFont.bold(10))
                        }
                    }
                }
                .buttonStyle(
                    ArchiveOutlineButtonStyle(
                        active: showTagDrawer || !appState.selectedTags.isEmpty,
                        compact: true
                    )
                )

                Menu {
                    ForEach(DateRangePreset.allCases, id: \.self) { preset in
                        Button {
                            appState.datePreset = preset
                        } label: {
                            HStack {
                                Text(preset.label)
                                if appState.datePreset == preset {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text(appState.datePreset == .all ? "Date" : appState.datePreset.label)
                        .font(ArchiveFont.regular(11))
                        .lineLimit(1)
                        .foregroundStyle(appState.datePreset == .all ? ArchiveColor.ink : ArchiveColor.paper)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(appState.datePreset == .all ? ArchiveColor.paper : ArchiveColor.ink)
                        .overlay(Rectangle().stroke(ArchiveColor.ink, lineWidth: 1))
                }
            }

            // Row 2: View mode (List | Grid | Map), Near Me GPS sort, Random entry, count
            HStack(spacing: 6) {
                ArchiveSegmentedBar(
                    items: CatalogViewMode.allCases.map { .init(id: $0, label: $0.label) },
                    selection: $state.viewMode
                )
                .frame(maxWidth: 185)

                Button {
                    Task { await appState.sortCatalogByNearMe() }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: appState.locationService.isLocating ? "location.fill" : "location")
                            .font(.system(size: 10))
                        Text("Near Me")
                    }
                }
                .buttonStyle(
                    ArchiveOutlineButtonStyle(
                        active: appState.sortField == .distance,
                        compact: true
                    )
                )

                Button("Random") {
                    appState.selectRandomRestroom()
                }
                .buttonStyle(ArchiveOutlineButtonStyle(compact: true))

                Spacer(minLength: 4)

                Text("\(appState.visibleRestrooms.count)")
                    .font(ArchiveFont.mono(11))
                    .foregroundStyle(ArchiveColor.muted)
                    .accessibilityLabel("\(appState.visibleRestrooms.count) entries")
            }

            // Active tag pills strip when drawer is closed
            if !showTagDrawer && !appState.selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(appState.selectedTags.sorted(), id: \.self) { tag in
                            Button {
                                appState.toggleTagFilter(tag)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(tag)
                                    Text("×")
                                }
                                .font(ArchiveFont.regular(11))
                                .foregroundStyle(ArchiveColor.paper)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(ArchiveColor.ink)
                            }
                            .buttonStyle(.plain)
                        }
                        Button("Clear") {
                            appState.selectedTags.removeAll()
                        }
                        .buttonStyle(ArchiveLinkButtonStyle())
                    }
                }
            }

            // Expandable descriptor filter drawer
            if showTagDrawer {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Filter by descriptors (matches all selected)")
                            .font(ArchiveFont.regular(11))
                            .foregroundStyle(ArchiveColor.muted)
                        Spacer()
                        if !appState.selectedTags.isEmpty {
                            Button("Clear tags") {
                                appState.selectedTags.removeAll()
                            }
                            .buttonStyle(ArchiveLinkButtonStyle())
                        }
                    }

                    if tagCounts.isEmpty {
                        Text("No descriptors indexed yet.")
                            .font(ArchiveFont.regular(11))
                            .foregroundStyle(ArchiveColor.muted)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 5) {
                                ForEach(tagCounts, id: \.tag) { item in
                                    let active = appState.selectedTags.contains(item.tag)
                                    Button {
                                        appState.toggleTagFilter(item.tag)
                                    } label: {
                                        Text("\(item.tag) (\(item.count))")
                                            .font(ArchiveFont.regular(11))
                                            .foregroundStyle(active ? ArchiveColor.paper : ArchiveColor.ink)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 4)
                                            .background(active ? ArchiveColor.ink : ArchiveColor.paper)
                                            .overlay(Rectangle().stroke(ArchiveColor.inputBorder, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(8)
                .background(ArchiveColor.hoverFill)
                .overlay(Rectangle().stroke(ArchiveColor.rule, lineWidth: 1))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ArchiveColor.paper)
        .overlay(alignment: .bottom) {
            Rectangle().fill(ArchiveColor.rule).frame(height: 1)
        }
    }
}
#endif

