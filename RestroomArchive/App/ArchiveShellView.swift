#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

public struct ArchiveShellView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Bottom-anchored sheet height fraction on compact (iPhone portrait) layouts.
    /// Matches the locked-in UX decision: 3D stage on top, bottom-anchored draggable sheet below.
    private static let collapsedFraction: CGFloat = 0.13
    private static let defaultFraction: CGFloat = 0.55
    private static let expandedFraction: CGFloat = 0.86
    private static let pushCutoffFraction: CGFloat = 0.58

    @State private var sheetFraction: CGFloat = Self.defaultFraction
    @State private var dragStartFraction: CGFloat?

    public init() {}

    public var body: some View {
        @Bindable var state = appState

        GeometryReader { geo in
            let isSideBySide = horizontalSizeClass == .regular && geo.size.width >= 740

            ZStack(alignment: .top) {
                if isSideBySide {
                    regularSplitLayout(totalSize: geo.size)
                } else {
                    compactBottomSheetLayout(totalSize: geo.size)
                }

                if let banner = appState.globalBannerMessage {
                    Text(banner)
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.paper)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(ArchiveColor.ink)
                        .overlay(Rectangle().stroke(ArchiveColor.paper.opacity(0.45), lineWidth: 1))
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(50)
                }
            }
        }
        .background(ArchiveColor.stageBackground)
        .alert("Discard unsaved scan?", isPresented: $state.showUnsavedSubmissionAlert) {
            Button("Keep Editing", role: .cancel) {
                appState.pendingTabAfterDiscardAlert = nil
            }
            Button("Discard", role: .destructive) {
                appState.confirmDiscardUnsavedSubmissionAndSwitch()
            }
        } message: {
            Text("Leaving the Submit wizard will clear your loaded preview scan. Tip: Tap 'Save Draft' first if you want to finish later.")
        }
    }

    // MARK: - iPad / Landscape Side-by-Side Split Layout

    private func regularSplitLayout(totalSize: CGSize) -> some View {
        let leftWidth = min(max(totalSize.width * 0.44, 380), 520)

        return HStack(spacing: 0) {
            VStack(spacing: 0) {
                topNavHeader
                activePanelContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: leftWidth)
            .background(ArchiveColor.paper)
            .overlay(alignment: .trailing) {
                Rectangle().fill(ArchiveColor.ink).frame(width: 1)
            }

            ZStack {
                ArchiveStageView(controller: appState.stageController)
                ViewerControlsOverlay()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ArchiveColor.stageBackground)
        }
    }

    // MARK: - iPhone Bottom-Anchored Sheet Layout

    private func compactBottomSheetLayout(totalSize: CGSize) -> some View {
        let totalH = max(totalSize.height, 1)
        let currentSheetH = totalH * sheetFraction
        // Below `pushCutoffFraction`, the 3D stage resizes cleanly above the sheet ("push zone").
        // Above `pushCutoffFraction`, the stage freezes at `(1 - pushCutoffFraction)` height while the sheet slides over it ("overlay zone").
        let stageHeight = totalH * (1.0 - min(sheetFraction, Self.pushCutoffFraction))
        let isCollapsed = sheetFraction <= (Self.collapsedFraction + 0.05)

        return ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                ZStack {
                    ArchiveStageView(controller: appState.stageController)
                    ViewerControlsOverlay()
                }
                .frame(width: totalSize.width, height: max(stageHeight, 120))
                .background(ArchiveColor.stageBackground)

                Spacer(minLength: 0)
            }

            VStack(spacing: 0) {
                sheetGrabberBar(totalHeight: totalH, isCollapsed: isCollapsed)

                if isCollapsed {
                    collapsedQuickStepBar
                } else {
                    topNavHeader
                    activePanelContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: totalSize.width, height: currentSheetH)
            .background(ArchiveColor.paper)
            .overlay(alignment: .top) {
                Rectangle().fill(ArchiveColor.ink).frame(height: 1)
            }
        }
    }

    private func sheetGrabberBar(totalHeight: CGFloat, isCollapsed: Bool) -> some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(ArchiveColor.ink.opacity(0.35))
                .frame(width: 38, height: 3)
            Spacer()
        }
        .frame(height: 20)
        .background(ArchiveColor.paper)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                sheetFraction = isCollapsed ? Self.defaultFraction : Self.collapsedFraction
            }
        }
        .gesture(
            DragGesture(minimumDistance: 3, coordinateSpace: .global)
                .onChanged { value in
                    let base = dragStartFraction ?? sheetFraction
                    if dragStartFraction == nil {
                        dragStartFraction = sheetFraction
                    }
                    let delta = -value.translation.height / max(totalHeight, 1)
                    sheetFraction = min(
                        Self.expandedFraction,
                        max(Self.collapsedFraction, base + delta)
                    )
                }
                .onEnded { value in
                    let base = dragStartFraction ?? sheetFraction
                    dragStartFraction = nil
                    let projectedDelta = -value.predictedEndTranslation.height / max(totalHeight, 1)
                    let projected = base + projectedDelta
                    let detents = [Self.collapsedFraction, Self.defaultFraction, Self.expandedFraction]
                    let nearest = detents.min(by: { abs($0 - projected) < abs($1 - projected) }) ?? Self.defaultFraction
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        sheetFraction = nearest
                    }
                }
        )
    }

    private var collapsedQuickStepBar: some View {
        HStack(spacing: 10) {
            Button("← Prev") {
                appState.stepSelection(delta: -1)
            }
            .buttonStyle(ArchiveOutlineButtonStyle(compact: true))

            VStack(spacing: 1) {
                Text(appState.selectedRestroom?.name ?? "The Restroom Archive")
                    .font(ArchiveFont.bold(12.5))
                    .foregroundStyle(ArchiveColor.ink)
                    .lineLimit(1)
                if let loc = appState.selectedRestroom?.location {
                    Text(loc)
                        .font(ArchiveFont.regular(10.5))
                        .foregroundStyle(ArchiveColor.muted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    sheetFraction = Self.defaultFraction
                }
            }

            Button("Next →") {
                appState.stepSelection(delta: 1)
            }
            .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(ArchiveColor.paper)
    }

    // MARK: - Top Navigation Header & Active Panel

    private var topNavHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Button {
                    appState.requestTabSwitch(.catalog)
                } label: {
                    Text("THE RESTROOM ARCHIVE")
                        .font(ArchiveFont.bold(12))
                        .tracking(0.6)
                        .foregroundStyle(ArchiveColor.ink)
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 12) {
                    ForEach(appState.availableTabs, id: \.self) { tab in
                        let active = appState.activeTab == tab
                        Button {
                            appState.requestTabSwitch(tab)
                        } label: {
                            HStack(spacing: 3) {
                                Text(tab.label)
                                    .font(active ? ArchiveFont.bold(12) : ArchiveFont.regular(12))
                                    .foregroundStyle(active ? ArchiveColor.ink : ArchiveColor.muted)
                                    .underline(active)

                                if tab == .admin && appState.totalAdminActionCount > 0 {
                                    Text("\(appState.totalAdminActionCount)")
                                        .font(ArchiveFont.bold(9.5))
                                        .foregroundStyle(ArchiveColor.paper)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(ArchiveColor.danger)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(ArchiveColor.paper)
        .overlay(alignment: .bottom) {
            Rectangle().fill(ArchiveColor.ink).frame(height: 1)
        }
    }

    @ViewBuilder
    private var activePanelContent: some View {
        switch appState.activeTab {
        case .catalog:
            CatalogView()
        case .submit:
            SubmitWizardView()
        case .account:
            AccountRootView()
        case .admin:
            AdminRootView()
        case .info:
            InfoView()
        }
    }
}
#endif

