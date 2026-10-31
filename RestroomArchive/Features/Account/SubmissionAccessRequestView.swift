#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

public struct SubmissionAccessRequestView: View {
    @Environment(AppState.self) private var appState

    @State private var checkedIndices: Set<Int> = []
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var showGuideSheet: Bool = false

    public init() {}

    public var body: some View {
        let agreements = SubmissionAgreements.all

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Archivist Submission Access")
                    .font(ArchiveFont.bold(14))
                    .foregroundStyle(ArchiveColor.ink)
                Spacer()
                Button("Submission Guide ?") {
                    showGuideSheet = true
                }
                .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
            }

            if appState.currentUser?.submissionRequested == true {
                VStack(alignment: .leading, spacing: 8) {
                    ArchivePillBadge("Request Pending Review", tone: .warn)
                    Text("Your request to contribute 3D restroom scans is awaiting admin approval. You can review the Submission Guide while you wait.")
                        .font(ArchiveFont.regular(12.5))
                        .foregroundStyle(ArchiveColor.ink)
                        .lineSpacing(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ArchiveColor.hoverFill)
                .overlay(Rectangle().stroke(ArchiveColor.rule, lineWidth: 1))
            } else {
                Text("Read the Submission Guide and confirm all eight commitments below to request Archivist access.")
                    .font(ArchiveFont.regular(12.5))
                    .foregroundStyle(ArchiveColor.muted)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(agreements.enumerated()), id: \.offset) { idx, clause in
                        let checked = checkedIndices.contains(idx)
                        Button {
                            if checked {
                                checkedIndices.remove(idx)
                            } else {
                                checkedIndices.insert(idx)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 9) {
                                Image(systemName: checked ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 15))
                                    .foregroundStyle(ArchiveColor.ink)
                                    .padding(.top, 1)

                                Text(clause)
                                    .font(ArchiveFont.regular(12))
                                    .foregroundStyle(ArchiveColor.ink)
                                    .multilineTextAlignment(.leading)
                                    .lineSpacing(1.5)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(ArchiveColor.hoverFill)
                .overlay(Rectangle().stroke(ArchiveColor.rule, lineWidth: 1))

                if let errorMessage {
                    Text(errorMessage)
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.danger)
                }

                Button(isSubmitting ? "Requesting…" : "Request Submission Access") {
                    Task { await submitAccessRequest() }
                }
                .buttonStyle(ArchivePrimaryButtonStyle())
                .disabled(checkedIndices.count < agreements.count || isSubmitting)
            }
        }
        .sheet(isPresented: $showGuideSheet) {
            SubmissionGuideSheet()
        }
    }

    private func submitAccessRequest() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await appState.apiClient.requestSubmissionAccess(agreements: SubmissionAgreements.all)
            await appState.refreshSession()
            appState.showBanner("Submission access requested.")
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
#endif

