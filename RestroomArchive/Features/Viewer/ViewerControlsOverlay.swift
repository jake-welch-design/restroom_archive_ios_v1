#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

public struct ViewerControlsOverlay: View {
    @Environment(AppState.self) private var appState
    @State private var composeText: String = ""
    @State private var isSubmittingAnnotation: Bool = false
    @State private var composeError: String?

    @State private var reportingAnnotation: Annotation?
    @State private var reportReason: String = ""
    @State private var isSendingReport: Bool = false

    @State private var isSavingCrop: Bool = false

    public init() {}

    public var body: some View {
        let stage = appState.stageController

        ZStack {
            // 1. Scan loading or error feedback centered on the black stage
            if stage.isLoadingScan {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text("Loading scan…")
                        .font(ArchiveFont.regular(11))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.75))
                .overlay(Rectangle().stroke(Color.white.opacity(0.35), lineWidth: 1))
            } else if let err = stage.scanErrorMessage {
                VStack(spacing: 10) {
                    Text(err)
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        appState.reloadCurrentScan()
                    }
                    .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                }
                .padding(14)
                .frame(maxWidth: 280)
                .background(Color.black.opacity(0.85))
                .overlay(Rectangle().stroke(Color.white.opacity(0.5), lineWidth: 1))
            }

            // 2. Top banners: Create-mode instruction, Admin preview label, or Stage toast
            VStack(spacing: 6) {
                if let pending = appState.adminPreviewEntry {
                    HStack(spacing: 8) {
                        Text("REVIEW PREVIEW: \(pending.name)")
                            .font(ArchiveFont.medium(10))
                            .lineLimit(1)
                        Button("Exit") {
                            appState.clearAdminPendingPreview()
                        }
                        .font(ArchiveFont.bold(10))
                        .underline()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.82))
                    .overlay(Rectangle().stroke(Color.white.opacity(0.45), lineWidth: 1))
                } else if appState.hasUnsavedSubmissionPreview {
                    Text("LOCAL SUBMISSION PREVIEW")
                        .font(ArchiveFont.medium(10))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.82))
                        .overlay(Rectangle().stroke(Color.white.opacity(0.45), lineWidth: 1))
                }

                if stage.createMode {
                    HStack(spacing: 10) {
                        Text("Tap a surface on the scan to place an annotation")
                            .font(ArchiveFont.regular(11))
                            .foregroundStyle(.white)
                        Button("Cancel") {
                            appState.pendingPickedPoint = nil
                            stage.setCreateMode(false)
                        }
                        .font(ArchiveFont.bold(11))
                        .foregroundStyle(.white)
                        .underline()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.85))
                    .overlay(Rectangle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                }

                if let toast = stage.toastMessage {
                    Text(toast)
                        .font(ArchiveFont.regular(11))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.8))
                        .overlay(Rectangle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                        .transition(.opacity)
                }

                Spacer()
            }
            .padding(.top, 8)
            .padding(.horizontal, 10)

            // 3. Bottom controls + Active annotation card + Admin crop toolbar
            VStack(alignment: .leading, spacing: 8) {
                Spacer()

                if let activeAnn = appState.selectedAnnotation, !stage.cropState.active {
                    activeAnnotationCard(activeAnn)
                }

                if stage.cropState.active {
                    adminCropToolbar(stage: stage)
                } else {
                    standardControlsRow(stage: stage)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .sheet(
            isPresented: Binding(
                get: { appState.pendingPickedPoint != nil },
                set: { shown in
                    if !shown {
                        appState.pendingPickedPoint = nil
                        composeText = ""
                        composeError = nil
                    }
                }
            )
        ) {
            composeAnnotationSheet
                .presentationDetents([.height(270), .medium])
        }
        .sheet(item: $reportingAnnotation) { ann in
            reportAnnotationSheet(ann)
                .presentationDetents([.height(260), .medium])
        }
    }

    // MARK: - Standard Stage Controls

    private func standardControlsRow(stage: StageController) -> some View {
        HStack(spacing: 8) {
            StageCircleButton(
                systemImage: stage.cameraMode == .pov ? "eye" : "cube",
                accessibilityLabel: stage.cameraMode == .pov ? "Switch to Orbit view" : "Switch to POV view",
                isActive: false
            ) {
                stage.toggleCameraMode()
            }

            if !appState.hasUnsavedSubmissionPreview && appState.adminPreviewEntry == nil {
                StageCircleButton(
                    systemImage: stage.markersVisible ? "tag.fill" : "tag.slash",
                    accessibilityLabel: stage.markersVisible ? "Hide annotations" : "Show annotations",
                    isActive: stage.markersVisible
                ) {
                    stage.toggleMarkersVisible()
                }

                StageCircleButton(
                    systemImage: stage.createMode ? "xmark" : "plus",
                    accessibilityLabel: stage.createMode ? "Cancel annotation" : "Add annotation",
                    isActive: stage.createMode
                ) {
                    handleTapCreateAnnotation()
                }
            }

            Spacer()

            if appState.activeCropTarget != nil {
                Button {
                    stage.startCrop()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "crop")
                            .font(.system(size: 11, weight: .medium))
                        Text("Crop")
                            .font(ArchiveFont.regular(11))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.78))
                    .overlay(Rectangle().stroke(Color.white.opacity(0.65), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func handleTapCreateAnnotation() {
        let stage = appState.stageController
        if stage.createMode {
            stage.setCreateMode(false)
            return
        }
        guard let user = appState.currentUser else {
            appState.requestTabSwitch(.account)
            appState.showBanner("Sign in to place spatial annotations.")
            return
        }
        if user.isBanned {
            appState.showBanner("Your account has been suspended.")
            return
        }
        if user.isMuted {
            appState.showBanner("Your account is temporarily muted from posting annotations.")
            return
        }
        stage.setCreateMode(true)
    }

    // MARK: - Active Annotation Card

    private func activeAnnotationCard(_ ann: Annotation) -> some View {
        let ordinal = (appState.visibleAnnotations.firstIndex(where: { $0.id == ann.id }) ?? 0) + 1
        let canDelete = appState.currentUser?.isAdmin == true || appState.currentUser?.id == ann.author.id
        let isOwn = appState.currentUser?.id == ann.author.id

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("#\(ordinal)")
                    .font(ArchiveFont.bold(11))
                    .foregroundStyle(ArchiveColor.paper)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(ArchiveColor.ink)

                Text(ann.author.formattedAttribution)
                    .font(ArchiveFont.medium(11))
                    .foregroundStyle(ArchiveColor.ink)

                Text("· \(ArchiveDateFormatter.formatMonthDayYear(ann.createdAt))")
                    .font(ArchiveFont.regular(11))
                    .foregroundStyle(ArchiveColor.muted)

                Spacer()

                if canDelete {
                    Button {
                        Task {
                            try? await appState.deleteAnnotation(ann.id)
                        }
                    } label: {
                        Text("Delete")
                            .font(ArchiveFont.regular(11))
                            .foregroundStyle(ArchiveColor.danger)
                    }
                    .buttonStyle(.plain)
                }

                if !isOwn {
                    Menu {
                        Button("Report annotation…") {
                            reportReason = ""
                            reportingAnnotation = ann
                        }
                        Button("Block @\(ann.author.username)", role: .destructive) {
                            Task {
                                await appState.blockAuthor(username: ann.author.username)
                            }
                        }
                    } label: {
                        Text("!")
                            .font(ArchiveFont.bold(11))
                            .foregroundStyle(ArchiveColor.muted)
                            .frame(width: 20, height: 20)
                            .overlay(Rectangle().stroke(ArchiveColor.inputBorder, lineWidth: 1))
                    }
                }

                Button {
                    appState.selectAnnotation(nil, fly: false)
                } label: {
                    Text("×")
                        .font(ArchiveFont.regular(16))
                        .foregroundStyle(ArchiveColor.ink)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)
            }

            Text(ann.body)
                .font(ArchiveFont.regular(12))
                .foregroundStyle(ArchiveColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: 420, alignment: .leading)
        .background(ArchiveColor.paper)
        .overlay(Rectangle().stroke(ArchiveColor.ink, lineWidth: 1))
    }

    // MARK: - Admin Crop & Levelling Toolbar

    private func adminCropToolbar(stage: StageController) -> some View {
        let cs = stage.cropState
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button(cs.tool == .rotate ? "Resize Box" : "Level") {
                    stage.toggleRotateTool()
                }
                .buttonStyle(ArchiveOutlineButtonStyle(active: cs.tool == .rotate, compact: true))

                if cs.tool == .box {
                    Button(cs.mode == .keep ? "Mode: Keep" : "Mode: Remove") {
                        stage.toggleCropMode()
                    }
                    .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                }

                if cs.boxEdited {
                    Button("Confirm Box") {
                        stage.confirmCropRound()
                    }
                    .buttonStyle(ArchiveOutlineButtonStyle(compact: true))

                    if cs.canDiscardBox {
                        Button("Discard Box") {
                            stage.discardCropRound()
                        }
                        .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                    }
                }

                if cs.dirty {
                    Button("Reset") {
                        stage.resetCrop()
                    }
                    .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                }

                Button(isSavingCrop ? "Saving…" : "Save Crop") {
                    Task { await saveCommittedCrop() }
                }
                .buttonStyle(ArchivePrimaryButtonStyle(compact: true))
                .disabled(isSavingCrop)

                Button("Cancel") {
                    stage.cancelCrop()
                }
                .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                .disabled(isSavingCrop)
            }
            .padding(6)
            .background(Color.black.opacity(0.82))
            .overlay(Rectangle().stroke(Color.white.opacity(0.45), lineWidth: 1))
        }
    }

    private func saveCommittedCrop() async {
        guard let target = appState.activeCropTarget else { return }
        isSavingCrop = true
        defer { isSavingCrop = false }

        let (result, thumbDataUrl) = await appState.stageController.commitCrop()
        guard let result else {
            appState.stageController.showToast("Failed to commit crop")
            return
        }

        do {
            try await appState.apiClient.saveRestroomCrop(id: target.id, cropResult: result)
            appState.stageController.applyCommittedCrop(result)

            if let thumbDataUrl, !target.hasThumb {
                try? await appState.apiClient.uploadThumbnail(slug: target.slug, imageDataUrl: thumbDataUrl)
            }

            if var pending = appState.adminPreviewEntry, pending.id == target.id {
                pending.crop = result.crop
                appState.adminPreviewEntry = pending
            }
            await appState.refreshCatalog()
            appState.stageController.showToast("Crop saved")
        } catch {
            appState.stageController.showToast(
                (error as? LocalizedError)?.errorDescription ?? "Failed to save crop"
            )
        }
    }

    // MARK: - Compose & Report Sheets

    private var composeAnnotationSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("New Spatial Annotation")
                    .font(ArchiveFont.medium(14))
                    .foregroundStyle(ArchiveColor.ink)
                Spacer()
                Button("Cancel") {
                    appState.pendingPickedPoint = nil
                }
                .buttonStyle(ArchiveLinkButtonStyle())
            }

            Text("Pinned to your current camera angle and selected 3D surface point.")
                .font(ArchiveFont.regular(11))
                .foregroundStyle(ArchiveColor.muted)

            TextEditor(text: $composeText)
                .font(ArchiveFont.regular(13))
                .frame(minHeight: 88)
                .padding(4)
                .overlay(Rectangle().stroke(ArchiveColor.ink, lineWidth: 1))
                .onChange(of: composeText) { _, newValue in
                    if newValue.count > 200 {
                        composeText = String(newValue.prefix(200))
                    }
                }

            HStack {
                Text("\(composeText.count)/200")
                    .font(ArchiveFont.mono(11))
                    .foregroundStyle(ArchiveColor.muted)
                Spacer()
                if let composeError {
                    Text(composeError)
                        .font(ArchiveFont.regular(11))
                        .foregroundStyle(ArchiveColor.danger)
                }
                Button(isSubmittingAnnotation ? "Saving…" : "Post Annotation") {
                    Task {
                        isSubmittingAnnotation = true
                        composeError = nil
                        do {
                            try await appState.createAnnotation(body: composeText)
                            composeText = ""
                        } catch {
                            composeError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                        }
                        isSubmittingAnnotation = false
                    }
                }
                .buttonStyle(ArchivePrimaryButtonStyle())
                .disabled(composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmittingAnnotation)
            }
        }
        .padding(16)
        .background(ArchiveColor.paper)
    }

    private func reportAnnotationSheet(_ ann: Annotation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Report Annotation")
                    .font(ArchiveFont.medium(14))
                    .foregroundStyle(ArchiveColor.ink)
                Spacer()
                Button("Close") {
                    reportingAnnotation = nil
                }
                .buttonStyle(ArchiveLinkButtonStyle())
            }

            Text("\"\(ann.body)\" — \(ann.author.formattedAttribution)")
                .font(ArchiveFont.regular(12))
                .foregroundStyle(ArchiveColor.muted)
                .lineLimit(2)

            TextField("Optional reason (spam, disrespectful, privacy…)", text: $reportReason, axis: .vertical)
                .lineLimit(2...4)
                .archiveFieldStyle()

            HStack {
                Spacer()
                Button(isSendingReport ? "Sending…" : "Submit Report") {
                    guard let slug = appState.selectedSlug else { return }
                    Task {
                        isSendingReport = true
                        do {
                            try await appState.apiClient.reportAnnotation(
                                slug: slug,
                                annotationId: ann.id,
                                reason: reportReason
                            )
                            reportingAnnotation = nil
                            appState.showBanner("Annotation reported for moderator review.")
                        } catch {
                            appState.showBanner(
                                (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                            )
                            reportingAnnotation = nil
                        }
                        isSendingReport = false
                    }
                }
                .buttonStyle(ArchivePrimaryButtonStyle())
                .disabled(isSendingReport)
            }
        }
        .padding(16)
        .background(ArchiveColor.paper)
    }
}

private struct StageCircleButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isActive ? Color.black : Color.white)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(isActive ? Color.white : Color.black.opacity(0.74))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.75), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
#endif

