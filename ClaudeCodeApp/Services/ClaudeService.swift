import Foundation

// MARK: - Claude Service
/// Anthropic Claude APIとの通信を担当するサービス
actor ClaudeService {
    private var apiKey: String
    private let baseURL = "https://api.anthropic.com/v1"
    private let model = "claude-opus-4-5"
    private let urlSession: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        self.urlSession = URLSession(configuration: config)
    }

    func updateAPIKey(_ key: String) {
        self.apiKey = key
    }

    // MARK: - Chat Completion (Streaming)
    /// ストリーミングでClaudeにメッセージを送信し、レスポンスを非同期ストリームで返す
    func sendMessageStream(
        messages: [ChatMessage],
        systemPrompt: String = ClaudePrompts.defaultSystem
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try self.buildRequest(
                        endpoint: "/messages",
                        body: ClaudeRequest(
                            model: self.model,
                            maxTokens: 8192,
                            system: systemPrompt,
                            messages: messages.map { APIMessage(role: $0.role.rawValue, content: $0.content) },
                            stream: true
                        )
                    )

                    let (bytes, response) = try await self.urlSession.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw ClaudeError.invalidResponse
                    }
                    guard httpResponse.statusCode == 200 else {
                        throw ClaudeError.httpError(httpResponse.statusCode)
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6))
                        guard jsonString != "[DONE]" else { break }

                        if let data = jsonString.data(using: .utf8),
                           let event = try? JSONDecoder().decode(StreamEvent.self, from: data),
                           let text = event.delta?.text {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Code Generation
    /// コードを生成するメソッド
    func generateCode(
        description: String,
        language: String,
        context: String? = nil
    ) async throws -> String {
        let contextPart = context.map { "\n\n参考コンテキスト:\n```\n\($0)\n```" } ?? ""
        let prompt = """
        以下の説明に基づいて\(language)のコードを生成してください。

        説明: \(description)\(contextPart)

        コードのみを返してください（説明不要）。
        """

        let messages = [ChatMessage(role: .user, content: prompt)]
        var result = ""

        for try await chunk in sendMessageStream(messages: messages, systemPrompt: ClaudePrompts.codeGeneration) {
            result += chunk
        }

        return extractCode(from: result)
    }

    // MARK: - Code Explanation
    /// コードを説明するメソッド
    func explainCode(_ code: String, language: String) async throws -> String {
        let prompt = """
        以下の\(language)コードを詳しく説明してください：

        ```\(language)
        \(code)
        ```
        """

        let messages = [ChatMessage(role: .user, content: prompt)]
        var result = ""

        for try await chunk in sendMessageStream(messages: messages, systemPrompt: ClaudePrompts.codeExplanation) {
            result += chunk
        }

        return result
    }

    // MARK: - Code Review
    /// コードレビューを行うメソッド
    func reviewCode(_ code: String, language: String) async throws -> String {
        let prompt = """
        以下の\(language)コードをレビューしてください。問題点、改善案、ベストプラクティスについて指摘してください：

        ```\(language)
        \(code)
        ```
        """

        let messages = [ChatMessage(role: .user, content: prompt)]
        var result = ""

        for try await chunk in sendMessageStream(messages: messages, systemPrompt: ClaudePrompts.codeReview) {
            result += chunk
        }

        return result
    }

    // MARK: - Bug Fix
    /// バグ修正の提案
    func suggestBugFix(code: String, errorDescription: String, language: String) async throws -> String {
        let prompt = """
        以下のコードにバグがあります。修正してください。

        言語: \(language)
        エラー内容: \(errorDescription)

        コード:
        ```\(language)
        \(code)
        ```

        修正済みコードと説明を提供してください。
        """

        let messages = [ChatMessage(role: .user, content: prompt)]
        var result = ""

        for try await chunk in sendMessageStream(messages: messages, systemPrompt: ClaudePrompts.bugFix) {
            result += chunk
        }

        return result
    }

    // MARK: - Private Helpers
    private func buildRequest<T: Encodable>(endpoint: String, body: T) throws -> URLRequest {
        guard !apiKey.isEmpty else {
            throw ClaudeError.missingAPIKey
        }

        guard let url = URL(string: baseURL + endpoint) else {
            throw ClaudeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        return request
    }

    private func extractCode(from text: String) -> String {
        // コードブロックを抽出
        let pattern = "```(?:\\w+)?\\n([\\s\\S]+?)\\n```"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return text
    }
}

// MARK: - Request/Response Models
private struct ClaudeRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [APIMessage]
    let stream: Bool
}

private struct APIMessage: Encodable {
    let role: String
    let content: String
}

private struct StreamEvent: Decodable {
    let type: String
    let delta: DeltaContent?

    struct DeltaContent: Decodable {
        let type: String?
        let text: String?
    }
}

// MARK: - System Prompts
enum ClaudePrompts {
    static let defaultSystem = """
    あなたはClaude Code - iPhoneアプリ版です。
    ソフトウェア開発の専門家として、コードの作成、説明、レビュー、デバッグを支援します。
    日本語と英語の両方に対応しています。
    コードブロックには適切な言語タグを使用してください。
    """

    static let codeGeneration = """
    あなたはエキスパートプログラマーです。
    ユーザーの要求に基づいて、クリーンで効率的なコードを生成します。
    コードのみを返し、余分な説明は最小限にしてください。
    """

    static let codeExplanation = """
    あなたはコードの教師です。
    コードを段階的に、わかりやすく説明します。
    初心者にもわかるように、専門用語には説明を加えてください。
    """

    static let codeReview = """
    あなたはシニアエンジニアです。
    コードのセキュリティ、パフォーマンス、可読性、ベストプラクティスの観点からレビューします。
    具体的な改善案を提案してください。
    """

    static let bugFix = """
    あなたはデバッグの専門家です。
    コードのバグを特定し、修正案を提供します。
    なぜそのバグが発生したかも説明してください。
    """
}

// MARK: - Errors
enum ClaudeError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Claude APIキーが設定されていません。設定画面から入力してください。"
        case .invalidURL:
            return "無効なURLです。"
        case .invalidResponse:
            return "無効なレスポンスを受信しました。"
        case .httpError(let code):
            return "HTTPエラー: \(code)"
        case .decodingError:
            return "レスポンスの解析に失敗しました。"
        }
    }
}
