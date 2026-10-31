#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

public struct AdminRootView: View {
    public enum GroupTab: String, CaseIterable, Hashable {
        case submissions
        case users
        case annotations
        case log

        var label: String {
            switch self {
            case .submissions: return "Submissions"
            case .users: return "Users"
            case .annotations: return "Annotations"
            case .log: return "Log"
            }
        }
    }

    @Environment(AppState.self) private var appState
    @State private var selectedGroup: GroupTab = .submissions
    @State private var auditEntries: [AuditLogEntry] = []
    @State private var isLoadingLog: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            ArchiveSegmentedBar(
                items: [
                    .init(
                        id: GroupTab.submissions,
                        label: "Submissions",
                        badge: appState.adminPendingCount + appState.adminRemovalsCount
                    ),
                    .init(
                        id: GroupTab.users,
                        label: "Users",
                        badge: appState.adminUpgradesCount
                    ),
                    .init(
                        id: GroupTab.annotations,
                        label: "Notes",
                        badge: appState.adminReportsCount
                    ),
                    .init(id: GroupTab.log, label: "Log")
                ],
                selection: $selectedGroup
            )
            .padding(.horizontal, 16)
            .padding(.top, 10)

            switch selectedGroup {
            case .submissions:
                AdminSubmissionsSection()
            case .users:
                AdminUsersSection()
            case .annotations:
                AdminAnnotationsSection()
            case .log:
                auditLogView
            }
        }
        .background(ArchiveColor.paper)
        .task {
            await appState.refreshAdminBadgeCounts()
        }
    }

    private var auditLogView: some View {
        Group {
            if isLoadingLog {
                VStack { ProgressView().tint(ArchiveColor.ink) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if auditEntries.isEmpty {
                VStack {
                    Text("No audit log entries recorded.")
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(auditEntries) { entry in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(entry.action)
                                        .font(ArchiveFont.mono(11.5))
                                        .foregroundStyle(ArchiveColor.ink)
                                    Spacer()
                                    Text(ArchiveDateFormatter.formatDayMonthYear(entry.createdAt))
                                        .font(ArchiveFont.regular(10.5))
                                        .foregroundStyle(ArchiveColor.muted)
                                }

                                Text("\(entry.actor.map { "@\($0.username)" } ?? "system") → \(entry.targetType)\(entry.targetId.map { " #\($0)" } ?? "")")
                                    .font(ArchiveFont.regular(11))
                                    .foregroundStyle(ArchiveColor.muted)

                                if let meta = entry.metadata, !meta.isEmpty {
                                    Text(JSONValue.object(meta).compactSummary)
                                        .font(ArchiveFont.mono(10))
                                        .foregroundStyle(ArchiveColor.muted)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(ArchiveColor.rowRule).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
        .task(id: selectedGroup) {
            guard selectedGroup == .log else { return }
            isLoadingLog = true
            auditEntries = (try? await appState.apiClient.fetchAdminAuditLog()) ?? []
            isLoadingLog = false
        }
    }
}
#endif

