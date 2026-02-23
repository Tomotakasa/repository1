import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            // チャット画面
            NavigationStack {
                ChatView()
            }
            .tabItem {
                Label(AppTab.chat.title, systemImage: AppTab.chat.icon)
            }
            .tag(AppTab.chat)

            // GitHub連携画面
            NavigationStack {
                GitHubView()
            }
            .tabItem {
                Label(AppTab.github.title, systemImage: AppTab.github.icon)
            }
            .tag(AppTab.github)

            // 設定画面
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(AppTab.settings.title, systemImage: AppTab.settings.icon)
            }
            .tag(AppTab.settings)
        }
        .alert("エラー", isPresented: .init(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK") { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }
}
