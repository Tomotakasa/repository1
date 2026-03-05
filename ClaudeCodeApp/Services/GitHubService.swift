import Foundation

// MARK: - GitHub Service
/// GitHub APIとの通信を担当するサービス
actor GitHubService {
    private var token: String
    private let baseURL = "https://api.github.com"
    private let oauthURL = "https://github.com/login/oauth"
    private let urlSession: URLSession

    // GitHub OAuth App設定 (Info.plistから取得)
    private var clientID: String {
        Bundle.main.infoDictionary?["GITHUB_CLIENT_ID"] as? String ?? ""
    }
    private var clientSecret: String {
        Bundle.main.infoDictionary?["GITHUB_CLIENT_SECRET"] as? String ?? ""
    }

    init(token: String) {
        self.token = token
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.urlSession = URLSession(configuration: config)
    }

    func updateToken(_ token: String) {
        self.token = token
    }

    // MARK: - OAuth
    /// GitHub OAuthの認証URLを生成
    func buildOAuthURL(redirectURI: String = "claudecodeapp://oauth/callback") -> URL? {
        var components = URLComponents(string: "\(oauthURL)/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "scope", value: "repo,user"),
            URLQueryItem(name: "redirect_uri", value: redirectURI)
        ]
        return components?.url
    }

    /// OAuth codeをアクセストークンに交換
    func exchangeOAuthCode(_ code: String) async throws -> String {
        guard let url = URL(string: "\(oauthURL)/access_token") else {
            throw GitHubError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)
        try validateResponse(response)

        let json = try JSONDecoder().decode([String: String].self, from: data)
        guard let token = json["access_token"] else {
            throw GitHubError.tokenExchangeFailed
        }
        return token
    }

    // MARK: - User
    /// 現在のユーザー情報を取得
    func fetchCurrentUser() async throws -> GitHubUser {
        let request = try buildRequest(endpoint: "/user")
        let (data, response) = try await urlSession.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(GitHubUser.self, from: data)
    }

    // MARK: - Repositories
    /// ユーザーのリポジトリ一覧を取得
    func fetchRepositories(page: Int = 1, perPage: Int = 30) async throws -> [GitHubRepository] {
        let endpoint = "/user/repos?sort=updated&per_page=\(perPage)&page=\(page)"
        let request = try buildRequest(endpoint: endpoint)
        let (data, response) = try await urlSession.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode([GitHubRepository].self, from: data)
    }

    /// 特定リポジトリの情報を取得
    func fetchRepository(owner: String, repo: String) async throws -> GitHubRepository {
        let request = try buildRequest(endpoint: "/repos/\(owner)/\(repo)")
        let (data, response) = try await urlSession.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(GitHubRepository.self, from: data)
    }

    // MARK: - Contents
    /// ディレクトリ/ファイル一覧を取得
    func fetchContents(owner: String, repo: String, path: String = "", branch: String? = nil) async throws -> [GitHubContent] {
        var endpoint = "/repos/\(owner)/\(repo)/contents/\(path)"
        if let branch = branch {
            endpoint += "?ref=\(branch)"
        }
        let request = try buildRequest(endpoint: endpoint)
        let (data, response) = try await urlSession.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode([GitHubContent].self, from: data)
    }

    /// ファイルの内容を取得
    func fetchFileContent(owner: String, repo: String, path: String, branch: String? = nil) async throws -> GitHubFileContent {
        var endpoint = "/repos/\(owner)/\(repo)/contents/\(path)"
        if let branch = branch {
            endpoint += "?ref=\(branch)"
        }
        let request = try buildRequest(endpoint: endpoint)
        let (data, response) = try await urlSession.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(GitHubFileContent.self, from: data)
    }

    // MARK: - File Operations
    /// ファイルを新規作成またはアップデート
    func createOrUpdateFile(
        owner: String,
        repo: String,
        path: String,
        content: String,
        message: String,
        branch: String? = nil,
        sha: String? = nil  // 更新の場合は既存ファイルのSHAが必要
    ) async throws -> GitHubCommitResponse {
        guard let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)") else {
            throw GitHubError.invalidURL
        }

        // コンテンツをBase64エンコード
        guard let contentData = content.data(using: .utf8) else {
            throw GitHubError.encodingFailed
        }
        let base64Content = contentData.base64EncodedString()

        var request = URLRequest(url: url)
        request.httpMethod = sha != nil ? "PUT" : "PUT"  // 作成も更新もPUT
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        var body: [String: Any] = [
            "message": message,
            "content": base64Content
        ]
        if let branch = branch { body["branch"] = branch }
        if let sha = sha { body["sha"] = sha }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(GitHubCommitResponse.self, from: data)
    }

    /// ファイルを削除
    func deleteFile(
        owner: String,
        repo: String,
        path: String,
        message: String,
        sha: String,
        branch: String? = nil
    ) async throws {
        guard let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)") else {
            throw GitHubError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        var body: [String: Any] = [
            "message": message,
            "sha": sha
        ]
        if let branch = branch { body["branch"] = branch }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await urlSession.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Branches
    /// ブランチ一覧を取得
    func fetchBranches(owner: String, repo: String) async throws -> [GitHubBranch] {
        let request = try buildRequest(endpoint: "/repos/\(owner)/\(repo)/branches")
        let (data, response) = try await urlSession.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode([GitHubBranch].self, from: data)
    }

    // MARK: - Search
    /// リポジトリを検索
    func searchRepositories(query: String, page: Int = 1) async throws -> [GitHubRepository] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let endpoint = "/search/repositories?q=\(encoded)&sort=stars&per_page=20&page=\(page)"
        let request = try buildRequest(endpoint: endpoint)
        let (data, response) = try await urlSession.data(for: request)
        try validateResponse(response)
        let searchResult = try JSONDecoder().decode(GitHubSearchResult.self, from: data)
        return searchResult.items
    }

    // MARK: - Private Helpers
    private func buildRequest(endpoint: String) throws -> URLRequest {
        guard !token.isEmpty else {
            throw GitHubError.unauthorized
        }
        guard let url = URL(string: baseURL + endpoint) else {
            throw GitHubError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        return request
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200...299: break
        case 401: throw GitHubError.unauthorized
        case 403: throw GitHubError.forbidden
        case 404: throw GitHubError.notFound
        case 422: throw GitHubError.unprocessableEntity
        default: throw GitHubError.httpError(httpResponse.statusCode)
        }
    }
}

// MARK: - GitHub Errors
enum GitHubError: LocalizedError {
    case unauthorized
    case forbidden
    case notFound
    case invalidURL
    case invalidResponse
    case tokenExchangeFailed
    case encodingFailed
    case unprocessableEntity
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "GitHubの認証に失敗しました。再度ログインしてください。"
        case .forbidden:
            return "このリソースへのアクセス権限がありません。"
        case .notFound:
            return "リソースが見つかりません。"
        case .invalidURL:
            return "無効なURLです。"
        case .invalidResponse:
            return "無効なレスポンスを受信しました。"
        case .tokenExchangeFailed:
            return "アクセストークンの取得に失敗しました。"
        case .encodingFailed:
            return "コンテンツのエンコードに失敗しました。"
        case .unprocessableEntity:
            return "リクエストの内容が無効です。"
        case .httpError(let code):
            return "HTTPエラー: \(code)"
        }
    }
}
