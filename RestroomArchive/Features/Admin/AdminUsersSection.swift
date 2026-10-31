#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

public struct AdminUsersSection: View {
    public enum SubTab: String, CaseIterable, Hashable {
        case accounts
        case upgrades
    }

    @Environment(AppState.self) private var appState
    @State private var subTab: SubTab = .accounts

    @State private var accounts: [AccountRow] = []
    @State private var pendingUsers: [PendingUser] = []
    @State private var isLoading: Bool = true
    @State private var search: String = ""

    @State private var expandedManageId: Int?
    @State private var noteText: String = ""
    @State private var renameText: String = ""
    @State private var muteDays: Int = 7
    @State private var userSubmissions: [Int: [AccountSubmission]] = [:]
    @State private var userAnnotations: [Int: [AccountAnnotation]] = [:]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            ArchiveUnderlineTabs(
                items: [
                    .init(id: SubTab.accounts, label: "Accounts (\(accounts.count))"),
                    .init(id: SubTab.upgrades, label: "Upgrades", badge: pendingUsers.count)
                ],
                selection: $subTab
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if isLoading {
                VStack { ProgressView().tint(ArchiveColor.ink) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if subTab == .accounts {
                accountsView
            } else {
                upgradesView
            }
        }
        .task { await reload() }
    }

    private var accountsView: some View {
        let filtered = accounts.filter { row in
            let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !q.isEmpty else { return true }
            return row.username.lowercased().contains(q)
                || row.email.lowercased().contains(q)
                || (row.displayName?.lowercased().contains(q) == true)
        }

        let adminsCount = accounts.filter { $0.role == "admin" }.count
        let archivistsCount = accounts.filter { $0.role != "admin" && $0.approvedAt != nil }.count
        let annotatorsCount = accounts.count - adminsCount - archivistsCount

        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(accounts.count) total · \(adminsCount) admins · \(archivistsCount) archivists · \(annotatorsCount) annotators")
                    .font(ArchiveFont.regular(11))
                    .foregroundStyle(ArchiveColor.muted)

                TextField("Search username, display name, or email…", text: $search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .archiveFieldStyle()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { row in
                        let isManaging = expandedManageId == row.id
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("@\(row.username)")
                                    .font(ArchiveFont.bold(12.5))
                                if let dn = row.displayName, !dn.isEmpty {
                                    Text("(\(dn))")
                                        .font(ArchiveFont.regular(11.5))
                                        .foregroundStyle(ArchiveColor.muted)
                                }
                                ArchivePillBadge(row.accountTypeLabel, tone: row.role == "admin" ? .role : .outline)
                                if row.isMuted {
                                    ArchivePillBadge("Muted", tone: .warn)
                                }
                                if row.bannedAt != nil {
                                    ArchivePillBadge("Banned", tone: .danger)
                                }
                                Spacer()
                                Button(isManaging ? "Close" : "Manage") {
                                    if isManaging {
                                        expandedManageId = nil
                                    } else {
                                        expandedManageId = row.id
                                        noteText = row.adminMessage ?? ""
                                        renameText = row.username
                                        Task { await loadActivity(for: row.id) }
                                    }
                                }
                                .buttonStyle(ArchiveOutlineButtonStyle(active: isManaging, compact: true))
                            }

                            Text("\(row.email) · \(row.submissionCount) scans · \(row.annotationCount) annotations")
                                .font(ArchiveFont.regular(11))
                                .foregroundStyle(ArchiveColor.muted)

                            if isManaging {
                                managePanel(for: row)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(isManaging ? ArchiveColor.hoverFill : ArchiveColor.paper)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(ArchiveColor.rowRule).frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private func managePanel(for row: AccountRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Admin Note
            HStack(spacing: 6) {
                TextField("Admin note shown to user", text: $noteText)
                    .archiveFieldStyle()
                Button("Send Note") {
                    Task {
                        try? await appState.apiClient.adminUserAction(userId: row.id, verb: "note", message: noteText)
                        await reload()
                    }
                }
                .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
            }

            // Rename
            HStack(spacing: 6) {
                TextField("New username", text: $renameText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .archiveFieldStyle()
                Button("Rename") {
                    Task {
                        try? await appState.apiClient.adminRenameUser(userId: row.id, newUsername: renameText)
                        await reload()
                    }
                }
                .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
            }

            // Role & Moderation Actions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if row.role != "admin" {
                        if row.approvedAt == nil {
                            Button("Grant Submit") {
                                Task {
                                    try? await appState.apiClient.adminUserAction(userId: row.id, verb: "grant-submit")
                                    await reload()
                                }
                            }
                            .buttonStyle(ArchiveActionButtonStyle(tone: .publish))
                        } else {
                            Button("Revoke Submit") {
                                Task {
                                    try? await appState.apiClient.adminUserAction(userId: row.id, verb: "revoke-submit")
                                    await reload()
                                }
                            }
                            .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                        }

                        Button("Promote Admin") {
                            Task {
                                try? await appState.apiClient.adminUserAction(userId: row.id, verb: "promote")
                                await reload()
                            }
                        }
                        .buttonStyle(ArchiveOutlineButtonStyle(compact: true))

                        if row.isMuted {
                            Button("Unmute") {
                                Task {
                                    try? await appState.apiClient.adminUserAction(userId: row.id, verb: "unmute")
                                    await reload()
                                }
                            }
                            .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                        } else {
                            Picker("Days", selection: $muteDays) {
                                Text("1d").tag(1)
                                Text("7d").tag(7)
                                Text("30d").tag(30)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 115)

                            Button("Mute") {
                                Task {
                                    try? await appState.apiClient.adminUserAction(
                                        userId: row.id,
                                        verb: "mute",
                                        message: noteText,
                                        days: muteDays
                                    )
                                    await reload()
                                }
                            }
                            .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                        }

                        if row.bannedAt != nil {
                            Button("Unban") {
                                Task {
                                    try? await appState.apiClient.adminUserAction(userId: row.id, verb: "unban")
                                    await reload()
                                }
                            }
                            .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                        } else {
                            Button("Ban") {
                                Task {
                                    try? await appState.apiClient.adminUserAction(
                                        userId: row.id,
                                        verb: "ban",
                                        message: noteText
                                    )
                                    await reload()
                                }
                            }
                            .buttonStyle(ArchiveActionButtonStyle(tone: .reject))
                        }

                        Button("Delete User") {
                            Task {
                                try? await appState.apiClient.adminDeleteUser(userId: row.id)
                                expandedManageId = nil
                                await reload()
                            }
                        }
                        .buttonStyle(ArchiveActionButtonStyle(tone: .dangerFill))
                    }
                }
            }

            if let subs = userSubmissions[row.id], !subs.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("User Submissions:")
                        .font(ArchiveFont.medium(11))
                    ForEach(subs) { s in
                        Text("• \(s.name) (\(s.location)) — \(s.status)")
                            .font(ArchiveFont.regular(11))
                            .foregroundStyle(ArchiveColor.muted)
                    }
                }
            }

            if let anns = userAnnotations[row.id], !anns.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("User Annotations:")
                        .font(ArchiveFont.medium(11))
                    ForEach(anns.prefix(8)) { a in
                        Text("• [\(a.restroomName)] \(a.body)")
                            .font(ArchiveFont.regular(11))
                            .foregroundStyle(ArchiveColor.muted)
                    }
                }
            }
        }
        .padding(10)
        .background(ArchiveColor.paper)
        .overlay(Rectangle().stroke(ArchiveColor.rule, lineWidth: 1))
    }

    private var upgradesView: some View {
        Group {
            if pendingUsers.isEmpty {
                VStack {
                    Text("No pending Archivist access requests.")
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(pendingUsers) { u in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("@\(u.username)\(u.displayName.map { " (\($0))" } ?? "")")
                                        .font(ArchiveFont.bold(12.5))
                                    Text(u.email)
                                        .font(ArchiveFont.regular(11))
                                        .foregroundStyle(ArchiveColor.muted)
                                }
                                Spacer()
                                Button("Approve") {
                                    Task {
                                        try? await appState.apiClient.approveUserUpgrade(id: u.id)
                                        await reload()
                                    }
                                }
                                .buttonStyle(ArchiveActionButtonStyle(tone: .publish))

                                Button("Decline") {
                                    Task {
                                        try? await appState.apiClient.rejectUserUpgrade(id: u.id)
                                        await reload()
                                    }
                                }
                                .buttonStyle(ArchiveActionButtonStyle(tone: .reject))
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

    private func loadActivity(for userId: Int) async {
        async let subs = try? appState.apiClient.fetchAdminUserSubmissions(userId: userId)
        async let anns = try? appState.apiClient.fetchAdminUserAnnotations(userId: userId)
        let (s, a) = await (subs, anns)
        userSubmissions[userId] = s ?? []
        userAnnotations[userId] = a ?? []
    }

    private func reload() async {
        isLoading = true
        async let a = try? appState.apiClient.fetchAdminAccounts()
        async let p = try? appState.apiClient.fetchAdminPendingUsers()
        let (aVal, pVal) = await (a, p)
        accounts = aVal ?? []
        pendingUsers = pVal ?? []
        appState.adminUpgradesCount = pendingUsers.count
        isLoading = false
    }
}
#endif

