#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

public struct AdminAnnotationsSection: View {
    public enum SubTab: String, CaseIterable, Hashable {
        case all
        case reports
    }

    @Environment(AppState.self) private var appState
    @State private var subTab: SubTab = .all
    @State private var allAnnotations: [AdminAnnotation] = []
    @State private var reports: [AnnotationReportItem] = []
    @State private var isLoading: Bool = true

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            ArchiveUnderlineTabs(
                items: [
                    .init(id: SubTab.all, label: "All (\(allAnnotations.count))"),
                    .init(id: SubTab.reports, label: "Reports", badge: reports.count)
                ],
                selection: $subTab
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if isLoading {
                VStack { ProgressView().tint(ArchiveColor.ink) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if subTab == .all {
                allAnnotationsList
            } else {
                reportsList
            }
        }
        .task { await reload() }
    }

    private var allAnnotationsList: some View {
        Group {
            if allAnnotations.isEmpty {
                emptyText("No annotations recorded.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(allAnnotations) { ann in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(ann.restroom.name)
                                        .font(ArchiveFont.bold(12))
                                    if ann.hiddenAt != nil {
                                        ArchivePillBadge("Hidden", tone: .danger)
                                    }
                                    if ann.openReportCount > 0 {
                                        ArchivePillBadge("\(ann.openReportCount) reports", tone: .warn)
                                    }
                                    Spacer()
                                    Text(ArchiveDateFormatter.formatMonthDayYear(ann.createdAt))
                                        .font(ArchiveFont.regular(11))
                                        .foregroundStyle(ArchiveColor.muted)
                                }

                                Text(ann.body)
                                    .font(ArchiveFont.regular(12.5))

                                HStack(spacing: 12) {
                                    if let author = ann.author {
                                        Text("By @\(author.username)")
                                            .font(ArchiveFont.regular(11))
                                            .foregroundStyle(ArchiveColor.muted)
                                    }
                                    Spacer()
                                    Button("Open Scan") {
                                        appState.selectRestroom(slug: ann.restroom.slug, initialAnnotationId: ann.id)
                                    }
                                    .buttonStyle(ArchiveLinkButtonStyle())

                                    if ann.hiddenAt == nil {
                                        Button("Hide") {
                                            Task {
                                                try? await appState.apiClient.adminHideAnnotation(id: ann.id)
                                                await reload()
                                            }
                                        }
                                        .buttonStyle(ArchiveActionButtonStyle(tone: .reject))
                                    } else {
                                        Button("Unhide") {
                                            Task {
                                                try? await appState.apiClient.adminUnhideAnnotation(id: ann.id)
                                                await reload()
                                            }
                                        }
                                        .buttonStyle(ArchiveOutlineButtonStyle(compact: true))
                                    }
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

    private var reportsList: some View {
        Group {
            if reports.isEmpty {
                emptyText("No open annotation reports.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(reports) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(item.restroom.name)")
                                    .font(ArchiveFont.bold(12.5))
                                Text("\"\(item.annotation.body)\"")
                                    .font(ArchiveFont.regular(12))
                                if let reason = item.reportReason, !reason.isEmpty {
                                    Text("Reported reason: \(reason)")
                                        .font(ArchiveFont.regular(11.5))
                                        .foregroundStyle(ArchiveColor.danger)
                                }
                                HStack(spacing: 8) {
                                    Button("Hide Annotation") {
                                        Task {
                                            try? await appState.apiClient.adminHideAnnotation(id: item.annotation.id)
                                            await reload()
                                        }
                                    }
                                    .buttonStyle(ArchiveActionButtonStyle(tone: .reject))

                                    Button("Dismiss Reports") {
                                        Task {
                                            try? await appState.apiClient.adminDismissAnnotationReports(id: item.annotation.id)
                                            await reload()
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

    private func emptyText(_ text: String) -> some View {
        VStack {
            Text(text)
                .font(ArchiveFont.regular(12))
                .foregroundStyle(ArchiveColor.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func reload() async {
        isLoading = true
        async let a = try? appState.apiClient.fetchAdminAnnotations()
        async let r = try? appState.apiClient.fetchAdminAnnotationReports()
        let (aVal, rVal) = await (a, r)
        allAnnotations = aVal ?? []
        reports = rVal ?? []
        appState.adminReportsCount = reports.count
        isLoading = false
    }
}
#endif

