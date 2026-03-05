import Foundation

/// アプリ設定の定数定義
enum AppConfig {
    // MARK: - バンドル情報
    static let bundleIdentifier = "com.claudecodeapp"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

    // MARK: - GitHub OAuth URL Scheme
    static let oauthCallbackScheme = "claudecodeapp"
    static let oauthCallbackHost = "oauth"
    static let oauthCallbackPath = "/callback"
    static let oauthCallbackURL = "\(oauthCallbackScheme)://\(oauthCallbackHost)\(oauthCallbackPath)"

    // MARK: - ネットワーク
    static let defaultRequestTimeout: TimeInterval = 120
    static let defaultOllamaEndpoint = "http://localhost:11434"

    // MARK: - ページネーション
    static let defaultPageSize = 30
    static let maxPageSize = 100

    // MARK: - ファイルサイズ制限
    /// GitHub APIで直接取得できるファイルサイズの上限 (1MB)
    static let maxDirectFetchSize = 1_000_000

    // MARK: - UI設定
    static let maxMessageBubbleWidth: CGFloat = 0.75
    static let codeEditorFontSize: CGFloat = 12

    // MARK: - セキュリティ
    static let keychainService = "com.claudecodeapp.keychain"
    static let conversationEncryptionKeyName = "conversation_encryption_key"
}

/// ビルド設定から取得する機密情報
/// Xcodeのビルド設定または環境変数から取得します
enum SecretsConfig {
    static var githubClientID: String {
        Bundle.main.infoDictionary?["GITHUB_CLIENT_ID"] as? String ?? ""
    }

    static var githubClientSecret: String {
        // 注意: クライアントシークレットはサーバーサイドで処理することを推奨
        // このアプリでは学習・デモ目的でクライアントに保持しています
        Bundle.main.infoDictionary?["GITHUB_CLIENT_SECRET"] as? String ?? ""
    }
}
