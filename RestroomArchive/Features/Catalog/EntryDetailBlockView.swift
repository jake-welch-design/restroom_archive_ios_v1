#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

public struct EntryDetailBlockView: View {
    @Environment(AppState.self) private var appState
    let entry: RestroomSummary

    @State private var showEditSheet: Bool = false
    @State private var showRemovalSheet: Bool = false
    @State private var removalReason: String = ""
    @State private var showReportSheet: Bool = false
    @State private var reportReason: String = ""

    public init(entry: RestroomSummary) {
        self.entry = entry
    }

    private var isSubmitter: Bool {
        guard let currentUsername = appState.currentUser?.username.lowercased(),
              let subUsername = entry.submitter?.username.lowercased() else {
            return false
        }
        return currentUsername == subUsername
    }

    private var canEdit: Bool {
        appState.currentUser?.isAdmin == true || isSubmitter
    }

    private var shareURL: URL {
        URL(string: "https://restroomarchive.com/r/\(entry.slug)")
            ?? APIClient.defaultBaseURL
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let description = entry.description, !description.isEmpty {
                Text(description)
                    .font(ArchiveFont.regular(12.5))
                    .foregroundStyle(ArchiveColor.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !entry.descriptors.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(entry.descriptors, id: \.self) { tag in
                            let active = appState.selectedTags.contains(tag)
                            Button {
                                appState.toggleTagFilter(tag)
                            } label: {
                                Text(tag)
                                    .font(ArchiveFont.regular(11))
                                    .foregroundStyle(active ? ArchiveColor.paper : ArchiveColor.muted)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(active ? ArchiveColor.ink : ArchiveColor.subtleFill)
                                    .overlay(Rectangle().stroke(active ? ArchiveColor.ink : ArchiveColor.inputBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Byline & Action Bar
            HStack(spacing: 10) {
                if let submitter = entry.submitter {
                    Text("Submitted by \(submitter.formattedAttribution)")
                        .font(ArchiveFont.regular(11))
                        .foregroundStyle(ArchiveColor.muted)
                } else {
                    Text("Unattributed archive entry")
                        .font(ArchiveFont.regular(11))
                        .foregroundStyle(ArchiveColor.muted)
                }

                Spacer()

                ShareLink(item: shareURL) {
                    Text("Share")
                        .font(ArchiveFont.regular(11))
                        .foregroundStyle(ArchiveColor.ink)
                        .underline()
                }

                if canEdit {
                    Button("Edit") {
                        showEditSheet = true
                    }
                    .buttonStyle(ArchiveLinkButtonStyle())
                }

                if isSubmitter && appState.currentUser?.isAdmin != true {
                    Button("Request Removal") {
                        removalReason = ""
                        showRemovalSheet = true
                    }
                    .buttonStyle(ArchiveLinkButtonStyle())
                }

                Menu {
                    Button("Report entry…") {
                        reportReason = ""
                        showReportSheet = true
                    }
                    if let submitter = entry.submitter, !isSubmitter {
                        Button("Block @\(submitter.username)", role: .destructive) {
                            Task { await appState.blockAuthor(username: submitter.username) }
                        }
                    }
                } label: {
                    Text("•••")
                        .font(ArchiveFont.bold(10))
                        .foregroundStyle(ArchiveColor.muted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .overlay(Rectangle().stroke(ArchiveColor.inputBorder, lineWidth: 1))
                }
            }

            Rectangle()
                .fill(ArchiveColor.rowRule)
                .frame(height: 1)

            AnnotationListView(slug: entry.slug)
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showEditSheet) {
            EntryEditSheet(entry: entry)
        }
        .sheet(isPresented: $showRemovalSheet) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Request Entry Removal")
                        .font(ArchiveFont.medium(14))
                    Spacer()
                    Button("Cancel") { showRemovalSheet = false }
                        .buttonStyle(ArchiveLinkButtonStyle())
                }
                Text("Contributions are intended to be permanent, and removal requests are reviewed individually by an admin.")
                    .font(ArchiveFont.regular(12))
                    .foregroundStyle(ArchiveColor.muted)
                TextField("Reason for removal request", text: $removalReason, axis: .vertical)
                    .lineLimit(3...5)
                    .archiveFieldStyle()
                HStack {
                    Spacer()
                    Button("Send Request") {
                        Task {
                            do {
                                try await appState.apiClient.requestRestroomRemoval(
                                    slug: entry.slug,
                                    reason: removalReason
                                )
                                showRemovalSheet = false
                                appState.showBanner("Removal request sent to archive admins.")
                            } catch {
                                appState.showBanner(
                                    (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                                )
                            }
                        }
                    }
                    .buttonStyle(ArchivePrimaryButtonStyle())
                }
            }
            .padding(16)
            .presentationDetents([.height(260)])
        }
        .sheet(isPresented: $showReportSheet) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Report Restroom Entry")
                        .font(ArchiveFont.medium(14))
                    Spacer()
                    Button("Cancel") { showReportSheet = false }
                        .buttonStyle(ArchiveLinkButtonStyle())
                }
                Text("Report scans containing identifying personal content, private property, or guideline violations.")
                    .font(ArchiveFont.regular(12))
                    .foregroundStyle(ArchiveColor.muted)
                TextField("Reason (optional)", text: $reportReason, axis: .vertical)
                    .lineLimit(2...4)
                    .archiveFieldStyle()
                HStack {
                    Spacer()
                    Button("Submit Report") {
                        Task {
                            do {
                                try await appState.apiClient.reportRestroom(
                                    slug: entry.slug,
                                    reason: reportReason
                                )
                                showReportSheet = false
                                appState.showBanner("Entry reported for moderator review.")
                            } catch {
                                appState.showBanner(
                                    (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                                )
                            }
                        }
                    }
                    .buttonStyle(ArchivePrimaryButtonStyle())
                }
            }
            .padding(16)
            .presentationDetents([.height(250)])
        }
    }
}
#endif

