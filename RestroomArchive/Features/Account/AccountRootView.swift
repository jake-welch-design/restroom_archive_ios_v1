#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

public struct AccountRootView: View {
    public enum SubTab: String, CaseIterable, Hashable {
        case profile
        case submissions
        case annotations
        case access

        var label: String {
            switch self {
            case .profile: return "Profile"
            case .submissions: return "Submissions"
            case .annotations: return "Annotations"
            case .access: return "Archivist Access"
            }
        }
    }

    @Environment(AppState.self) private var appState
    @State private var selectedTab: SubTab = .profile

    public init() {}

    public var body: some View {
        Group {
            if let user = appState.currentUser {
                VStack(spacing: 0) {
                    let tabs: [SubTab] = user.canSubmit
                        ? [.profile, .submissions, .annotations]
                        : [.profile, .access, .annotations]

                    ArchiveUnderlineTabs(
                        items: tabs.map { .init(id: $0, label: $0.label) },
                        selection: $selectedTab
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    switch selectedTab {
                    case .profile:
                        ProfileSettingsView(user: user)
                    case .submissions:
                        MySubmissionsView()
                    case .annotations:
                        MyAnnotationsView()
                    case .access:
                        ScrollView {
                            SubmissionAccessRequestView()
                                .padding(16)
                        }
                    }
                }
            } else if appState.isBootstrappingSession {
                VStack {
                    ProgressView().tint(ArchiveColor.ink)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    AuthFormView()
                        .padding(16)
                }
            }
        }
        .background(ArchiveColor.paper)
    }
}
#endif

