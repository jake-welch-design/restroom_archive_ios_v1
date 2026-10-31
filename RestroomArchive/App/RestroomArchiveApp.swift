#if canImport(SwiftUI) && canImport(UIKit) && canImport(WebKit)
import ArchiveCore
import SwiftUI

@main
struct RestroomArchiveApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ArchiveShellView()
                .environment(appState)
                .preferredColorScheme(.light)
                .task {
                    await appState.bootstrap()
                }
                .onOpenURL { url in
                    appState.handleIncomingURL(url)
                }
        }
    }
}
#endif

