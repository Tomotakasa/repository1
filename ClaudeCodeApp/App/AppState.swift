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
    @Published var hasCompletedOnboarding: Bool = false

    // MARK: - Services
    let claudeService: ClaudeService
    let gitHubService: GitHubService
    private let keychainService = KeychainService()

    // MARK: - Init
    init() {
        let keychainService = KeychainService()
        let savedClaudeKey   = keychainService.load(key: KeychainKeys.claudeAPIKey) ?? ""
        let savedGitHubToken = keychainService.load(key: KeychainKeys.gitHubToken)  ?? ""

        self.claudeService = ClaudeService(apiKey: savedClaudeKey)
        self.gitHubService = GitHubService(token: savedGitHubToken)
        self.claudeAPIKey  = savedClaudeKey
        self.gitHubToken   = savedGitHubToken
        self.isGitHubAuthenticated  = !savedGitHubToken.isEmpty
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "onboarding_completed")

        if isGitHubAuthenticated {
            Task { await loadGitHubUser() }
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
            Task { await loadGitHubUser() }
        }
    }

    func logoutGitHub() {
        gitHubToken = ""
        gitHubService.updateToken("")
        keychainService.delete(key: KeychainKeys.gitHubToken)
        isGitHubAuthenticated = false
        gitHubUser = nil
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
        hasCompletedOnboarding = true
    }

    func handleOAuthCallback(url: URL) {
        guard let code = extractOAuthCode(from: url) else { return }
        Task { await exchangeOAuthCode(code) }
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
            gitHubUser = try await gitHubService.fetchCurrentUser()
        } catch {
            if case GitHubError.unauthorized = error { logoutGitHub() }
        }
    }
}

// MARK: - App Tab
enum AppTab: String, CaseIterable {
    case chat      = "chat"
    case library   = "library"
    case memory    = "memory"
    case save      = "save"
    case settings  = "settings"

    var title: String {
        switch self {
        case .chat:     return "チャット"
        case .library:  return "資料"
        case .memory:   return "記憶"
        case .save:     return "保存"
        case .settings: return "設定"
        }
    }

    var icon: String {
        switch self {
        case .chat:     return "bubble.left.and.bubble.right.fill"
        case .library:  return "books.vertical.fill"
        case .memory:   return "brain"
        case .save:     return "folder.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Keychain Keys
enum KeychainKeys {
    static let claudeAPIKey    = "claude_api_key"
    static let gitHubToken     = "github_token"
    static let customLLMAPIKey = "custom_llm_api_key"
}
