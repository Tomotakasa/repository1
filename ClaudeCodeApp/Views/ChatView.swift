import SwiftUI
import Speech
import AVFoundation

// MARK: - Chat View (メインチャット画面)
struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var memoryService = MemoryService.shared
    @StateObject private var docService   = DocumentService.shared
    @StateObject private var profileManager = ProfileManager.shared

    @State private var inputText = ""
    @State private var isRecording = false
    @State private var showTools = false
    @State private var showHistory = false
    @FocusState private var isInputFocused: Bool

    var currentProfile: FamilyProfile? { profileManager.currentProfile }

    var body: some View {
        VStack(spacing: 0) {
            // プロフィールバー
            profileBar

            // メッセージリスト
            messageList

            // 入力エリア
            inputArea
        }
        .navigationTitle("AIおしゃべり帳")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                historyButton
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    memoryIndicator
                    newChatButton
                }
            }
        }
        .sheet(isPresented: $showHistory) { conversationHistorySheet }
        .sheet(isPresented: $showTools)   { AIToolsView().environmentObject(appState) }
        .task { viewModel.setup(profileManager: profileManager, memoryService: memoryService, docService: docService) }
    }

    // MARK: - Profile Bar
    private var profileBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(profileManager.profiles) { profile in
                    Button {
                        profileManager.switchProfile(to: profile)
                        viewModel.startNewConversation()
                    } label: {
                        HStack(spacing: 6) {
                            Text(profile.iconEmoji)
                                .font(.title3)
                            if profileManager.currentProfileID == profile.id {
                                Text(profile.name)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, profileManager.currentProfileID == profile.id ? 12 : 8)
                        .padding(.vertical, 6)
                        .background(
                            profileManager.currentProfileID == profile.id
                                ? profile.color
                                : Color(.systemGray5)
                        )
                        .cornerRadius(20)
                    }
                }

                // プロフィール追加ボタン
                NavigationLink {
                    AddProfileView()
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }

    // MARK: - Message List
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // アクティブな記憶・ドキュメント表示
                    if !viewModel.activeContextSummary.isEmpty {
                        contextBanner
                    }

                    if viewModel.currentSession.messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(viewModel.currentSession.messages) { msg in
                            MessageRow(
                                message: msg,
                                profile: currentProfile,
                                role: currentProfile?.role ?? .adult
                            )
                            .id(msg.id)
                        }
                    }

                    if viewModel.isStreaming {
                        HStack { TypingIndicator(); Spacer() }
                            .padding(.horizontal)
                            .id("typing")
                    }
                }
                .padding(.bottom, 8)
            }
            .onChange(of: viewModel.currentSession.messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isStreaming) { streaming in
                if streaming { scrollToBottom(proxy: proxy) }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if viewModel.isStreaming {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = viewModel.currentSession.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Context Banner
    private var contextBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain")
                .font(.caption)
                .foregroundColor(.purple)
            Text(viewModel.activeContextSummary)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color.purple.opacity(0.06))
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        let role = currentProfile?.role ?? .adult
        return VStack(spacing: 24) {
            Spacer().frame(height: 40)

            if let profile = currentProfile {
                Text(profile.iconEmoji)
                    .font(.system(size: 60))
                Text("\(profile.name)さん、\nこんにちは！")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
            } else {
                Text("🤖")
                    .font(.system(size: 60))
                Text("何でも聞いてください！")
                    .font(.title2.bold())
            }

            // クイック質問ボタン
            VStack(spacing: 10) {
                ForEach(QuickPrompt.forRole(role).prefix(4), id: \.text) { prompt in
                    Button {
                        inputText = prompt.text
                        sendMessage()
                    } label: {
                        HStack(spacing: 12) {
                            Text(prompt.emoji)
                                .font(.title3)
                                .frame(width: 36)
                            Text(prompt.text)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(14)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Input Area
    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                // ツールボタン
                Button { showTools = true } label: {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundColor(.purple)
                        .frame(width: 36, height: 36)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(Circle())
                }

                // テキスト入力
                TextField(
                    currentProfile?.role == .child ? "なんでも聞いてね😊" : "メッセージを入力...",
                    text: $inputText,
                    axis: .vertical
                )
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(.systemGray6))
                .cornerRadius(22)
                .focused($isInputFocused)
                .font(currentProfile?.role == .elderly ? .body : .callout)

                // 音声入力ボタン
                VoiceInputButton(isRecording: $isRecording) { recognized in
                    inputText = recognized
                }

                // 送信
                Button {
                    viewModel.isStreaming ? viewModel.stopStreaming() : sendMessage()
                } label: {
                    Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(inputText.isEmpty && !viewModel.isStreaming ? .secondary : .accentColor)
                }
                .disabled(inputText.isEmpty && !viewModel.isStreaming)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Toolbar Items
    private var historyButton: some View {
        Button { showHistory = true } label: {
            Image(systemName: "clock.arrow.circlepath")
        }
    }

    private var newChatButton: some View {
        Button { viewModel.startNewConversation() } label: {
            Image(systemName: "square.and.pencil")
        }
    }

    private var memoryIndicator: some View {
        let count = memoryService.memories.filter { $0.isEnabled && ($0.profileID == currentProfile?.id || $0.profileID == nil) }.count
        return Group {
            if count > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "brain")
                        .font(.caption)
                    Text("\(count)")
                        .font(.caption2.bold())
                }
                .foregroundColor(.purple)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - History Sheet
    private var conversationHistorySheet: some View {
        NavigationStack {
            List {
                if viewModel.savedSessions.isEmpty {
                    Text("まだ会話の記録がありません")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.savedSessions) { session in
                        Button {
                            viewModel.loadSession(session)
                            showHistory = false
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text(session.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { viewModel.savedSessions[$0] }.forEach {
                            try? ConversationStorageManager.shared.delete($0)
                        }
                        viewModel.savedSessions.remove(atOffsets: offsets)
                    }
                }
            }
            .navigationTitle("会話の履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { showHistory = false }
                }
            }
        }
    }

    // MARK: - Action
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        isInputFocused = false
        Task { await viewModel.sendMessage(text: text) }
    }
}

// MARK: - Message Row
struct MessageRow: View {
    let message: ChatMessage
    let profile: FamilyProfile?
    let role: FamilyRole

    @State private var copied = false

    var isUser: Bool { message.role == .user }
    var fontSize: Font { role == .elderly ? .body : .callout }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isUser { aiAvatar }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
                // バブル
                Text(message.content)
                    .font(fontSize)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isUser
                        ? (profile?.color ?? Color.accentColor)
                        : Color(.systemGray5))
                    .foregroundColor(isUser ? .white : .primary)
                    .cornerRadius(18)
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                            copied = true
                        } label: { Label("コピー", systemImage: "doc.on.doc") }
                    }

                // 時刻
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(isUser ? .trailing : .leading, 4)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.72,
                   alignment: isUser ? .trailing : .leading)

            if isUser { userAvatar }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var aiAvatar: some View {
        ZStack {
            Circle().fill(Color.purple.opacity(0.12)).frame(width: 32, height: 32)
            Text("🤖").font(.caption)
        }
    }

    private var userAvatar: some View {
        ZStack {
            Circle()
                .fill(profile?.color.opacity(0.2) ?? Color.blue.opacity(0.2))
                .frame(width: 32, height: 32)
            Text(profile?.iconEmoji ?? "😊").font(.caption)
        }
    }
}

// MARK: - Voice Input Button
struct VoiceInputButton: View {
    @Binding var isRecording: Bool
    let onResult: (String) -> Void

    @State private var recognizer = SpeechRecognizer()

    var body: some View {
        Button {
            if isRecording {
                recognizer.stop { text in
                    if let text, !text.isEmpty { onResult(text) }
                    isRecording = false
                }
            } else {
                isRecording = true
                recognizer.start()
            }
        } label: {
            Image(systemName: isRecording ? "waveform.circle.fill" : "mic.circle")
                .font(.system(size: 28))
                .foregroundColor(isRecording ? .red : .secondary)
                .symbolEffect(.pulse, isActive: isRecording)
        }
    }
}

// MARK: - Speech Recognizer
class SpeechRecognizer {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    func start() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { return }
        request.shouldReportPartialResults = true

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        try? engine.start()
    }

    func stop(completion: @escaping (String?) -> Void) {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()

        guard let recognizer, recognizer.isAvailable,
              let request else { completion(nil); return }

        task = recognizer.recognitionTask(with: request) { result, error in
            if let result, result.isFinal {
                completion(result.bestTranscription.formattedString)
            } else if error != nil {
                completion(nil)
            }
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle().frame(width: 7, height: 7)
                    .foregroundColor(.secondary)
                    .opacity(phase == i ? 1 : 0.3)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color(.systemGray5)).cornerRadius(18)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Quick Prompts
struct QuickPrompt {
    let emoji: String
    let text: String

    static func forRole(_ role: FamilyRole) -> [QuickPrompt] {
        switch role {
        case .child:
            return [
                QuickPrompt(emoji: "🦁", text: "ライオンについて教えて！"),
                QuickPrompt(emoji: "🧮", text: "算数の問題を出して！"),
                QuickPrompt(emoji: "📖", text: "おもしろいお話を作って！"),
                QuickPrompt(emoji: "🎨", text: "絵のかき方を教えて！"),
            ]
        case .elderly:
            return [
                QuickPrompt(emoji: "🌸", text: "今日のおすすめの過ごし方は？"),
                QuickPrompt(emoji: "🍳", text: "簡単においしく作れる料理を教えて"),
                QuickPrompt(emoji: "💊", text: "健康によい食べ物を教えてください"),
                QuickPrompt(emoji: "📱", text: "スマホの使い方で困っています"),
            ]
        case .adult:
            return [
                QuickPrompt(emoji: "🍽️", text: "今夜の夕食、何か提案して"),
                QuickPrompt(emoji: "✈️", text: "週末のおすすめおでかけ先は？"),
                QuickPrompt(emoji: "💡", text: "アイデアを一緒に考えて"),
                QuickPrompt(emoji: "📝", text: "メールや文章を作るのを手伝って"),
            ]
        }
    }
}

// MARK: - Add Profile View (簡易)
struct AddProfileView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var pm = ProfileManager.shared

    @State private var name = ""
    @State private var emoji = "😊"
    @State private var role: FamilyRole = .adult
    @State private var color = "#4A90D9"

    let colors = ["#4A90D9","#E74C3C","#2ECC71","#F39C12","#9B59B6","#1ABC9C","#E67E22","#34495E"]

    var body: some View {
        Form {
            Section("名前") {
                TextField("例：お母さん", text: $name)
            }
            Section("誰ですか？") {
                Picker("種別", selection: $role) {
                    ForEach(FamilyRole.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: role) { r in emoji = r.defaultEmojis.first ?? "😊" }
            }
            Section("アイコン") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                    ForEach(role.defaultEmojis, id: \.self) { e in
                        Button { emoji = e } label: {
                            Text(e).font(.title2)
                                .frame(width: 40, height: 40)
                                .background(emoji == e ? Color.accentColor.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            Section("カラー") {
                HStack(spacing: 14) {
                    ForEach(colors, id: \.self) { hex in
                        Button { color = hex } label: {
                            ZStack {
                                Circle().fill(Color(hex: hex) ?? .blue).frame(width: 32, height: 32)
                                if color == hex { Image(systemName: "checkmark").font(.caption.bold()).foregroundColor(.white) }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("プロフィールを追加")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("追加") {
                    pm.addProfile(FamilyProfile(
                        name: name.isEmpty ? "新しいプロフィール" : name,
                        iconEmoji: emoji, colorHex: color, role: role))
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Chat ViewModel
@MainActor
class ChatViewModel: ObservableObject {
    @Published var currentSession = ConversationSession()
    @Published var savedSessions: [ConversationSession] = []
    @Published var isStreaming = false
    @Published var activeContextSummary = ""

    private var profileManager: ProfileManager?
    private var memoryService: MemoryService?
    private var docService: DocumentService?
    private var streamingTask: Task<Void, Never>?
    private let storage = ConversationStorageManager.shared

    func setup(profileManager: ProfileManager, memoryService: MemoryService, docService: DocumentService) {
        self.profileManager = profileManager
        self.memoryService  = memoryService
        self.docService     = docService
        loadSavedSessions()
        updateContextSummary()
    }

    func sendMessage(text: String) async {
        guard !text.isEmpty else { return }

        let profile = profileManager?.currentProfile
        let profileID = profile?.id

        // ユーザーメッセージ追加
        let userMsg = ChatMessage(role: .user, content: text)
        currentSession.addMessage(userMsg)
        currentSession.updateTitle()

        // 応答用プレースホルダ
        var assistantMsg = ChatMessage(role: .assistant, content: "", isStreaming: true)
        currentSession.addMessage(assistantMsg)
        isStreaming = true

        streamingTask = Task {
            do {
                let systemPrompt = buildSystemPrompt(text: text, profile: profile, profileID: profileID)
                let llm = LLMService(privacyConfig: .shared)
                var full = ""

                let contextMessages = currentSession.messages
                    .dropLast()          // プレースホルダを除く
                    .suffix(20)          // 直近20件に制限（容量節約）
                    .map { $0 }

                for try await chunk in await llm.sendMessageStream(
                    messages: contextMessages,
                    systemPrompt: systemPrompt
                ) {
                    guard !Task.isCancelled else { break }
                    full += chunk
                    if let idx = currentSession.messages.lastIndex(where: { $0.id == assistantMsg.id }) {
                        currentSession.messages[idx].content = full
                    }
                }

                // 完了処理
                if let idx = currentSession.messages.lastIndex(where: { $0.id == assistantMsg.id }) {
                    currentSession.messages[idx].isStreaming = false
                }
                assistantMsg.content = full

                // 自動記憶抽出（バックグラウンド）
                Task.detached(priority: .background) { [weak self] in
                    guard let self else { return }
                    if let memories = try? await self.memoryService?.extractMemoriesFromConversation(
                        self.currentSession.messages, profileID: profileID
                    ) {
                        await MainActor.run {
                            memories.forEach { self.memoryService?.addMemory($0) }
                            self.updateContextSummary()
                        }
                    }
                }

                if PrivacyConfig.shared.persistConversationHistory {
                    try? storage.save(currentSession)
                    loadSavedSessions()
                }
            } catch {
                if let idx = currentSession.messages.lastIndex(where: { $0.id == assistantMsg.id }) {
                    currentSession.messages[idx].content = "エラーが発生しました 😢\n\(error.localizedDescription)"
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
        updateContextSummary()
    }

    func loadSession(_ session: ConversationSession) {
        currentSession = session
    }

    // MARK: - Private
    private func buildSystemPrompt(text: String, profile: FamilyProfile?, profileID: UUID?) -> String {
        var parts: [String] = []

        // ベースプロンプト
        if let profile {
            parts.append("""
            あなたは「AIおしゃべり帳」です。\(profile.name)さんのお手伝いをします。
            親しみやすく、\(profile.role == .child ? "やさしい言葉" : "丁寧な言葉")で答えてください。
            """)
        } else {
            parts.append("あなたは「AIおしゃべり帳」です。親しみやすく丁寧に答えてください。")
        }

        // ロール別調整
        if let suffix = profile?.role.systemPromptSuffix, !suffix.isEmpty {
            parts.append(suffix)
        }

        // 記憶コンテキスト
        if let memCtx = memoryService?.buildMemoryContext(for: profileID), !memCtx.isEmpty {
            parts.append(memCtx)
        }

        // ドキュメントコンテキスト
        if let docCtx = docService?.buildContext(for: text, profileID: profileID), !docCtx.isEmpty {
            parts.append(docCtx)
        }

        return parts.joined(separator: "\n\n")
    }

    private func updateContextSummary() {
        let profileID = profileManager?.currentProfileID
        let memCount = memoryService?.memories.filter {
            $0.isEnabled && ($0.profileID == profileID || $0.profileID == nil)
        }.count ?? 0
        let docCount = docService?.documents.filter {
            $0.isEnabled && ($0.profileID == profileID || $0.profileID == nil)
        }.count ?? 0

        var parts: [String] = []
        if memCount > 0 { parts.append("記憶 \(memCount)件") }
        if docCount > 0 { parts.append("資料 \(docCount)件") }
        activeContextSummary = parts.isEmpty ? "" : parts.joined(separator: "・") + " を参照中"
    }

    private func loadSavedSessions() {
        savedSessions = (try? storage.loadAll()) ?? []
    }
}

// MARK: - AppState Extension
extension AppState {
    var llmService: LLMService { LLMService(privacyConfig: PrivacyConfig.shared) }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
        hasCompletedOnboarding = true
    }
}
