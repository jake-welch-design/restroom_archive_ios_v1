#if canImport(SwiftUI)
import SwiftUI

public struct LegalSheet: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Privacy and Terms")
                    .font(ArchiveFont.regular(14))
                    .foregroundStyle(ArchiveColor.muted)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("×")
                        .font(ArchiveFont.regular(20))
                        .foregroundStyle(ArchiveColor.ink)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                Rectangle().fill(ArchiveColor.rule).frame(height: 1)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    majorHeading("Terms")

                    subHeading("1. Scope")
                    bodyText("These terms cover use of The Restroom Archive. Submitting a scan additionally accepts section 2.")

                    subHeading("2. Ownership and license")
                    bodyText("Archivists own their scans and keep copyright in them. Contributing transfers no ownership and places no limit on an Archivist's use of their own work.")
                    bodyText("Submission grants the archive a sole, perpetual, irrevocable, worldwide license to store, preserve, display, and present the scan, including the technical copies hosting requires: thumbnails, compressed versions, and format conversions. Sole means the archive is the only party that may hold these rights, and that the Archivist will not license the same scan elsewhere while it remains in the archive.")
                    bodyText("Submission confirms the scan is the Archivist's own work and that they held the right to scan the space.")

                    subHeading("3. How scans are used")
                    bodyText("Contributed scans are used on this site and app and nowhere else. The archive does not:")
                    bulletText("Sell, rent, or otherwise commercialise them.")
                    bulletText("Transfer or assign them unless these commitments transfer intact.")
                    bulletText("Sublicense or redistribute them. There are no dataset releases, bulk exports, partner feeds, or download endpoints.")
                    bulletText("Use them, or permit their use, as training, fine-tuning, evaluation, or grounding data for machine learning models.")

                    subHeading("4. Use by others")
                    bodyText("All rights reserved. Viewing, browsing, linking, citing, and writing about the archive are permitted. No license to reuse the scans is granted to any party. Downloading, extracting, redistributing, and building on scan geometry require written permission.")
                    bodyText("Machine learning use is prohibited and expressly reserved under Article 4(3) of Directive (EU) 2019/790 and equivalent text-and-data-mining provisions in other jurisdictions, regardless of how a copy was obtained.")

                    subHeading("5. Accounts")
                    bodyText("Account holders are responsible for activity under their account. Submission access is granted case by case and may be revoked. Scans are reviewed before publication, and the archive may decline or remove any submission.")

                    subHeading("6. Removal")
                    bodyText("Contributions are intended to be permanent. Deleting an account removes the account and its annotations and detaches the Archivist's name from their scans, which remain in the archive unattributed. Full removal may be requested in writing. Requests are reviewed individually and granted at the archive's discretion.")

                    subHeading("7. Changes")
                    bodyText("These terms may change. Material changes affecting contributors will be communicated to Archivists directly. The commitments in section 3 will not be weakened.")

                    majorHeading("Privacy")

                    bodyText("The Restroom Archive runs no analytics, tracking pixels, advertising, third-party cookies, or data brokers. Visitor activity is not profiled, and personal information is never sold, rented, or shared for marketing.")

                    subHeading("Data collected")
                    bodyText("Accounts store an email address, username, optional display name, and a password hash (scrypt, with a per-account salt). Submissions store the scan with the restroom's name, location, coordinates, description, and tags. Annotations store their text and position. IP addresses are retained for under one hour for rate limiting, then deleted.")

                    subHeading("Public information")
                    bodyText("Usernames, display names, scans, and annotations are public. Email addresses are never displayed and are used only for account verification, password resets, and replies.")

                    subHeading("Third-party processors")
                    bodyText("Cloudflare hosts the backend, database, and files. Plunk sends account and contact emails, and receives recipient addresses. On the map view, tiles load directly from CARTO and Esri, which receive visitor IP addresses and the map area requested. No other third party receives data.")

                    subHeading("Authentication storage")
                    bodyText("On iOS, your signed-in session token is stored solely in the device Keychain and deleted immediately when you sign out or delete your account.")

                    subHeading("Scans and people")
                    bodyText("Archivists agree not to scan a restroom while other people are present, and all scans are reviewed before publication. Scans that capture identifying or private content are removed on report.")

                    subHeading("Access and deletion")
                    bodyText("Accounts can be deleted at any time from the Account tab, which immediately removes the account and its annotations. Corrections, takedown requests, and questions about stored data go through the contact form on the Info tab.")

                    Text("Last updated 1 September 2026.")
                        .font(ArchiveFont.regular(12))
                        .foregroundStyle(ArchiveColor.muted)
                        .padding(.top, 8)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(ArchiveColor.paper)
    }

    private func majorHeading(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(ArchiveFont.regular(14))
                .foregroundStyle(ArchiveColor.muted)
            Rectangle().fill(ArchiveColor.rule).frame(height: 1)
        }
        .padding(.top, 6)
    }

    private func subHeading(_ title: String) -> some View {
        Text(title)
            .font(ArchiveFont.bold(13))
            .foregroundStyle(ArchiveColor.ink)
            .padding(.top, 4)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(ArchiveFont.regular(13))
            .foregroundStyle(ArchiveColor.ink)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bulletText(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(ArchiveFont.bold(13))
            Text(text)
                .font(ArchiveFont.regular(13))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(ArchiveColor.ink)
        .padding(.leading, 8)
    }
}
#endif

