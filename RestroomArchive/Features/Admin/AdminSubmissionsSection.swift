#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

public struct AdminSubmissionsSection: View {
    public enum SubTab: String, CaseIterable, Hashable {
        case pending
        case archive
        case rejected
        case removals

        var label: String {
            switch self {
            case .pending: return "Pending"
            case .archive: return "Archive"
            case .rejected: return "Rejected"
            case .removals: return "Removals"
            }
        }
    }

    @Environment(AppState.self) private var appState
    @State private var subTab: SubTab = .pending

    @State private var pendingList: [PendingRestroom] = []
    @State private var archiveList: [ArchiveEntry] = []
    @State private var rejectedList: [RejectedSubmission] = []
    @State private var removalsList: [RemovalRequest] = []
    @State private var isLoading: Bool = true

    @State private var rejectTarget: PendingRestroom?
    @State private var rejectMessage: String = ""

    @State private var removeTarget: ArchiveEntry?
    @State private var removeMessage: String = ""
    @State private var archiveSearch: String = ""

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            ArchiveUnderlineTabs(
                items: [
                    .init(id: SubTab.pending, label: "Pending", badge: pendingList.count),
                    .init(id: SubTab.archive, label: "Archive (\(archiveList.count))"),
                    .init(id: SubTab.rejected, label: "Rejected (\(rejectedList.count))"),
                    .init(id: SubTab.removals, label: "Removals", badge: removalsList.count)
                ],
                selection: $subTab
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if isLoading {
                VStack { ProgressView().tint(ArchiveColor.ink) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch subTab {
                case .pending:
                    pendingQueueView
                case .archive:
                    archiveDirectoryView
                case .rejected:
                    rejectedQueueView
                case .removals:
                    removalsQueueView
                }
            }
        }
        .task { await reloadAll() }
        .sheet(item: $rejectTarget) { item in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Reject: \(item.name)")
                        .font(ArchiveFont.medium(14))
                    Spacer()
                    Button("Cancel") { rejectTarget = nil }
                        .buttonStyle(ArchiveLinkButtonStyle())
                }
                TextField("Optional note to submitter", text: $rejectMessage, axis: .vertical)
                    .lineLimit(3...5)
                    .archiveFieldStyle()
                HStack {
                    Spacer()
                    Button("Reject Submission") {
                        Task {
                            try? await appState.apiClient.rejectRestroom(id: item.id, message: rejectMessage)
                            if appState.adminPreviewEntry?.id == item.id {
                                appState.clearAdminPendingPreview()
                            }
                            rejectTarget = nil
                            await reloadAll()
                        }
                    }
                    .buttonStyle(ArchiveActionButtonStyle(tone: .dangerFill))
                }
            }
            .padding(16)
            .presentationDetents([.height(240)])
        }
        .sheet(item: $removeTarget) { entry in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Remove from Archive: \(entry.name)")
                        .font(ArchiveFont.medium(14))
                    Spacer()
                    Button("Cancel") { removeTarget = nil }
                        .buttonStyle(ArchiveLinkButtonStyle())
                }
                TextField("Reason shown to submitter (optional)", text: $removeMessage, axis: .vertical)
                    .lineLimit(3...5)
                    .archiveFieldStyle()
                HStack {
                    Spacer()
                    Button("Remove Entry") {
                        Task {
                            try? await appState.apiClient.removeRestroom(id: entry.id, message: removeMessage)
                            removeTarget = nil
                            await appState.refreshCatalog()
                            await reloadAll()
                        }
                    }
                    .buttonStyle(ArchiveActionButtonStyle(tone: .dangerFill))
                }
            }
            .padding(16)
            .presentationDetents([.height(240)])
        }
    }

    // MARK: - Pending Queue

    private var pendingQueueView: some View {
        Group {
            if pendingList.isEmpty {
                emptyNotice("No submissions awaiting review.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(pendingList) { item in
                            let isPreviewing = appState.adminPreviewEntry?.id == item.id
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(item.name)
                                        .font(ArchiveFont.bold(13))
                                    Spacer()
                                    Text("\(item.location) · \(ArchiveDateFormatter.formatDayMonthYear(item.isoDate))")
                                        .font(ArchiveFont.regular(11))
                                        .foregroundStyle(ArchiveColor.muted)
                                }

                                if let submitter = item.submitter {
                                    Text("By \(submitter.formattedAttribution) (\(submitter.email))")
                                        .font(ArchiveFont.regular(11))
                                        .foregroundStyle(ArchiveColor.muted)
                                }

                                if let desc = item.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(ArchiveFont.regular(12))
                                        .foregroundStyle(ArchiveColor.ink)
                                }

                                if !item.descriptors.isEmpty {
                                    Text("Tags: \(item.descriptors.joined(separator: ", "))")
                                        .font(ArchiveFont.regular(11))
                                        .foregroundStyle(ArchiveColor.muted)
                                }

                                HStack(spacing: 8) {
                                    Button(isPreviewing ? "Previewing in 3D" : "Preview in 3D") {
                                        appState.previewAdminPendingEntry(item)
                                    }
                                    .buttonStyle(ArchiveOutlineButtonStyle(active: isPreviewing, compact: true))

                                    Button("Crop & Level") {
                                        appState.previewAdminPendingEntry(item)
                                        appState.stageController.startCrop()
                                    }
                                    .buttonStyle(ArchiveOutlineButtonStyle(compact: true))

                                    Spacer()

                                    Button("Publish") {
                                        Task {
                                            try? await appState.apiClient.publishRestroom(id: item.id)
                                            if appState.adminPreviewEntry?.id == item.id {
                                                appState.clearAdminPendingPreview()
                                            }
                                            await appState.refreshCatalog()
                                            await reloadAll()
                                            appState.showBanner("Published \(item.name).")
                                        }
                                    }
                                    .buttonStyle(ArchiveActionButtonStyle(tone: .publish))

                                    Button("Reject") {
                                        rejectMessage = ""
                                        rejectTarget = item
                                    }
                                    .buttonStyle(ArchiveActionButtonStyle(tone: .reject))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(isPreviewing ? ArchiveColor.subtleFill : ArchiveColor.paper)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(ArchiveColor.rowRule).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Archive Directory

    private var archiveDirectoryView: some View {
        let filtered = archiveList.filter { row in
            let q = archiveSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !q.isEmpty else { return true }
            return row.name.lowercased().contains(q)
                || row.location.lowercased().contains(q)
                || (row.submitter?.username.lowercased().contains(q) == true)
        }

        return VStack(spacing: 0) {
            TextField("Filter archive by name, city, or submitter…", text: $archiveSearch)
                .archiveFieldStyle()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            if filtered.isEmpty {
                emptyNotice("No archive entries match.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(entry.name)
                                            .font(ArchiveFont.bold(12.5))
                                        ArchivePillBadge(
                                            entry.status,
                                            tone: entry.status == "published" ? .outline : .danger
                                        )
                                    }
                                    Text("\(entry.location) · \(ArchiveDateFormatter.formatDayMonthYear(entry.isoDate))\(entry.submitter.map { " · @\($0.username)" } ?? "")")
                                        .font(ArchiveFont.regular(11))
                                        .foregroundStyle(ArchiveColor.muted)
                                }
                                Spacer()
                                if entry.status == "published" {
                                    Button("View") {
                                        appState.selectRestroom(slug: entry.slug)
                                    }
                                    .buttonStyle(ArchiveLinkButtonStyle())

                                    Button("Remove") {
                                        removeMessage = ""
                                        removeTarget = entry
                                    }
                                    .buttonStyle(ArchiveActionButtonStyle(tone: .reject))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(ArchiveColor.rowRule).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Rejected Queue (with 30-day Grace Countdown)

    private var rejectedQueueView: some View {
        Group {
            if rejectedList.isEmpty {
                emptyNotice("No rejected submissions.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rejectedList) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.name)
                                        .font(ArchiveFont.bold(12.5))
                                    Spacer()
                                    if item.scanPurgedAt != nil {
                                        ArchivePillBadge("Scan Purged", tone: .neutral)
                                    } else if let ms = RejectionGrace.msLeft(rejectedAt: item.rejectedAt) {
                                        ArchivePillBadge(RejectionGrace.formatCountdown(msLeft: ms), tone: .warn)
                                    }
                                }

                                Text("\(item.location) · \(ArchiveDateFormatter.formatDayMonthYear(item.isoDate))\(item.submitter.map { " · @\($0.username)" } ?? "")")
                                    .font(ArchiveFont.regular(11))
                                    .foregroundStyle(ArchiveColor.muted)

                                if let msg = item.rejectionMessage, !msg.isEmpty {
                                    Text("Reason: \(msg)")
                                        .font(ArchiveFont.regular(11.5))
                                }

                                if item.restorable {
                                    Button("Restore to Pending") {
                                        Task {
                                            try? await appState.apiClient.unrejectRestroom(id: item.id)
                                            await reloadAll()
                                            appState.showBanner("Restored \(item.name) to pending queue.")
                                        }
                                    }
                                    .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(ArchiveColor.rowRule).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Removal Requests Queue

    private var removalsQueueView: some View {
        Group {
            if removalsList.isEmpty {
                emptyNotice("No open removal requests.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(removalsList) { req in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(req.name) (\(req.location))")
                                    .font(ArchiveFont.bold(12.5))

                                if let requester = req.requester {
                                    Text("Requested by \(requester.formattedAttribution) (\(requester.email))")
                                        .font(ArchiveFont.regular(11))
                                        .foregroundStyle(ArchiveColor.muted)
                                }

                                if let reason = req.removalReason, !reason.isEmpty {
                                    Text("Reason: \(reason)")
                                        .font(ArchiveFont.regular(12))
                                }

                                HStack(spacing: 8) {
                                    Button("Approve Removal") {
                                        Task {
                                            try? await appState.apiClient.removeRestroom(id: req.id, message: nil)
                                            await appState.refreshCatalog()
                                            await reloadAll()
                                        }
                                    }
                                    .buttonStyle(ArchiveActionButtonStyle(tone: .reject))

                                    Button("Dismiss Request") {
                                        Task {
                                            try? await appState.apiClient.dismissRemovalRequest(id: req.id)
                                            await reloadAll()
                                        }
                                    }
                                    .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(ArchiveColor.rowRule).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
    }

    private func emptyNotice(_ text: String) -> some View {
        VStack {
            Text(text)
                .font(ArchiveFont.regular(12))
                .foregroundStyle(ArchiveColor.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func reloadAll() async {
        isLoading = true
        async let p = try? appState.apiClient.fetchAdminPendingRestrooms()
        async let a = try? appState.apiClient.fetchAdminArchive()
        async let r = try? appState.apiClient.fetchAdminRejected()
        async let rem = try? appState.apiClient.fetchAdminRemovals()
        let (pVal, aVal, rVal, remVal) = await (p, a, r, rem)
        pendingList = pVal ?? []
        archiveList = aVal ?? []
        rejectedList = rVal ?? []
        removalsList = remVal ?? []
        appState.adminPendingCount = pendingList.count
        appState.adminRemovalsCount = removalsList.count
        isLoading = false
    }
}
#endif

