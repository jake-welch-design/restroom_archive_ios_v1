#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

public struct MySubmissionsView: View {
    public enum Filter: String, CaseIterable, Hashable {
        case all
        case published
        case pending

        var label: String {
            switch self {
            case .all: return "All"
            case .published: return "Published"
            case .pending: return "Pending"
            }
        }
    }

    @Environment(AppState.self) private var appState

    @State private var submissions: [MySubmission] = []
    @State private var isLoading: Bool = true
    @State private var filter: Filter = .all
    @State private var removalTarget: MySubmission?
    @State private var removalReason: String = ""

    public init() {}

    private var filtered: [MySubmission] {
        switch filter {
        case .all: return submissions
        case .published: return submissions.filter { $0.status == "published" }
        case .pending: return submissions.filter { $0.status == "pending" }
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                ArchiveUnderlineTabs(
                    items: [
                        .init(id: Filter.all, label: "All (\(submissions.count))"),
                        .init(id: Filter.published, label: "Published (\(submissions.filter { $0.status == "published" }.count))"),
                        .init(id: Filter.pending, label: "Pending (\(submissions.filter { $0.status == "pending" }.count))")
                    ],
                    selection: $filter
                )
                Spacer()
                Button("+ New") {
                    appState.requestTabSwitch(.submit)
                }
                .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            if isLoading {
                VStack {
                    ProgressView().tint(ArchiveColor.ink)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filtered.isEmpty {
                VStack(spacing: 8) {
                    Text("No submissions in this view.")
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.muted)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Button {
                                        if item.status == "published" {
                                            appState.selectRestroom(slug: item.slug)
                                            appState.requestTabSwitch(.catalog)
                                        }
                                    } label: {
                                        Text(item.name)
                                            .font(ArchiveFont.bold(13))
                                            .foregroundStyle(ArchiveColor.ink)
                                    }
                                    .buttonStyle(.plain)

                                    Spacer()

                                    ArchivePillBadge(
                                        item.statusDisplayLabel,
                                        tone: item.status == "published"
                                            ? .outline
                                            : (item.status == "pending" ? .warn : .danger)
                                    )
                                }

                                Text("\(item.location) · \(ArchiveDateFormatter.formatDayMonthYear(item.isoDate))")
                                    .font(ArchiveFont.regular(11.5))
                                    .foregroundStyle(ArchiveColor.muted)

                                if let note = item.adminNote, !note.isEmpty {
                                    Text("Admin note: \(note)")
                                        .font(ArchiveFont.regular(11.5))
                                        .foregroundStyle(ArchiveColor.ink)
                                        .padding(8)
                                        .background(ArchiveColor.subtleFill)
                                }

                                HStack(spacing: 12) {
                                    if item.status == "published" {
                                        Button("View in Catalog") {
                                            appState.selectRestroom(slug: item.slug)
                                            appState.requestTabSwitch(.catalog)
                                        }
                                        .buttonStyle(ArchiveLinkButtonStyle())

                                        if !item.removalRequested {
                                            Button("Request Removal") {
                                                removalReason = ""
                                                removalTarget = item
                                            }
                                            .buttonStyle(ArchiveLinkButtonStyle())
                                        } else {
                                            Text("Removal requested")
                                                .font(ArchiveFont.regular(11))
                                                .foregroundStyle(ArchiveColor.muted)
                                        }
                                    } else if item.status == "pending" {
                                        Button("Withdraw") {
                                            Task {
                                                try? await appState.apiClient.deleteOrWithdrawRestroom(slug: item.slug)
                                                await reload()
                                                appState.showBanner("Pending submission withdrawn.")
                                            }
                                        }
                                        .font(ArchiveFont.regular(11))
                                        .foregroundStyle(ArchiveColor.danger)
                                        .buttonStyle(.plain)
                                    }
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
        .sheet(item: $removalTarget) { sub in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Request Removal: \(sub.name)")
                        .font(ArchiveFont.medium(14))
                    Spacer()
                    Button("Cancel") { removalTarget = nil }
                        .buttonStyle(ArchiveLinkButtonStyle())
                }
                TextField("Reason for removal request", text: $removalReason, axis: .vertical)
                    .lineLimit(3...5)
                    .archiveFieldStyle()
                HStack {
                    Spacer()
                    Button("Send Request") {
                        Task {
                            try? await appState.apiClient.requestRestroomRemoval(
                                slug: sub.slug,
                                reason: removalReason
                            )
                            removalTarget = nil
                            await reload()
                        }
                    }
                    .buttonStyle(ArchivePrimaryButtonStyle())
                }
            }
            .padding(16)
            .presentationDetents([.height(240)])
        }
    }

    private func reload() async {
        isLoading = true
        submissions = (try? await appState.apiClient.fetchMySubmissions()) ?? []
        isLoading = false
    }
}
#endif

