#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

public struct ProfileSettingsView: View {
    @Environment(AppState.self) private var appState
    let user: SessionUser

    @State private var displayName: String = ""
    @State private var isSavingName: Bool = false
    @State private var nameFeedback: String?

    @State private var newEmail: String = ""
    @State private var emailPassword: String = ""
    @State private var isSavingEmail: Bool = false
    @State private var emailFeedback: String?

    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var isSavingPassword: Bool = false
    @State private var passwordFeedback: String?

    // Admin Telegram Notifications
    @State private var notifySettings: NotifySettings?
    @State private var telegramLink: TelegramLink?
    @State private var notifyFeedback: String?

    // Self-delete account confirmation
    @State private var showDeleteSection: Bool = false
    @State private var confirmUsername: String = ""
    @State private var deletePassword: String = ""
    @State private var isDeletingAccount: Bool = false
    @State private var deleteError: String?

    public init(user: SessionUser) {
        self.user = user
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Identity Card + Role Badge + Sign Out
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        Text("@\(user.username)")
                            .font(ArchiveFont.bold(14))
                            .foregroundStyle(ArchiveColor.ink)

                        ArchivePillBadge(
                            user.isAdmin ? "Admin" : (user.canSubmit ? "Archivist" : "Annotator"),
                            tone: .role
                        )

                        if user.isMuted {
                            ArchivePillBadge("Muted", tone: .warn)
                        }
                        if user.isBanned {
                            ArchivePillBadge("Banned", tone: .danger)
                        }

                        Spacer()

                        Button("Sign Out") {
                            Task { await appState.signOut() }
                        }
                        .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                    }

                    Text(user.email)
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.muted)

                    if let adminMsg = user.adminMessage, !adminMsg.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Message from Archive Admin")
                                .font(ArchiveFont.bold(11))
                            Text(adminMsg)
                                .font(ArchiveFont.regular(12))
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ArchiveColor.subtleFill)
                        .overlay(Rectangle().stroke(ArchiveColor.ink, lineWidth: 1))
                    }
                }

                divider

                // Display Name
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Display Name")
                    HStack(spacing: 8) {
                        TextField("Optional public name (up to 25 chars)", text: $displayName)
                            .archiveFieldStyle()
                            .onChange(of: displayName) { _, val in
                                if val.count > 25 { displayName = String(val.prefix(25)) }
                            }
                        Button(isSavingName ? "Saving…" : "Save") {
                            Task { await saveDisplayName() }
                        }
                        .buttonStyle(ArchivePrimaryButtonStyle(compact: true))
                        .disabled(isSavingName)
                    }
                    if let nameFeedback {
                        Text(nameFeedback)
                            .font(ArchiveFont.regular(11))
                            .foregroundStyle(ArchiveColor.muted)
                    }
                }

                divider

                // Update Email
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Change Email")
                    TextField("New email address", text: $newEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .archiveFieldStyle()
                    SecureField("Current password", text: $emailPassword)
                        .archiveFieldStyle()
                    if let emailFeedback {
                        Text(emailFeedback)
                            .font(ArchiveFont.regular(11))
                            .foregroundStyle(ArchiveColor.muted)
                    }
                    Button(isSavingEmail ? "Updating…" : "Update Email") {
                        Task { await saveEmail() }
                    }
                    .buttonStyle(ArchiveOutlineButtonStyle())
                    .disabled(isSavingEmail || !newEmail.contains("@") || emailPassword.isEmpty)
                }

                divider

                // Update Password
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Change Password")
                    SecureField("Current password", text: $currentPassword)
                        .archiveFieldStyle()
                    SecureField("New password (at least 8 characters)", text: $newPassword)
                        .archiveFieldStyle()
                    if let passwordFeedback {
                        Text(passwordFeedback)
                            .font(ArchiveFont.regular(11))
                            .foregroundStyle(ArchiveColor.muted)
                    }
                    Button(isSavingPassword ? "Updating…" : "Update Password") {
                        Task { await savePassword() }
                    }
                    .buttonStyle(ArchiveOutlineButtonStyle())
                    .disabled(isSavingPassword || currentPassword.isEmpty || newPassword.count < 8)
                }

                // Admin Telegram Alerts
                if user.isAdmin {
                    divider
                    adminTelegramSection
                }

                divider

                // Blocked Users (App Store Guideline 1.2)
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Blocked Accounts (\(appState.blockedUsers.count))")
                    if appState.blockedUsers.isEmpty {
                        Text("You haven't blocked any accounts. Entries and annotations from blocked accounts are immediately hidden.")
                            .font(ArchiveFont.regular(12))
                            .foregroundStyle(ArchiveColor.muted)
                    } else {
                        ForEach(appState.blockedUsers) { blocked in
                            HStack {
                                Text("@\(blocked.username)")
                                    .font(ArchiveFont.regular(12.5))
                                Spacer()
                                Button("Unblock") {
                                    Task { await appState.unblockAuthor(username: blocked.username) }
                                }
                                .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Self-Delete Account (App Store Guideline 5.1.1(v))
                if !user.isAdmin {
                    divider

                    VStack(alignment: .leading, spacing: 10) {
                        Button(showDeleteSection ? "Cancel Account Deletion" : "Delete Account…") {
                            showDeleteSection.toggle()
                            deleteError = nil
                        }
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.danger)
                        .underline()
                        .buttonStyle(.plain)

                        if showDeleteSection {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Deleting your account permanently removes your login and all spatial annotations you have posted. Published restroom scans remain in the archive unattributed.")
                                    .font(ArchiveFont.regular(12))
                                    .foregroundStyle(ArchiveColor.ink)

                                TextField("Type \(user.username) to confirm", text: $confirmUsername)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .archiveFieldStyle()

                                SecureField("Current password", text: $deletePassword)
                                    .archiveFieldStyle()

                                if let deleteError {
                                    Text(deleteError)
                                        .font(ArchiveFont.regular(12))
                                        .foregroundStyle(ArchiveColor.danger)
                                }

                                Button(isDeletingAccount ? "Deleting…" : "Permanently Delete Account") {
                                    Task { await performSelfDelete() }
                                }
                                .buttonStyle(ArchiveActionButtonStyle(tone: .dangerFill))
                                .disabled(
                                    isDeletingAccount ||
                                        confirmUsername.trimmingCharacters(in: .whitespaces).lowercased() != user.username.lowercased() ||
                                        deletePassword.isEmpty
                                )
                            }
                            .padding(12)
                            .overlay(Rectangle().stroke(ArchiveColor.danger, lineWidth: 1))
                        }
                    }
                }
            }
            .padding(16)
        }
        .onAppear {
            displayName = user.displayName ?? ""
            if user.isAdmin {
                Task { notifySettings = try? await appState.apiClient.fetchNotifySettings() }
            }
        }
    }

    private var adminTelegramSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Admin Telegram Alerts")
            if let ns = notifySettings {
                if !ns.serverConfigured {
                    Text("Telegram bot is not configured on this server.")
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.muted)
                } else if ns.connected {
                    HStack {
                        Text("Connected\(ns.telegramName.map { " as \($0)" } ?? "")")
                            .font(ArchiveFont.regular(12))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { ns.enabled },
                            set: { enabled in
                                Task {
                                    try? await appState.apiClient.updateNotifySettings(enabled: enabled)
                                    notifySettings = try? await appState.apiClient.fetchNotifySettings()
                                }
                            }
                        ))
                        .labelsHidden()
                        .tint(ArchiveColor.ink)
                    }
                    HStack(spacing: 8) {
                        Button("Send Test") {
                            Task {
                                do {
                                    try await appState.apiClient.sendTestNotification()
                                    notifyFeedback = "Test alert sent."
                                } catch {
                                    notifyFeedback = error.localizedDescription
                                }
                            }
                        }
                        .buttonStyle(ArchiveOutlineButtonStyle(compact: true))

                        Button("Disconnect") {
                            Task {
                                try? await appState.apiClient.disconnectTelegram()
                                notifySettings = try? await appState.apiClient.fetchNotifySettings()
                            }
                        }
                        .buttonStyle(ArchiveActionButtonStyle(tone: .reject))
                    }
                } else {
                    if let link = telegramLink, let url = URL(string: link.url) {
                        Link("1. Open @\(link.botUsername) in Telegram →", destination: url)
                            .font(ArchiveFont.regular(12))
                            .foregroundStyle(ArchiveColor.ink)
                            .underline()
                        Button("2. Verify Connection") {
                            Task {
                                do {
                                    try await appState.apiClient.verifyTelegramLink()
                                    telegramLink = nil
                                    notifySettings = try? await appState.apiClient.fetchNotifySettings()
                                } catch {
                                    notifyFeedback = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                                }
                            }
                        }
                        .buttonStyle(ArchivePrimaryButtonStyle(compact: true))
                    } else {
                        Button("Connect Telegram Bot") {
                            Task {
                                telegramLink = try? await appState.apiClient.startTelegramLink()
                            }
                        }
                        .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                    }
                }
                if let notifyFeedback {
                    Text(notifyFeedback)
                        .font(ArchiveFont.regular(11))
                        .foregroundStyle(ArchiveColor.muted)
                }
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(ArchiveColor.rowRule).frame(height: 1)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(ArchiveFont.medium(12))
            .foregroundStyle(ArchiveColor.ink)
    }

    private func saveDisplayName() async {
        isSavingName = true
        nameFeedback = nil
        defer { isSavingName = false }
        do {
            try await appState.apiClient.updateDisplayName(displayName.trimmingCharacters(in: .whitespacesAndNewlines))
            await appState.refreshSession()
            nameFeedback = "Display name saved."
        } catch {
            nameFeedback = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func saveEmail() async {
        isSavingEmail = true
        emailFeedback = nil
        defer { isSavingEmail = false }
        do {
            try await appState.apiClient.updateEmail(
                newEmail: newEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                currentPassword: emailPassword
            )
            newEmail = ""
            emailPassword = ""
            await appState.refreshSession()
            emailFeedback = "Email updated."
        } catch {
            emailFeedback = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func savePassword() async {
        isSavingPassword = true
        passwordFeedback = nil
        defer { isSavingPassword = false }
        do {
            try await appState.apiClient.updatePassword(currentPassword: currentPassword, newPassword: newPassword)
            currentPassword = ""
            newPassword = ""
            passwordFeedback = "Password updated."
        } catch {
            passwordFeedback = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func performSelfDelete() async {
        isDeletingAccount = true
        deleteError = nil
        defer { isDeletingAccount = false }
        do {
            try await appState.apiClient.deleteAccount(password: deletePassword)
            appState.currentUser = nil
            appState.blockedUsers = []
            appState.showBanner("Your account has been permanently deleted.")
        } catch {
            deleteError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
#endif

