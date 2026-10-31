#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

public struct AnnotationListView: View {
    @Environment(AppState.self) private var appState
    let slug: String

    @State private var isExpanded: Bool = true
    @State private var reportTarget: Annotation?
    @State private var reportReason: String = ""

    public init(slug: String) {
        self.slug = slug
    }

    public var body: some View {
        let items = appState.selectedSlug == slug ? appState.visibleAnnotations : []

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.14)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "▾" : "▸")
                            .font(ArchiveFont.mono(11))
                        Text("Annotations (\(items.count))")
                            .font(ArchiveFont.medium(11))
                    }
                    .foregroundStyle(ArchiveColor.ink)
                }
                .buttonStyle(.plain)

                Spacer()

                Button("+ Add annotation") {
                    if appState.selectedSlug != slug {
                        appState.selectRestroom(slug: slug)
                    }
                    if appState.currentUser == nil {
                        appState.requestTabSwitch(.account)
                        appState.showBanner("Sign in to place spatial annotations.")
                    } else if appState.currentUser?.isMuted == true {
                        appState.showBanner("Your account is temporarily muted.")
                    } else {
                        appState.stageController.setCreateMode(true)
                    }
                }
                .buttonStyle(ArchiveLinkButtonStyle())
            }

            if isExpanded {
                if appState.isLoadingAnnotations && items.isEmpty {
                    Text("Loading annotations…")
                        .font(ArchiveFont.regular(11))
                        .foregroundStyle(ArchiveColor.muted)
                } else if items.isEmpty {
                    Text("No annotations yet. Tap + on the viewer to pin a note to a surface.")
                        .font(ArchiveFont.regular(11))
                        .foregroundStyle(ArchiveColor.muted)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, ann in
                            let isSelected = appState.selectedAnnotationId == ann.id
                            let canDelete = appState.currentUser?.isAdmin == true || appState.currentUser?.id == ann.author.id
                            let isOwn = appState.currentUser?.id == ann.author.id

                            HStack(alignment: .top, spacing: 8) {
                                Button {
                                    if isSelected {
                                        appState.selectAnnotation(nil, fly: false)
                                    } else {
                                        appState.selectAnnotation(ann.id, fly: true)
                                    }
                                } label: {
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(index + 1)")
                                            .font(ArchiveFont.mono(10))
                                            .foregroundStyle(isSelected ? ArchiveColor.paper : ArchiveColor.ink)
                                            .frame(width: 18, height: 18)
                                            .background(isSelected ? ArchiveColor.ink : ArchiveColor.paper)
                                            .overlay(Rectangle().stroke(ArchiveColor.ink, lineWidth: 1))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(ann.body)
                                                .font(ArchiveFont.regular(12))
                                                .foregroundStyle(ArchiveColor.ink)
                                                .multilineTextAlignment(.leading)

                                            Text("\(ann.author.formattedAttribution) · \(ArchiveDateFormatter.formatMonthDayYear(ann.createdAt))")
                                                .font(ArchiveFont.regular(10))
                                                .foregroundStyle(ArchiveColor.muted)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                }
                                .buttonStyle(.plain)

                                if canDelete {
                                    Button("Delete") {
                                        Task { try? await appState.deleteAnnotation(ann.id) }
                                    }
                                    .font(ArchiveFont.regular(10))
                                    .foregroundStyle(ArchiveColor.danger)
                                    .buttonStyle(.plain)
                                } else if !isOwn {
                                    Menu {
                                        Button("Report annotation…") {
                                            reportReason = ""
                                            reportTarget = ann
                                        }
                                        Button("Block @\(ann.author.username)", role: .destructive) {
                                            Task { await appState.blockAuthor(username: ann.author.username) }
                                        }
                                    } label: {
                                        Text("!")
                                            .font(ArchiveFont.bold(10))
                                            .foregroundStyle(ArchiveColor.muted)
                                            .frame(width: 18, height: 18)
                                            .overlay(Rectangle().stroke(ArchiveColor.inputBorder, lineWidth: 1))
                                    }
                                }
                            }
                            .padding(6)
                            .background(isSelected ? ArchiveColor.subtleFill : Color.clear)
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
        .sheet(item: $reportTarget) { ann in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Report Annotation")
                        .font(ArchiveFont.medium(14))
                    Spacer()
                    Button("Close") { reportTarget = nil }
                        .buttonStyle(ArchiveLinkButtonStyle())
                }
                TextField("Optional reason", text: $reportReason, axis: .vertical)
                    .lineLimit(2...4)
                    .archiveFieldStyle()
                HStack {
                    Spacer()
                    Button("Submit Report") {
                        Task {
                            try? await appState.apiClient.reportAnnotation(
                                slug: slug,
                                annotationId: ann.id,
                                reason: reportReason
                            )
                            reportTarget = nil
                            appState.showBanner("Annotation reported.")
                        }
                    }
                    .buttonStyle(ArchivePrimaryButtonStyle())
                }
            }
            .padding(16)
            .presentationDetents([.height(230)])
        }
    }
}
#endif

