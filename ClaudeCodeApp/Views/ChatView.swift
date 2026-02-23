import SwiftUI

// MARK: - Chat View (メインチャット画面)
struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @State private var showCodeActions = false
    @State private var selectedMode: ChatMode = .chat
    @State private var showAttachCode = false
    @State private var attachedCode: CodeAttachment? = nil
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // モード選択バー
            chatModeSelector

            // メッセージリスト
            messageList

            // 入力エリア
            inputArea
        }
        .navigationTitle("Claude Code")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                conversationHistoryButton
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                newConversationButton
            }
        }
        .sheet(isPresented: $showAttachCode) {
            CodeAttachmentView(attachment: $attachedCode)
        }
        .task {
            viewModel.setup(llmService: appState.llmService)
        }
    }

    // MARK: - Mode Selector
    private var chatModeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ChatMode.allCases, id: \.self) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: mode.icon)
                            Text(mode.displayName)
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedMode == mode ? Color.accentColor : Color(.systemGray5))
                        .foregroundColor(selectedMode == mode ? .white : .primary)
                        .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .shadow(radius: 1)
    }

    // MARK: - Message List
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.currentSession.messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(viewModel.currentSession.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }

                    if viewModel.isStreaming {
                        HStack {
                            TypingIndicator()
                            Spacer()
                        }
                        .padding(.horizontal)
                        .id("streaming_indicator")
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.currentSession.messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isStreaming) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            if viewModel.isStreaming {
                proxy.scrollTo("streaming_indicator", anchor: .bottom)
            } else if let lastId = viewModel.currentSession.messages.last?.id {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("Claude Code")
                .font(.title2.bold())

            Text("コードの作成・説明・レビュー・デバッグを\nAIがサポートします")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.callout)

            // クイックアクションボタン
            VStack(spacing: 10) {
                ForEach(QuickAction.allCases, id: \.self) { action in
                    Button {
                        inputText = action.prompt
                        isInputFocused = true
                    } label: {
                        HStack {
                            Image(systemName: action.icon)
                                .frame(width: 24)
                            Text(action.displayName)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 40)
    }

    // MARK: - Input Area
    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()

            // コードアタッチメント表示
            if let code = attachedCode {
                CodeAttachmentBadge(attachment: code) {
                    attachedCode = nil
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            HStack(alignment: .bottom, spacing: 8) {
                // コード添付ボタン
                Button {
                    showAttachCode = true
                } label: {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }

                // テキスト入力
                TextField(selectedMode.placeholder, text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .focused($isInputFocused)

                // 送信ボタン
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSend ? .accentColor : .secondary)
                }
                .disabled(!canSend && !viewModel.isStreaming)
                .onTapGesture {
                    if viewModel.isStreaming {
                        viewModel.stopStreaming()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isStreaming
    }

    // MARK: - Toolbar Buttons
    private var conversationHistoryButton: some View {
        Menu {
            ForEach(viewModel.savedSessions) { session in
                Button {
                    viewModel.loadSession(session)
                } label: {
                    Label(session.title, systemImage: "clock")
                }
            }
            if viewModel.savedSessions.isEmpty {
                Text("履歴なし")
            }
        } label: {
            Image(systemName: "clock")
        }
    }

    private var newConversationButton: some View {
        Button {
            viewModel.startNewConversation()
        } label: {
            Image(systemName: "square.and.pencil")
        }
    }

    // MARK: - Actions
    private func sendMessage() {
        guard canSend else { return }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = attachedCode
        inputText = ""
        attachedCode = nil

        Task {
            await viewModel.sendMessage(text: text, mode: selectedMode, attachedCode: code)
        }
    }
}

// MARK: - Chat Mode
enum ChatMode: String, CaseIterable {
    case chat = "chat"
    case codeGen = "code_gen"
    case explain = "explain"
    case review = "review"
    case bugFix = "bug_fix"

    var displayName: String {
        switch self {
        case .chat: return "チャット"
        case .codeGen: return "コード生成"
        case .explain: return "コード説明"
        case .review: return "コードレビュー"
        case .bugFix: return "バグ修正"
        }
    }

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .codeGen: return "chevron.left.forwardslash.chevron.right"
        case .explain: return "doc.text.magnifyingglass"
        case .review: return "checkmark.seal"
        case .bugFix: return "ant.circle"
        }
    }

    var placeholder: String {
        switch self {
        case .chat: return "メッセージを入力..."
        case .codeGen: return "作りたいコードを説明してください..."
        case .explain: return "説明したいコードを入力またはペーストしてください..."
        case .review: return "レビューしたいコードを貼り付けてください..."
        case .bugFix: return "バグのあるコードとエラー内容を教えてください..."
        }
    }

    var systemPrompt: String {
        switch self {
        case .chat: return ClaudePrompts.defaultSystem
        case .codeGen: return ClaudePrompts.codeGeneration
        case .explain: return ClaudePrompts.codeExplanation
        case .review: return ClaudePrompts.codeReview
        case .bugFix: return ClaudePrompts.bugFix
        }
    }
}

// MARK: - Quick Actions
enum QuickAction: CaseIterable {
    case generateSwiftUI
    case reviewCode
    case explainCode
    case writeTests

    var displayName: String {
        switch self {
        case .generateSwiftUI: return "SwiftUIコンポーネントを作成"
        case .reviewCode: return "コードをレビューしてもらう"
        case .explainCode: return "コードの動作を説明してもらう"
        case .writeTests: return "ユニットテストを書いてもらう"
        }
    }

    var icon: String {
        switch self {
        case .generateSwiftUI: return "swift"
        case .reviewCode: return "checkmark.seal"
        case .explainCode: return "doc.text.magnifyingglass"
        case .writeTests: return "checkmark.circle"
        }
    }

    var prompt: String {
        switch self {
        case .generateSwiftUI: return "SwiftUIで"
        case .reviewCode: return "以下のコードをレビューしてください:\n"
        case .explainCode: return "以下のコードを説明してください:\n"
        case .writeTests: return "以下のコードのユニットテストを書いてください:\n"
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage
    @State private var showCopyFeedback = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                assistantAvatar
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if let code = message.attachedCode {
                    CodeBlockView(code: code)
                }

                // メッセージバブル
                messageContent
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(message.role == .user ? Color.accentColor : Color(.systemGray5))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(16)
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                            showCopyFeedback = true
                        } label: {
                            Label("コピー", systemImage: "doc.on.doc")
                        }
                    }

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user {
                userAvatar
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var messageContent: some View {
        // コードブロックを含むメッセージのレンダリング
        MarkdownCodeView(text: message.content)
    }

    private var assistantAvatar: some View {
        Image(systemName: "cpu")
            .font(.caption)
            .padding(8)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(Circle())
            .foregroundColor(.accentColor)
    }

    private var userAvatar: some View {
        Image(systemName: "person.circle.fill")
            .font(.title3)
            .foregroundColor(.secondary)
    }
}

// MARK: - Markdown/Code View
struct MarkdownCodeView: View {
    let text: String

    var body: some View {
        // コードブロックとテキストを混在表示
        Text(text)
            .textSelection(.enabled)
    }
}

// MARK: - Code Block View
struct CodeBlockView: View {
    let code: CodeAttachment
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ヘッダー
            HStack {
                Image(systemName: "doc.text")
                    .font(.caption)
                Text(code.filename)
                    .font(.caption.monospaced())
                Spacer()
                Button {
                    UIPasteboard.general.string = code.content
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray4))

            // コード
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code.content)
                    .font(.system(.caption, design: .monospaced))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .background(Color(.systemGray6))
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundColor(.secondary)
                    .scaleEffect(animating ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
        .cornerRadius(16)
        .onAppear { animating = true }
    }
}

// MARK: - Code Attachment Views
struct CodeAttachmentBadge: View {
    let attachment: CodeAttachment
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.caption)
                .foregroundColor(.accentColor)
            Text(attachment.filename.isEmpty ? "コード添付" : attachment.filename)
                .font(.caption)
                .lineLimit(1)
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct CodeAttachmentView: View {
    @Binding var attachment: CodeAttachment?
    @Environment(\.dismiss) var dismiss

    @State private var filename = ""
    @State private var language = "swift"
    @State private var content = ""

    let languages = ["swift", "python", "javascript", "typescript", "kotlin", "go", "rust", "java", "c", "cpp", "ruby", "php", "html", "css", "json", "yaml", "bash", "sql"]

    var body: some View {
        NavigationStack {
            Form {
                Section("ファイル情報") {
                    TextField("ファイル名 (例: main.swift)", text: $filename)
                    Picker("言語", selection: $language) {
                        ForEach(languages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                }

                Section("コード") {
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("コードを添付")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添付") {
                        attachment = CodeAttachment(
                            filename: filename.isEmpty ? "code.\(language)" : filename,
                            language: language,
                            content: content
                        )
                        dismiss()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Chat View Model
@MainActor
class ChatViewModel: ObservableObject {
    @Published var currentSession = ConversationSession()
    @Published var savedSessions: [ConversationSession] = []
    @Published var isStreaming = false

    private var llmService: LLMService?
    private var streamingTask: Task<Void, Never>?
    private let storage = ConversationStorageManager.shared

    func setup(llmService: LLMService) {
        self.llmService = llmService
        loadSavedSessions()
    }

    func sendMessage(text: String, mode: ChatMode, attachedCode: CodeAttachment?) async {
        var messageContent = text
        if let code = attachedCode {
            messageContent += "\n\n```\(code.language)\n\(code.content)\n```"
        }

        let userMessage = ChatMessage(role: .user, content: messageContent, attachedCode: attachedCode)
        currentSession.addMessage(userMessage)
        currentSession.updateTitle()

        // アシスタントの応答メッセージを準備
        let assistantMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
        currentSession.addMessage(assistantMessage)

        isStreaming = true

        streamingTask = Task {
            do {
                guard let llmService = llmService else { return }
                var fullContent = ""

                let stream = await llmService.sendMessageStream(
                    messages: currentSession.messages.dropLast().map { $0 },
                    systemPrompt: mode.systemPrompt
                )

                for try await chunk in stream {
                    guard !Task.isCancelled else { break }
                    fullContent += chunk

                    if let idx = currentSession.messages.lastIndex(where: { $0.id == assistantMessage.id }) {
                        currentSession.messages[idx].content = fullContent
                    }
                }

                // ストリーミング完了
                if let idx = currentSession.messages.lastIndex(where: { $0.id == assistantMessage.id }) {
                    currentSession.messages[idx].isStreaming = false
                }

                // 保存
                if PrivacyConfig.shared.persistConversationHistory {
                    try? storage.save(currentSession)
                    loadSavedSessions()
                }
            } catch {
                if let idx = currentSession.messages.lastIndex(where: { $0.id == assistantMessage.id }) {
                    currentSession.messages[idx].content = "エラーが発生しました: \(error.localizedDescription)"
                    currentSession.messages[idx].isStreaming = false
                }
            }
            isStreaming = false
        }
    }

    func stopStreaming() {
        streamingTask?.cancel()
        isStreaming = false
        if let idx = currentSession.messages.indices.last {
            currentSession.messages[idx].isStreaming = false
        }
    }

    func startNewConversation() {
        currentSession = ConversationSession()
    }

    func loadSession(_ session: ConversationSession) {
        currentSession = session
    }

    private func loadSavedSessions() {
        savedSessions = (try? storage.loadAll()) ?? []
    }
}

// MARK: - AppState Extension
extension AppState {
    var llmService: LLMService {
        LLMService(privacyConfig: PrivacyConfig.shared)
    }
}
