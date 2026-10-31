#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

public struct InfoView: View {
    @Environment(AppState.self) private var appState

    @State private var showGuideSheet: Bool = false
    @State private var showLegalSheet: Bool = false

    @State private var contactName: String = ""
    @State private var contactEmail: String = ""
    @State private var contactSubject: String = ""
    @State private var contactBody: String = ""
    @State private var contactLoading: Bool = false
    @State private var contactError: String?
    @State private var contactSubmitted: Bool = false

    public init() {}

    private var statsSentence: String {
        let s = appState.stats
        guard s.restrooms > 0 else { return "" }
        func plural(_ n: Int, _ one: String, _ many: String) -> String {
            "\(n) \(n == 1 ? one : many)"
        }
        let verb = s.archivists == 1 ? "has" : "have"
        let whereClause: String
        if let countries = s.countries {
            whereClause = "\(plural(s.cities, "city", "cities")) across \(plural(countries, "country", "countries"))"
        } else {
            whereClause = plural(s.cities, "city", "cities")
        }
        return "Currently, \(plural(s.archivists, "archivist", "archivists")) \(verb) documented \(plural(s.restrooms, "restroom", "restrooms")) in \(whereClause)."
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // About Section
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("About")

                    Text(
                        "The Restroom Archive is an ongoing repository of publicly accessible restrooms. Designed and built by Jake Welch, this archive aims to document the diverse qualities of these unique spaces. Everyone uses restrooms, yet as spaces, they are considered taboo and are rarely considered. There is perhaps no space in society that better captures the creativity and impertinence of humans when they know that nobody else is watching.\(statsSentence.isEmpty ? "" : " " + statsSentence)"
                    )
                    .font(ArchiveFont.regular(13))
                    .foregroundStyle(ArchiveColor.ink)
                    .lineSpacing(3)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Featured in:")
                            .font(ArchiveFont.regular(12))
                            .foregroundStyle(ArchiveColor.muted)

                        HStack(spacing: 12) {
                            Link("404 Media", destination: URL(string: "https://www.404media.co/the-man-on-a-quest-to-digitally-preserve-americas-public-restrooms/")!)
                            Link("VISLA Magazine", destination: URL(string: "https://visla.kr/feature/352064/?ckattempt=1")!)
                            Link("PAP Magazine", destination: URL(string: "https://www.pap-magazine.com/article/jake-welch-the-restroom-archive-3d-scan")!)
                        }
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.ink)
                        .underline()

                        HStack(spacing: 12) {
                            Link("Toilet Game Studies", destination: URL(string: "https://toiletgamestudies.org/interview_jake_welch")!)
                            Link("Instagram", destination: URL(string: "https://www.instagram.com/restroomarchive/")!)
                            Link("jakewelch.design", destination: URL(string: "https://jakewelch.design")!)
                        }
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.ink)
                        .underline()
                    }
                }

                divider

                // Become an Archivist
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Become an Archivist")

                    Text("Create an account and request submission access to contribute to the Archive.")
                        .font(ArchiveFont.regular(13))
                        .foregroundStyle(ArchiveColor.ink)

                    Button {
                        showGuideSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("Submission Guide")
                            Text("?")
                                .font(ArchiveFont.mono(10))
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(ArchiveColor.paper, lineWidth: 1))
                        }
                    }
                    .buttonStyle(ArchivePrimaryButtonStyle())

                    HStack(spacing: 4) {
                        Button("Click here to view the full terms") {
                            showLegalSheet = true
                        }
                        .buttonStyle(ArchiveLinkButtonStyle())
                        Text("for how the content in this Archive may be used.")
                            .font(ArchiveFont.regular(12))
                            .foregroundStyle(ArchiveColor.ink)
                    }
                }

                divider

                // Contact Form
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Contact")

                    if contactSubmitted {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Thanks, your message is on its way.")
                                .font(ArchiveFont.regular(13))
                                .foregroundStyle(ArchiveColor.ink)
                            Text("We'll reply to \(contactEmail) if a reply is needed.")
                                .font(ArchiveFont.regular(12))
                                .foregroundStyle(ArchiveColor.muted)
                            Button("Send another message") {
                                contactSubject = ""
                                contactBody = ""
                                contactSubmitted = false
                            }
                            .buttonStyle(ArchiveLinkButtonStyle())
                            .padding(.top, 4)
                        }
                    } else {
                        Text("Questions or feedback? Please feel free to reach out.")
                            .font(ArchiveFont.regular(13))
                            .foregroundStyle(ArchiveColor.ink)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Name")
                                .font(ArchiveFont.medium(11))
                            TextField("Your name", text: $contactName)
                                .archiveFieldStyle()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email")
                                .font(ArchiveFont.medium(11))
                            TextField("you@example.com", text: $contactEmail)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .archiveFieldStyle()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Subject")
                                .font(ArchiveFont.medium(11))
                            TextField("Subject", text: $contactSubject)
                                .archiveFieldStyle()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Message")
                                .font(ArchiveFont.medium(11))
                            TextEditor(text: $contactBody)
                                .font(ArchiveFont.regular(13))
                                .frame(minHeight: 96)
                                .padding(4)
                                .overlay(Rectangle().stroke(ArchiveColor.inputBorder, lineWidth: 1))
                        }

                        if let contactError {
                            Text(contactError)
                                .font(ArchiveFont.regular(12))
                                .foregroundStyle(ArchiveColor.danger)
                        }

                        Button(contactLoading ? "Sending…" : "Send") {
                            Task { await submitContact() }
                        }
                        .buttonStyle(ArchivePrimaryButtonStyle())
                        .disabled(!canSubmitContact || contactLoading)
                    }
                }

                divider

                // Footer
                HStack(spacing: 6) {
                    Text("© 2026 Jake Welch")
                    Text("•")
                    Button("Privacy and Terms") {
                        showLegalSheet = true
                    }
                    .buttonStyle(ArchiveLinkButtonStyle())
                }
                .font(ArchiveFont.regular(11))
                .foregroundStyle(ArchiveColor.muted)
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background(ArchiveColor.paper)
        .onAppear {
            if let user = appState.currentUser {
                if contactEmail.isEmpty { contactEmail = user.email }
                if contactName.isEmpty { contactName = user.displayName ?? user.username }
            }
        }
        .sheet(isPresented: $showGuideSheet) {
            SubmissionGuideSheet()
        }
        .sheet(isPresented: $showLegalSheet) {
            LegalSheet()
        }
    }

    private var canSubmitContact: Bool {
        !contactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            contactEmail.contains("@") &&
            !contactSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !contactBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var divider: some View {
        Rectangle().fill(ArchiveColor.rowRule).frame(height: 1)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(ArchiveFont.regular(13))
            .foregroundStyle(ArchiveColor.muted)
    }

    private func submitContact() async {
        contactLoading = true
        contactError = nil
        defer { contactLoading = false }
        do {
            try await appState.apiClient.sendContactMessage(
                ContactFormRequest(
                    name: contactName.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: contactEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                    subject: contactSubject.trimmingCharacters(in: .whitespacesAndNewlines),
                    body: contactBody.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
            contactSubmitted = true
        } catch {
            contactError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
#endif

