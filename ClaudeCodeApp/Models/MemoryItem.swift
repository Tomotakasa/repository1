import Foundation

// MARK: - Memory Item (AIが覚えておくこと)
struct MemoryItem: Identifiable, Codable {
    let id: UUID
    var content: String          // 記憶の内容
    var category: MemoryCategory // カテゴリ
    var profileID: UUID?         // どのプロフィールの記憶か
    let createdAt: Date
    var updatedAt: Date
    var useCount: Int            // 何回参照されたか
    var isEnabled: Bool          // 有効/無効

    init(
        id: UUID = UUID(),
        content: String,
        category: MemoryCategory = .general,
        profileID: UUID? = nil,
        createdAt: Date = Date(),
        isEnabled: Bool = true
    ) {
        self.id = id
        self.content = content
        self.category = category
        self.profileID = profileID
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.useCount = 0
        self.isEnabled = isEnabled
    }
}

// MARK: - Memory Category
enum MemoryCategory: String, Codable, CaseIterable {
    case personal    = "personal"    // 個人情報（名前、家族構成など）
    case preference  = "preference"  // 好み・趣味
    case routine     = "routine"     // 日常のルーティン
    case health      = "health"      // 健康・医療情報
    case work        = "work"        // 仕事・学校
    case general     = "general"     // その他

    var displayName: String {
        switch self {
        case .personal:   return "プロフィール"
        case .preference: return "好み・趣味"
        case .routine:    return "日課・ルーティン"
        case .health:     return "健康"
        case .work:       return "仕事・学校"
        case .general:    return "その他"
        }
    }

    var emoji: String {
        switch self {
        case .personal:   return "👤"
        case .preference: return "❤️"
        case .routine:    return "📅"
        case .health:     return "💊"
        case .work:       return "💼"
        case .general:    return "💡"
        }
    }
}

// MARK: - Memory Service
/// AIとの会話から学習した記憶を管理するサービス
class MemoryService: ObservableObject {
    static let shared = MemoryService()

    @Published var memories: [MemoryItem] = []

    private let storageKey = "ai_memories_v1"
    private let maxMemories = 200  // 最大保存件数（容量節約）
    private let llmService = LLMService()

    private init() { load() }

    // MARK: - CRUD
    func addMemory(_ item: MemoryItem) {
        memories.insert(item, at: 0)
        pruneIfNeeded()
        save()
    }

    func updateMemory(_ item: MemoryItem) {
        if let idx = memories.firstIndex(where: { $0.id == item.id }) {
            memories[idx] = item
            save()
        }
    }

    func deleteMemory(id: UUID) {
        memories.removeAll { $0.id == id }
        save()
    }

    func toggleMemory(id: UUID) {
        if let idx = memories.firstIndex(where: { $0.id == id }) {
            memories[idx].isEnabled.toggle()
            save()
        }
    }

    // MARK: - Context 生成
    /// 現在のプロフィール向けの記憶をシステムプロンプト用テキストに変換
    func buildMemoryContext(for profileID: UUID?) -> String {
        let relevantMemories = memories.filter {
            $0.isEnabled && ($0.profileID == profileID || $0.profileID == nil)
        }
        guard !relevantMemories.isEmpty else { return "" }

        var lines = ["【あなたが覚えていること（ユーザーの情報）】"]
        for memory in relevantMemories.prefix(30) {  // 最大30件（トークン節約）
            lines.append("- \(memory.content)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - AI による自動記憶抽出
    /// 会話から記憶すべき情報を抽出する
    func extractMemoriesFromConversation(
        _ messages: [ChatMessage],
        profileID: UUID?
    ) async throws -> [MemoryItem] {
        // 直近5往復だけを対象にする（コスト・速度節約）
        let recentMessages = messages.suffix(10)
        guard recentMessages.contains(where: { $0.role == .user }) else { return [] }

        let conversationText = recentMessages
            .map { "\($0.role == .user ? "ユーザー" : "AI"): \($0.content)" }
            .joined(separator: "\n")

        let prompt = """
        以下の会話から、ユーザーについて「覚えておくべき重要な情報」だけを箇条書きで抽出してください。
        例：名前、好み、趣味、家族構成、仕事、健康状態など。
        一時的な話題や挨拶は除外してください。
        何もなければ「なし」と答えてください。

        会話:
        \(conversationText)

        形式: 各行を「カテゴリ:内容」の形式で。
        カテゴリは personal/preference/routine/health/work/general のいずれか。
        例:
        personal: 名前は田中花子
        preference: 猫が好き
        """

        var result = ""
        let stream = await llmService.sendMessageStream(
            messages: [ChatMessage(role: .user, content: prompt)],
            systemPrompt: "あなたは情報抽出の専門家です。指示通りに情報を抽出してください。"
        )
        for try await chunk in stream { result += chunk }

        return parseMemories(result, profileID: profileID)
    }

    // MARK: - Private Helpers
    private func parseMemories(_ text: String, profileID: UUID?) -> [MemoryItem] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("なし") else {
            return []
        }

        return text.components(separatedBy: "\n")
            .compactMap { line -> MemoryItem? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed.contains(":") else { return nil }
                let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { return nil }

                let catStr = parts[0].trimmingCharacters(in: .whitespaces)
                let content = parts[1].trimmingCharacters(in: .whitespaces)
                guard !content.isEmpty else { return nil }

                let category = MemoryCategory(rawValue: catStr) ?? .general
                return MemoryItem(content: content, category: category, profileID: profileID)
            }
    }

    private func pruneIfNeeded() {
        if memories.count > maxMemories {
            memories = Array(memories.prefix(maxMemories))
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(memories) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let loaded = try? JSONDecoder().decode([MemoryItem].self, from: data) {
            memories = loaded
        }
    }
}
