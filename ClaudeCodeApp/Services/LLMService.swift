import Foundation

// MARK: - LLM Service (統合インターフェース)
/// Claude API / Ollama / カスタムサーバーを統一的に扱うサービス
/// PrivacyConfigの設定に基づいて適切なバックエンドを使用します
actor LLMService {
    private let privacyConfig: PrivacyConfig
    private let keychainService: KeychainService
    private var urlSession: URLSession

    init(privacyConfig: PrivacyConfig = .shared) {
        self.privacyConfig = privacyConfig
        self.keychainService = KeychainService()
        self.urlSession = URLSession.makeSession(
            skipSSLVerification: privacyConfig.skipSSLVerification,
            proxyHost: privacyConfig.proxyHost.isEmpty ? nil : privacyConfig.proxyHost,
            proxyPort: privacyConfig.proxyPort > 0 ? privacyConfig.proxyPort : nil
        )
    }

    func refreshSession() {
        self.urlSession = URLSession.makeSession(
            skipSSLVerification: privacyConfig.skipSSLVerification,
            proxyHost: privacyConfig.proxyHost.isEmpty ? nil : privacyConfig.proxyHost,
            proxyPort: privacyConfig.proxyPort > 0 ? privacyConfig.proxyPort : nil
        )
    }

    // MARK: - Main Chat Interface
    /// ストリーミングでメッセージを送信（バックエンドを自動選択）
    func sendMessageStream(
        messages: [ChatMessage],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error> {
        switch privacyConfig.llmBackend {
        case .claudeAPI:
            return sendClaudeStream(messages: messages, systemPrompt: systemPrompt)
        case .ollama:
            return sendOllamaStream(messages: messages, systemPrompt: systemPrompt)
        case .customOpenAICompatible:
            return sendOpenAICompatibleStream(messages: messages, systemPrompt: systemPrompt)
        }
    }

    // MARK: - Claude API
    private func sendClaudeStream(
        messages: [ChatMessage],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let apiKey = self.keychainService.load(key: KeychainKeys.claudeAPIKey) ?? ""
                    guard !apiKey.isEmpty else {
                        throw LLMError.missingCredentials("Claude APIキーが設定されていません")
                    }

                    let baseURL = self.privacyConfig.effectiveLLMBaseURL
                    guard let url = URL(string: "\(baseURL)/messages") else {
                        throw LLMError.invalidEndpoint(baseURL)
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

                    let body = ClaudeAPIRequest(
                        model: "claude-opus-4-5",
                        maxTokens: 8192,
                        system: systemPrompt,
                        messages: messages.map { APIMessagePayload(role: $0.role.rawValue, content: $0.content) },
                        stream: true
                    )
                    let encoder = JSONEncoder()
                    encoder.keyEncodingStrategy = .convertToSnakeCase
                    request.httpBody = try encoder.encode(body)

                    let (bytes, response) = try await self.urlSession.bytes(for: request)
                    try self.validateHTTPResponse(response)

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))
                        guard jsonStr != "[DONE]" else { break }

                        if let data = jsonStr.data(using: .utf8),
                           let event = try? JSONDecoder().decode(ClaudeStreamEvent.self, from: data),
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

    // MARK: - Ollama (完全ローカル)
    private func sendOllamaStream(
        messages: [ChatMessage],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let baseURL = self.privacyConfig.effectiveLLMBaseURL
                    guard let url = URL(string: "\(baseURL)/api/chat") else {
                        throw LLMError.invalidEndpoint(baseURL)
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    // システムプロンプトをmessagesに追加
                    var ollamaMessages: [[String: String]] = [
                        ["role": "system", "content": systemPrompt]
                    ]
                    ollamaMessages += messages.map { ["role": $0.role.rawValue, "content": $0.content] }

                    let body: [String: Any] = [
                        "model": self.privacyConfig.ollamaModel,
                        "messages": ollamaMessages,
                        "stream": true
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await self.urlSession.bytes(for: request)
                    try self.validateHTTPResponse(response)

                    for try await line in bytes.lines {
                        guard !line.isEmpty,
                              let data = line.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let message = json["message"] as? [String: Any],
                              let content = message["content"] as? String else {
                            continue
                        }
                        continuation.yield(content)

                        if let done = json["done"] as? Bool, done {
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - OpenAI互換API（自社サーバー等）
    private func sendOpenAICompatibleStream(
        messages: [ChatMessage],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let apiKey = self.keychainService.load(key: KeychainKeys.customLLMAPIKey) ?? ""
                    let baseURL = self.privacyConfig.effectiveLLMBaseURL
                    guard let url = URL(string: "\(baseURL)/chat/completions") else {
                        throw LLMError.invalidEndpoint(baseURL)
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    if !apiKey.isEmpty {
                        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    }

                    var openAIMessages: [[String: String]] = [
                        ["role": "system", "content": systemPrompt]
                    ]
                    openAIMessages += messages.map { ["role": $0.role.rawValue, "content": $0.content] }

                    let body: [String: Any] = [
                        "model": self.privacyConfig.ollamaModel,
                        "messages": openAIMessages,
                        "stream": true
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await self.urlSession.bytes(for: request)
                    try self.validateHTTPResponse(response)

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))
                        guard jsonStr != "[DONE]" else { break }

                        if let data = jsonStr.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let delta = choices.first?["delta"] as? [String: Any],
                           let content = delta["content"] as? String {
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Helpers
    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw LLMError.missingCredentials("認証に失敗しました。APIキーを確認してください。")
            }
            throw LLMError.httpError(httpResponse.statusCode)
        }
    }
}

// MARK: - Request Models (Claude API)
private struct ClaudeAPIRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [APIMessagePayload]
    let stream: Bool
}

private struct APIMessagePayload: Encodable {
    let role: String
    let content: String
}

private struct ClaudeStreamEvent: Decodable {
    let type: String
    let delta: ClaudeDelta?

    struct ClaudeDelta: Decodable {
        let type: String?
        let text: String?
    }
}

// MARK: - LLM Errors
enum LLMError: LocalizedError {
    case missingCredentials(String)
    case invalidEndpoint(String)
    case invalidResponse
    case httpError(Int)
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials(let msg): return msg
        case .invalidEndpoint(let url): return "無効なエンドポイント: \(url)"
        case .invalidResponse: return "無効なレスポンスを受信しました"
        case .httpError(let code): return "HTTPエラー: \(code)"
        case .connectionFailed(let msg): return "接続エラー: \(msg)"
        }
    }
}

// MARK: - URLSession Extension (プロキシ/SSL設定)
extension URLSession {
    static func makeSession(
        skipSSLVerification: Bool,
        proxyHost: String?,
        proxyPort: Int?
    ) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120

        // プロキシ設定
        if let host = proxyHost, let port = proxyPort {
            config.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable as String: true,
                kCFNetworkProxiesHTTPProxy as String: host,
                kCFNetworkProxiesHTTPPort as String: port,
                kCFNetworkProxiesHTTPSEnable as String: true,
                kCFNetworkProxiesHTTPSProxy as String: host,
                kCFNetworkProxiesHTTPSPort as String: port
            ]
        }

        if skipSSLVerification {
            // 自己署名証明書対応（プライベートサーバー向け）
            return URLSession(
                configuration: config,
                delegate: InsecureSSLDelegate(),
                delegateQueue: nil
            )
        }

        return URLSession(configuration: config)
    }
}

// MARK: - SSL Verification Bypass (プライベートサーバー用)
private class InsecureSSLDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // 注意: これはプライベートネットワーク内の自己署名証明書向けです
        // 公共ネットワークでは使用しないでください
        let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        completionHandler(.useCredential, credential)
    }
}

// MARK: - Extended Keychain Keys
extension KeychainKeys {
    static let customLLMAPIKey = "custom_llm_api_key"
}
