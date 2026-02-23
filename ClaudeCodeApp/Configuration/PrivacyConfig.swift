import Foundation

/// プライバシー・セキュリティ設定を管理するシングルトン
/// すべてのネットワーク通信先をユーザーが制御できます
final class PrivacyConfig: ObservableObject {
    static let shared = PrivacyConfig()

    private let keychainService = KeychainService()
    private let defaults = UserDefaults.standard

    // MARK: - LLM設定
    /// 使用するLLMバックエンド
    @Published var llmBackend: LLMBackend {
        didSet { defaults.set(llmBackend.rawValue, forKey: "llm_backend") }
    }

    /// カスタムエンドポイントURL（OllamaやプライベートAPIサーバー等）
    @Published var customLLMEndpoint: String {
        didSet { defaults.set(customLLMEndpoint, forKey: "custom_llm_endpoint") }
    }

    /// Ollamaで使用するモデル名
    @Published var ollamaModel: String {
        didSet { defaults.set(ollamaModel, forKey: "ollama_model") }
    }

    // MARK: - Git/VCS設定
    /// 使用するVCSバックエンド
    @Published var vcsBackend: VCSBackend {
        didSet { defaults.set(vcsBackend.rawValue, forKey: "vcs_backend") }
    }

    /// プライベートGit APIのベースURL（GitHub Enterprise, Gitea等）
    @Published var customVCSBaseURL: String {
        didSet { defaults.set(customVCSBaseURL, forKey: "custom_vcs_base_url") }
    }

    // MARK: - データ保護
    /// ローカルデータの暗号化を有効化
    @Published var enableLocalEncryption: Bool {
        didSet { defaults.set(enableLocalEncryption, forKey: "enable_local_encryption") }
    }

    /// 会話履歴をデバイスに保存するか
    @Published var persistConversationHistory: Bool {
        didSet { defaults.set(persistConversationHistory, forKey: "persist_conversation_history") }
    }

    /// チャット入力からクリップボードを使用後に自動クリア
    @Published var autoClearClipboard: Bool {
        didSet { defaults.set(autoClearClipboard, forKey: "auto_clear_clipboard") }
    }

    // MARK: - ネットワーク設定
    /// SSL証明書の検証をスキップ（自己署名証明書を使うプライベートサーバー向け）
    @Published var skipSSLVerification: Bool {
        didSet { defaults.set(skipSSLVerification, forKey: "skip_ssl_verification") }
    }

    /// プロキシ設定
    @Published var proxyHost: String {
        didSet { defaults.set(proxyHost, forKey: "proxy_host") }
    }
    @Published var proxyPort: Int {
        didSet { defaults.set(proxyPort, forKey: "proxy_port") }
    }

    // MARK: - Init
    private init() {
        let defaults = UserDefaults.standard

        self.llmBackend = LLMBackend(rawValue: defaults.string(forKey: "llm_backend") ?? "") ?? .claudeAPI
        self.customLLMEndpoint = defaults.string(forKey: "custom_llm_endpoint") ?? "http://localhost:11434"
        self.ollamaModel = defaults.string(forKey: "ollama_model") ?? "llama3.2"
        self.vcsBackend = VCSBackend(rawValue: defaults.string(forKey: "vcs_backend") ?? "") ?? .githubCloud
        self.customVCSBaseURL = defaults.string(forKey: "custom_vcs_base_url") ?? ""
        self.enableLocalEncryption = defaults.bool(forKey: "enable_local_encryption")
        self.persistConversationHistory = defaults.object(forKey: "persist_conversation_history") as? Bool ?? true
        self.autoClearClipboard = defaults.bool(forKey: "auto_clear_clipboard")
        self.skipSSLVerification = defaults.bool(forKey: "skip_ssl_verification")
        self.proxyHost = defaults.string(forKey: "proxy_host") ?? ""
        self.proxyPort = defaults.integer(forKey: "proxy_port")
    }

    // MARK: - Derived Properties

    /// 現在のLLMエンドポイントURL
    var effectiveLLMBaseURL: String {
        switch llmBackend {
        case .claudeAPI:
            return "https://api.anthropic.com/v1"
        case .ollama:
            let url = customLLMEndpoint.isEmpty ? "http://localhost:11434" : customLLMEndpoint
            return url.hasSuffix("/") ? String(url.dropLast()) : url
        case .customOpenAICompatible:
            let url = customLLMEndpoint.isEmpty ? "http://localhost:8080/v1" : customLLMEndpoint
            return url.hasSuffix("/") ? String(url.dropLast()) : url
        }
    }

    /// 現在のVCS APIベースURL
    var effectiveVCSBaseURL: String {
        switch vcsBackend {
        case .githubCloud:
            return "https://api.github.com"
        case .githubEnterprise, .gitea, .gitlab:
            return customVCSBaseURL.isEmpty ? "https://your-server.example.com/api/v1" : customVCSBaseURL
        }
    }

    /// データがローカルのみか（外部送信なし）
    var isFullyLocalMode: Bool {
        return llmBackend == .ollama || llmBackend == .customOpenAICompatible
    }
}

// MARK: - LLM Backend
enum LLMBackend: String, CaseIterable, Identifiable {
    case claudeAPI = "claude_api"
    case ollama = "ollama"
    case customOpenAICompatible = "openai_compatible"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claudeAPI: return "Claude API (Anthropic)"
        case .ollama: return "Ollama (ローカル)"
        case .customOpenAICompatible: return "カスタムサーバー (OpenAI互換)"
        }
    }

    var description: String {
        switch self {
        case .claudeAPI:
            return "Anthropicのクラウドサービス。高精度ですが、データは外部サーバーに送信されます。"
        case .ollama:
            return "完全ローカル処理。データは外部に送信されません。事前にOllamaのインストールが必要です。"
        case .customOpenAICompatible:
            return "自社/プライベートサーバー上のLLMを使用。OpenAI互換APIに対応したサーバーが必要です。"
        }
    }

    var isPrivate: Bool {
        return self != .claudeAPI
    }
}

// MARK: - VCS Backend
enum VCSBackend: String, CaseIterable, Identifiable {
    case githubCloud = "github_cloud"
    case githubEnterprise = "github_enterprise"
    case gitea = "gitea"
    case gitlab = "gitlab"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .githubCloud: return "GitHub.com"
        case .githubEnterprise: return "GitHub Enterprise (社内)"
        case .gitea: return "Gitea (セルフホスト)"
        case .gitlab: return "GitLab (セルフホスト)"
        }
    }

    var description: String {
        switch self {
        case .githubCloud:
            return "github.comのクラウドサービス。データはGitHubのサーバーに保存されます。"
        case .githubEnterprise:
            return "社内GitHub Enterpriseサーバー。社内ネットワーク内でデータを管理できます。"
        case .gitea:
            return "オープンソースのセルフホストGitサービス。完全に自社サーバーで管理できます。"
        case .gitlab:
            return "セルフホストGitLab。完全に自社サーバーで管理できます。"
        }
    }

    var isPrivate: Bool {
        return self != .githubCloud
    }
}
