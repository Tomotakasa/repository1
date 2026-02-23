import Foundation
import PDFKit
import UIKit

// MARK: - Document Item (学習用ドキュメント)
struct DocumentItem: Identifiable, Codable {
    let id: UUID
    var filename: String
    var type: DocumentType
    var chunks: [TextChunk]      // テキストをチャンク分割して保存
    var summary: String          // AI生成サマリー（容量節約のため）
    var totalChars: Int          // 元テキストの文字数
    var isEnabled: Bool          // チャット時に参照するか
    var profileID: UUID?
    let importedAt: Date

    init(
        id: UUID = UUID(),
        filename: String,
        type: DocumentType,
        chunks: [TextChunk],
        summary: String = "",
        profileID: UUID? = nil
    ) {
        self.id = id
        self.filename = filename
        self.type = type
        self.chunks = chunks
        self.summary = summary
        self.totalChars = chunks.reduce(0) { $0 + $1.content.count }
        self.isEnabled = true
        self.profileID = profileID
        self.importedAt = Date()
    }

    /// ファイルサイズ表示用
    var sizeDescription: String {
        let kb = Double(totalChars) / 1000
        if kb < 1000 {
            return String(format: "%.0f KB相当", kb)
        } else {
            return String(format: "%.1f MB相当", kb / 1000)
        }
    }
}

// MARK: - Text Chunk (テキストの断片)
struct TextChunk: Codable {
    let id: UUID
    let content: String
    let pageNumber: Int?       // PDFのページ番号
    var keywords: [String]     // キーワード索引（検索用）

    init(content: String, pageNumber: Int? = nil) {
        self.id = UUID()
        self.content = content
        self.pageNumber = pageNumber
        self.keywords = TextChunk.extractKeywords(from: content)
    }

    /// シンプルなキーワード抽出
    static func extractKeywords(from text: String) -> [String] {
        // 3文字以上の単語を抽出（助詞・記号を除く簡易実装）
        let words = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count >= 3 }
            .prefix(20)
        return Array(words)
    }
}

// MARK: - Document Type
enum DocumentType: String, Codable {
    case pdf    = "pdf"
    case txt    = "txt"
    case md     = "md"
    case manual = "manual"  // 手動入力テキスト

    var emoji: String {
        switch self {
        case .pdf:    return "📄"
        case .txt:    return "📝"
        case .md:     return "📋"
        case .manual: return "✏️"
        }
    }

    var displayName: String {
        switch self {
        case .pdf:    return "PDF"
        case .txt:    return "テキスト"
        case .md:     return "Markdown"
        case .manual: return "手動入力"
        }
    }
}

// MARK: - Document Service
/// ドキュメントの読み込み・検索・参照を管理するサービス
class DocumentService: ObservableObject {
    static let shared = DocumentService()

    @Published var documents: [DocumentItem] = []

    private let storageKey = "ai_documents_v1"
    private let maxChunkSize = 800       // 1チャンク最大文字数
    private let maxChunksPerDoc = 50     // ドキュメント1つ最大50チャンク（容量節約）
    private let maxDocuments = 20        // 最大保存ドキュメント数

    private init() { load() }

    // MARK: - Import
    /// PDFファイルからテキストを抽出してドキュメントを作成
    func importPDF(url: URL, profileID: UUID?) throws -> DocumentItem {
        guard let pdf = PDFDocument(url: url) else {
            throw DocumentError.cannotOpenFile
        }

        var chunks: [TextChunk] = []
        var buffer = ""

        for pageIndex in 0..<min(pdf.pageCount, 100) {  // 最大100ページ
            guard let page = pdf.page(at: pageIndex) else { continue }
            let pageText = page.string ?? ""
            buffer += pageText + "\n"

            // バッファがチャンクサイズを超えたら分割
            while buffer.count >= maxChunkSize {
                let chunk = String(buffer.prefix(maxChunkSize))
                chunks.append(TextChunk(content: chunk, pageNumber: pageIndex + 1))
                buffer = String(buffer.dropFirst(maxChunkSize))

                if chunks.count >= maxChunksPerDoc { break }
            }
            if chunks.count >= maxChunksPerDoc { break }
        }
        // 残りのバッファをチャンクに
        if !buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chunks.append(TextChunk(content: buffer, pageNumber: nil))
        }

        guard !chunks.isEmpty else { throw DocumentError.emptyDocument }

        let doc = DocumentItem(
            filename: url.lastPathComponent,
            type: .pdf,
            chunks: chunks,
            profileID: profileID
        )
        addDocument(doc)
        return doc
    }

    /// プレーンテキストを直接インポート
    func importText(_ text: String, filename: String, type: DocumentType = .txt, profileID: UUID?) -> DocumentItem {
        var chunks: [TextChunk] = []
        let lines = text.components(separatedBy: "\n")
        var buffer = ""

        for line in lines {
            buffer += line + "\n"
            if buffer.count >= maxChunkSize {
                chunks.append(TextChunk(content: buffer))
                buffer = ""
                if chunks.count >= maxChunksPerDoc { break }
            }
        }
        if !buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chunks.append(TextChunk(content: buffer))
        }

        let doc = DocumentItem(
            filename: filename,
            type: type,
            chunks: chunks,
            profileID: profileID
        )
        addDocument(doc)
        return doc
    }

    // MARK: - Search & Context
    /// クエリに関連するチャンクを検索してコンテキスト文字列を返す
    func buildContext(for query: String, profileID: UUID?, maxChars: Int = 2000) -> String {
        let active = documents.filter {
            $0.isEnabled && ($0.profileID == profileID || $0.profileID == nil)
        }
        guard !active.isEmpty else { return "" }

        let queryWords = query.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count >= 2 }

        // キーワードマッチスコアで上位チャンクを選択
        var scored: [(chunk: TextChunk, docName: String, score: Int)] = []
        for doc in active {
            for chunk in doc.chunks {
                let score = queryWords.filter { word in
                    chunk.content.localizedCaseInsensitiveContains(word) ||
                    chunk.keywords.contains { $0.localizedCaseInsensitiveContains(word) }
                }.count
                if score > 0 {
                    scored.append((chunk, doc.filename, score))
                }
            }
        }

        scored.sort { $0.score > $1.score }
        var resultText = ""
        var usedChars = 0

        for item in scored.prefix(5) {
            let entry = "【\(item.docName)】\n\(item.chunk.content)\n\n"
            if usedChars + entry.count > maxChars { break }
            resultText += entry
            usedChars += entry.count
        }

        if resultText.isEmpty { return "" }
        return "【参考資料】\n\(resultText)"
    }

    // MARK: - CRUD
    func addDocument(_ doc: DocumentItem) {
        documents.insert(doc, at: 0)
        if documents.count > maxDocuments {
            documents = Array(documents.prefix(maxDocuments))
        }
        save()
    }

    func updateSummary(id: UUID, summary: String) {
        if let idx = documents.firstIndex(where: { $0.id == id }) {
            documents[idx].summary = summary
            save()
        }
    }

    func toggleDocument(id: UUID) {
        if let idx = documents.firstIndex(where: { $0.id == id }) {
            documents[idx].isEnabled.toggle()
            save()
        }
    }

    func deleteDocument(id: UUID) {
        documents.removeAll { $0.id == id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(documents) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let loaded = try? JSONDecoder().decode([DocumentItem].self, from: data) {
            documents = loaded
        }
    }
}

// MARK: - Document Errors
enum DocumentError: LocalizedError {
    case cannotOpenFile
    case emptyDocument
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .cannotOpenFile:    return "ファイルを開けませんでした"
        case .emptyDocument:     return "テキストが含まれていないファイルです"
        case .unsupportedFormat: return "対応していないファイル形式です"
        }
    }
}
