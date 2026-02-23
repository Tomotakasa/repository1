import Foundation
import CryptoKit

// MARK: - Chat Message
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var role: MessageRole
    var content: String
    let timestamp: Date
    var isStreaming: Bool
    var attachedCode: CodeAttachment?

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        attachedCode: CodeAttachment? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.attachedCode = attachedCode
    }
}

// MARK: - Message Role
enum MessageRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
}

// MARK: - Code Attachment
struct CodeAttachment: Identifiable, Codable, Equatable {
    let id: UUID
    var filename: String
    var language: String
    var content: String

    init(id: UUID = UUID(), filename: String, language: String, content: String) {
        self.id = id
        self.filename = filename
        self.language = language
        self.content = content
    }
}

// MARK: - Conversation Session
struct ConversationSession: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date
    var isEncrypted: Bool

    init(
        id: UUID = UUID(),
        title: String = "新しい会話",
        messages: [ChatMessage] = [],
        createdAt: Date = Date(),
        isEncrypted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isEncrypted = isEncrypted
    }

    mutating func addMessage(_ message: ChatMessage) {
        messages.append(message)
        updatedAt = Date()
    }

    mutating func updateTitle() {
        if let firstUserMessage = messages.first(where: { $0.role == .user }) {
            let content = firstUserMessage.content
            title = String(content.prefix(50)) + (content.count > 50 ? "..." : "")
        }
    }
}

// MARK: - Local Storage Manager (暗号化対応)
/// 会話履歴をローカルに安全に保存するマネージャー
class ConversationStorageManager {
    static let shared = ConversationStorageManager()
    private let privacyConfig = PrivacyConfig.shared

    private var storageDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("conversations", isDirectory: true)
    }

    private init() {
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Save
    func save(_ session: ConversationSession) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var data = try encoder.encode(session)

        if privacyConfig.enableLocalEncryption {
            data = try encrypt(data)
        }

        let fileURL = storageDirectory.appendingPathComponent("\(session.id).json")
        try data.write(to: fileURL, options: .completeFileProtection)
    }

    // MARK: - Load All
    func loadAll() throws -> [ConversationSession] {
        let files = try FileManager.default.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        )
        .filter { $0.pathExtension == "json" }

        return try files.compactMap { url in
            var data = try Data(contentsOf: url)
            if privacyConfig.enableLocalEncryption {
                data = try decrypt(data)
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(ConversationSession.self, from: data)
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Delete
    func delete(_ session: ConversationSession) throws {
        let fileURL = storageDirectory.appendingPathComponent("\(session.id).json")
        try FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Delete All (セキュアワイプ)
    func deleteAll() throws {
        let files = try FileManager.default.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: nil
        )
        for file in files {
            // ゼロ埋めしてから削除（セキュア削除）
            try secureDelete(url: file)
        }
    }

    // MARK: - Encryption (AES-GCM)
    private func getEncryptionKey() throws -> SymmetricKey {
        let keychainService = KeychainService()
        if let keyData = keychainService.load(key: "conversation_encryption_key"),
           let data = Data(base64Encoded: keyData) {
            return SymmetricKey(data: data)
        }
        // 新しいキーを生成
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0).base64EncodedString() }
        keychainService.save(key: "conversation_encryption_key", value: keyData)
        return key
    }

    private func encrypt(_ data: Data) throws -> Data {
        let key = try getEncryptionKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw StorageError.encryptionFailed
        }
        return combined
    }

    private func decrypt(_ data: Data) throws -> Data {
        let key = try getEncryptionKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    private func secureDelete(url: URL) throws {
        if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
           fileSize > 0 {
            // ゼロ埋めで上書き
            let zeros = Data(count: fileSize)
            try zeros.write(to: url)
        }
        try FileManager.default.removeItem(at: url)
    }
}

enum StorageError: LocalizedError {
    case encryptionFailed
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed: return "データの暗号化に失敗しました"
        case .decryptionFailed: return "データの復号に失敗しました"
        }
    }
}
