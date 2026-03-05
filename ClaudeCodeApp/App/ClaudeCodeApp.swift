import SwiftUI

@main
struct ClaudeCodeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onOpenURL { url in
                    // GitHub OAuth コールバック処理
                    appState.handleOAuthCallback(url: url)
                }
        }
    }
}
