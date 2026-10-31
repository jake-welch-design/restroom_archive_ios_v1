#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

public struct AuthFormView: View {
    public enum Mode: String, CaseIterable, Hashable {
        case signIn
        case signUp
        case forgotPassword

        var label: String {
            switch self {
            case .signIn: return "Sign In"
            case .signUp: return "Create Account"
            case .forgotPassword: return "Reset Password"
            }
        }
    }

    @Environment(AppState.self) private var appState

    @State private var mode: Mode = .signIn
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var username: String = ""
    @State private var displayName: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var resetSentMessage: String?
    @State private var showLegalSheet: Bool = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ArchiveSegmentedBar(
                items: [
                    .init(id: Mode.signIn, label: "Sign In"),
                    .init(id: Mode.signUp, label: "Create Account")
                ],
                selection: Binding(
                    get: { mode == .forgotPassword ? .signIn : mode },
                    set: { newMode in
                        mode = newMode
                        errorMessage = nil
                        resetSentMessage = nil
                    }
                )
            )

            switch mode {
            case .signIn:
                signInFields
            case .signUp:
                signUpFields
            case .forgotPassword:
                forgotPasswordFields
            }
        }
        .sheet(isPresented: $showLegalSheet) {
            LegalSheet()
        }
    }

    private var signInFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sign in with the same email and password you use on restroomarchive.com.")
                .font(ArchiveFont.regular(12))
                .foregroundStyle(ArchiveColor.muted)

            VStack(alignment: .leading, spacing: 4) {
                Text("Email")
                    .font(ArchiveFont.medium(11))
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .archiveFieldStyle()
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Password")
                        .font(ArchiveFont.medium(11))
                    Spacer()
                    Button("Forgot password?") {
                        mode = .forgotPassword
                        errorMessage = nil
                    }
                    .buttonStyle(ArchiveLinkButtonStyle())
                }
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .archiveFieldStyle()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(ArchiveFont.regular(12))
                    .foregroundStyle(ArchiveColor.danger)
            }

            Button(isLoading ? "Signing in…" : "Sign In") {
                Task { await performSignIn() }
            }
            .buttonStyle(ArchivePrimaryButtonStyle())
            .disabled(isLoading || email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty)
        }
    }

    private var signUpFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accounts can post spatial annotations immediately and request Archivist submission access.")
                .font(ArchiveFont.regular(12))
                .foregroundStyle(ArchiveColor.muted)

            VStack(alignment: .leading, spacing: 4) {
                Text("Email *")
                    .font(ArchiveFont.medium(11))
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .archiveFieldStyle()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Username *")
                    .font(ArchiveFont.medium(11))
                TextField("lowercase letters, numbers, hyphens, underscores", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .archiveFieldStyle()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Display Name (optional, up to 25 chars)")
                    .font(ArchiveFont.medium(11))
                TextField("Shown on submissions and annotations", text: $displayName)
                    .archiveFieldStyle()
                    .onChange(of: displayName) { _, val in
                        if val.count > 25 {
                            displayName = String(val.prefix(25))
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Password * (at least 8 characters)")
                    .font(ArchiveFont.medium(11))
                SecureField("Minimum 8 characters", text: $password)
                    .textContentType(.newPassword)
                    .archiveFieldStyle()
            }

            HStack(spacing: 4) {
                Text("By creating an account you agree to the")
                    .font(ArchiveFont.regular(11))
                    .foregroundStyle(ArchiveColor.muted)
                Button("Privacy and Terms") {
                    showLegalSheet = true
                }
                .buttonStyle(ArchiveLinkButtonStyle())
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(ArchiveFont.regular(12))
                    .foregroundStyle(ArchiveColor.danger)
            }

            Button(isLoading ? "Creating account…" : "Create Account") {
                Task { await performSignUp() }
            }
            .buttonStyle(ArchivePrimaryButtonStyle())
            .disabled(
                isLoading ||
                    !email.contains("@") ||
                    username.trimmingCharacters(in: .whitespaces).count < 2 ||
                    password.count < 8
            )
        }
    }

    private var forgotPasswordFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter your account email and we will send a password reset link.")
                .font(ArchiveFont.regular(12))
                .foregroundStyle(ArchiveColor.muted)

            VStack(alignment: .leading, spacing: 4) {
                Text("Email")
                    .font(ArchiveFont.medium(11))
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .archiveFieldStyle()
            }

            if let resetSentMessage {
                Text(resetSentMessage)
                    .font(ArchiveFont.regular(12))
                    .foregroundStyle(ArchiveColor.publish)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(ArchiveFont.regular(12))
                    .foregroundStyle(ArchiveColor.danger)
            }

            HStack {
                Button("Back to Sign In") {
                    mode = .signIn
                    errorMessage = nil
                    resetSentMessage = nil
                }
                .buttonStyle(ArchiveLinkButtonStyle())

                Spacer()

                Button(isLoading ? "Sending…" : "Send Reset Link") {
                    Task { await performResetRequest() }
                }
                .buttonStyle(ArchivePrimaryButtonStyle())
                .disabled(isLoading || !email.contains("@"))
            }
        }
    }

    private func performSignIn() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let user = try await appState.apiClient.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            password = ""
            await appState.didAuthenticate(user: user)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func performSignUp() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let user = try await appState.apiClient.signUp(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                displayName: displayName
            )
            password = ""
            await appState.didAuthenticate(user: user)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func performResetRequest() async {
        isLoading = true
        errorMessage = nil
        resetSentMessage = nil
        defer { isLoading = false }
        do {
            try await appState.apiClient.requestPasswordReset(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            resetSentMessage = "If an account exists for \(email), a password reset link is on its way."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
#endif

