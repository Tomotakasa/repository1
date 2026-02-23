import Foundation
import Combine

/// アプリ全体の状態を管理するクラス
@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties
    @Published var isGitHubAuthenticated: Bool = false
    @Published var gitHubUser: GitHubUser? = nil
    @Published var claudeAPIKey: String = ""
    @Published var gitHubToken: String = ""
    @Published var selectedTab: AppTab = .chat
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false

    // MARK: - Services
    let claudeService: ClaudeService
    let gitHubService: GitHubService
    private let keychainService = KeychainService()

    // MARK: - Init
    init() {
        let keychainService = KeychainService()
        let savedClaudeKey = keychainService.load(key: KeychainKeys.claudeAPIKey) ?? ""
        let savedGitHubToken = keychainService.load(key: KeychainKeys.gitHubToken) ?? ""

        self.claudeService = ClaudeService(apiKey: savedClaudeKey)
        self.gitHubService = GitHubService(token: savedGitHubToken)
        self.claudeAPIKey = savedClaudeKey
        self.gitHubToken = savedGitHubToken
        self.isGitHubAuthenticated = !savedGitHubToken.isEmpty

        if isGitHubAuthenticated {
            Task {
                await loadGitHubUser()
            }
        }
    }

    // MARK: - Auth Methods
    func saveClaudeAPIKey(_ key: String) {
        claudeAPIKey = key
        claudeService.updateAPIKey(key)
        keychainService.save(key: KeychainKeys.claudeAPIKey, value: key)
    }

    func saveGitHubToken(_ token: String) {
        gitHubToken = token
        gitHubService.updateToken(token)
        keychainService.save(key: KeychainKeys.gitHubToken, value: token)
        isGitHubAuthenticated = !token.isEmpty
        if isGitHubAuthenticated {
            Task {
                await loadGitHubUser()
            }
        }
    }

    func logoutGitHub() {
        gitHubToken = ""
        gitHubService.updateToken("")
        keychainService.delete(key: KeychainKeys.gitHubToken)
        isGitHubAuthenticated = false
        gitHubUser = nil
    }

    func handleOAuthCallback(url: URL) {
        guard let code = extractOAuthCode(from: url) else { return }
        Task {
            await exchangeOAuthCode(code)
        }
    }

    private func extractOAuthCode(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let codeItem = components.queryItems?.first(where: { $0.name == "code" }) else {
            return nil
        }
        return codeItem.value
    }

    private func exchangeOAuthCode(_ code: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let token = try await gitHubService.exchangeOAuthCode(code)
            saveGitHubToken(token)
        } catch {
            errorMessage = "GitHub認証に失敗しました: \(error.localizedDescription)"
        }
    }

    private func loadGitHubUser() async {
        do {
            let user = try await gitHubService.fetchCurrentUser()
            gitHubUser = user
        } catch {
            // サイレントに失敗（トークンが無効な場合は認証状態をリセット）
            if case GitHubError.unauthorized = error {
                logoutGitHub()
            }
        }
    }
}

// MARK: - App Tab
enum AppTab: String, CaseIterable {
    case chat = "chat"
    case github = "github"
    case settings = "settings"

    var title: String {
        switch self {
        case .chat: return "チャット"
        case .github: return "GitHub"
        case .settings: return "設定"
        }
    }

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .github: return "doc.text.magnifyingglass"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - Keychain Keys
enum KeychainKeys {
    static let claudeAPIKey = "claude_api_key"
    static let gitHubToken = "github_token"
}
