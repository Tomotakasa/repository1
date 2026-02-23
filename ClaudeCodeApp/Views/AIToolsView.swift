import SwiftUI
import Speech
import AVFoundation
import UniformTypeIdentifiers

// MARK: - AI Tools Hub
struct AIToolsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // ビジネスツール
                    ToolSection(title: "💼 ビジネス", tools: [
                        ToolCard(emoji: "🎙️", title: "ボイスメモ → 議事録",
                                 desc: "録音や音声から議事録・TODOを自動作成",
                                 destination: AnyView(VoiceMemoToolView())),
                        ToolCard(emoji: "📧", title: "メール・文書作成",
                                 desc: "ビジネスメール・報告書・提案書を下書き",
                                 destination: AnyView(DocumentWriterView())),
                        ToolCard(emoji: "📊", title: "アイデア整理",
                                 desc: "箇条書きをまとめ・整理・スライド構成に",
                                 destination: AnyView(IdeaOrganizerView())),
                        ToolCard(emoji: "📋", title: "TODOリスト作成",
                                 desc: "やることリストをAIと一緒に整理",
                                 destination: AnyView(TodoMakerView())),
                    ])

                    // 日常ツール
                    ToolSection(title: "🏡 日常・暮らし", tools: [
                        ToolCard(emoji: "🍳", title: "レシピアドバイザー",
                                 desc: "冷蔵庫の食材からレシピを提案",
                                 destination: AnyView(RecipeToolView())),
                        ToolCard(emoji: "✈️", title: "旅行プランナー",
                                 desc: "行先・日程・予算から旅程を作成",
                                 destination: AnyView(TravelPlannerView())),
                        ToolCard(emoji: "🌐", title: "翻訳・言い換え",
                                 desc: "日英翻訳、わかりやすい言葉に変換",
                                 destination: AnyView(TranslationToolView())),
                        ToolCard(emoji: "📝", title: "要約",
                                 desc: "長い文章をサクッと要約",
                                 destination: AnyView(SummaryToolView())),
                    ])

                    // 学習・創作ツール
                    ToolSection(title: "📚 学習・創作", tools: [
                        ToolCard(emoji: "🧪", title: "クイズ作成",
                                 desc: "テキストから練習問題を自動生成",
                                 destination: AnyView(QuizMakerView())),
                        ToolCard(emoji: "🖊️", title: "文章添削",
                                 desc: "ブログ・日記・エッセイの文章を改善",
                                 destination: AnyView(ProofreadingView())),
                        ToolCard(emoji: "💡", title: "ブレインストーミング",
                                 desc: "テーマからアイデアを大量に出す",
                                 destination: AnyView(BrainstormView())),
                        ToolCard(emoji: "📸", title: "画像について質問",
                                 desc: "写真を撮って内容をAIに聞く",
                                 destination: AnyView(ImageQuestionView())),
                    ])
                }
                .padding()
            }
            .navigationTitle("✨ AIツール")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Tool Section
struct ToolSection: View {
    let title: String
    let tools: [ToolCard]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(tools) { tool in
                    NavigationLink(destination: tool.destination) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(tool.emoji)
                                .font(.title2)
                            Text(tool.title)
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(tool.desc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(.systemGray6))
                        .cornerRadius(14)
                    }
                }
            }
        }
    }
}

struct ToolCard: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let desc: String
    let destination: AnyView
}

// MARK: - 🎙️ ボイスメモ → 議事録・TODO
struct VoiceMemoToolView: View {
    @State private var isRecording = false
    @State private var recordedText = ""
    @State private var result = ""
    @State private var outputMode: OutputMode = .minutes
    @State private var isProcessing = false
    @State private var recorder = AudioMemoRecorder()

    enum OutputMode: String, CaseIterable {
        case minutes = "議事録"
        case todo    = "TODOリスト"
        case summary = "要点まとめ"

        var emoji: String {
            switch self {
            case .minutes: return "📋"
            case .todo:    return "✅"
            case .summary: return "📌"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 出力形式選択
                Picker("出力形式", selection: $outputMode) {
                    ForEach(OutputMode.allCases, id: \.self) { mode in
                        Text("\(mode.emoji) \(mode.rawValue)").tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // 録音ボタン
                VStack(spacing: 12) {
                    Button {
                        if isRecording {
                            recorder.stop { text in
                                recordedText = text ?? ""
                                isRecording = false
                            }
                        } else {
                            recordedText = ""
                            result = ""
                            isRecording = true
                            recorder.start()
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(isRecording ? Color.red : Color.accentColor)
                                    .frame(width: 80, height: 80)
                                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                            Text(isRecording ? "タップして録音停止" : "タップして録音開始")
                                .font(.subheadline)
                                .foregroundColor(isRecording ? .red : .primary)
                        }
                    }
                    .symbolEffect(.pulse, isActive: isRecording)

                    if isRecording {
                        HStack(spacing: 6) {
                            Circle().fill(Color.red).frame(width: 8, height: 8)
                                .opacity(isRecording ? 1 : 0)
                                .animation(.easeInOut(duration: 0.6).repeatForever(), value: isRecording)
                            Text("録音中...")
                                .font(.caption).foregroundColor(.red)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)

                // テキスト入力（直接入力も可能）
                VStack(alignment: .leading, spacing: 8) {
                    Text("テキストを直接貼り付けることもできます")
                        .font(.caption).foregroundColor(.secondary)
                        .padding(.horizontal)
                    TextEditor(text: $recordedText)
                        .frame(height: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .font(.callout)
                        .padding(.horizontal)
                }

                // 変換ボタン
                Button {
                    processText()
                } label: {
                    HStack {
                        if isProcessing {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "wand.and.sparkles")
                        }
                        Text(isProcessing ? "作成中..." : "\(outputMode.emoji) \(outputMode.rawValue)を作成")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(recordedText.isEmpty ? Color(.systemGray4) : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .padding(.horizontal)
                }
                .disabled(recordedText.isEmpty || isProcessing)

                // 結果
                if !result.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("\(outputMode.emoji) \(outputMode.rawValue)")
                                .font(.headline)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = result
                            } label: {
                                Label("コピー", systemImage: "doc.on.doc")
                                    .font(.caption)
                            }
                            ShareLink(item: result) {
                                Label("共有", systemImage: "square.and.arrow.up")
                                    .font(.caption)
                            }
                        }
                        Text(result)
                            .font(.callout)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(14)
                    .padding(.horizontal)
                }

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("🎙️ ボイスメモ変換")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func processText() {
        isProcessing = true
        result = ""

        let prompt: String
        switch outputMode {
        case .minutes:
            prompt = """
            以下の音声テキストまたは会話メモを、読みやすい議事録形式に整理してください。
            【形式】
            - 日時：（わかれば）
            - 参加者：（わかれば）
            - 決定事項：
            - 話し合った内容：
            - 次のアクション：

            テキスト:
            \(recordedText)
            """
        case .todo:
            prompt = """
            以下のテキストから「やること（TODO）」だけを抽出して、箇条書きにしてください。
            優先度が高いものに「🔴 」、中程度に「🟡 」、低いものに「⚪️ 」をつけてください。

            テキスト:
            \(recordedText)
            """
        case .summary:
            prompt = """
            以下のテキストを3〜5つの重要なポイントに要約してください。
            箇条書きでわかりやすくまとめてください。

            テキスト:
            \(recordedText)
            """
        }

        Task {
            do {
                let llm = LLMService(privacyConfig: .shared)
                var full = ""
                for try await chunk in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: "あなたは優秀なビジネスアシスタントです。指示通りに整理・出力してください。"
                ) {
                    full += chunk
                }
                result = full
            } catch {
                result = "エラーが発生しました: \(error.localizedDescription)"
            }
            isProcessing = false
        }
    }
}

// MARK: - Audio Memo Recorder
class AudioMemoRecorder {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var accumulatedText = ""

    func start() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { return }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        try? audioEngine.start()

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, _ in
            if let result {
                self?.accumulatedText = result.bestTranscription.formattedString
            }
        }
    }

    func stop(completion: @escaping (String?) -> Void) {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            completion(self?.accumulatedText)
            self?.accumulatedText = ""
        }
    }
}

// MARK: - 📧 メール・文書作成
struct DocumentWriterView: View {
    @State private var docType: DocType = .email
    @State private var context = ""
    @State private var tone: Tone = .polite
    @State private var result = ""
    @State private var isProcessing = false

    enum DocType: String, CaseIterable {
        case email    = "ビジネスメール"
        case report   = "報告書"
        case proposal = "提案書"
        case apology  = "お詫び文"
        case thanks   = "お礼状"

        var placeholder: String {
            switch self {
            case .email:    return "例：来週の会議の日程調整をお願いしたい"
            case .report:   return "例：先月の売上は目標比120%、主な要因は..."
            case .proposal: return "例：新しいマーケティング施策を提案したい"
            case .apology:  return "例：納品が遅れてしまったことについて"
            case .thanks:   return "例：プロジェクトを手伝ってもらった同僚に"
            }
        }
    }

    enum Tone: String, CaseIterable {
        case polite   = "丁寧"
        case formal   = "フォーマル"
        case casual   = "カジュアル"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("文書種類", selection: $docType) {
                    ForEach(DocType.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 6) {
                    Text("何を伝えたいですか？")
                        .font(.headline).padding(.horizontal)
                    TextEditor(text: $context)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .font(.callout)
                        .padding(.horizontal)
                    Text(docType.placeholder)
                        .font(.caption).foregroundColor(.secondary).padding(.horizontal)
                }

                HStack {
                    Text("文体：").font(.subheadline).padding(.leading)
                    Picker("文体", selection: $tone) {
                        ForEach(Tone.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.trailing)
                }

                Button {
                    generate()
                } label: {
                    generateButtonLabel
                }
                .disabled(context.isEmpty || isProcessing)
                .padding(.horizontal)

                if !result.isEmpty { resultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("📧 文書作成")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var generateButtonLabel: some View {
        HStack {
            if isProcessing { ProgressView().tint(.white) }
            else { Image(systemName: "wand.and.sparkles") }
            Text(isProcessing ? "作成中..." : "作成する")
        }
        .font(.headline)
        .frame(maxWidth: .infinity).padding()
        .background(context.isEmpty ? Color(.systemGray4) : Color.accentColor)
        .foregroundColor(.white).cornerRadius(14)
    }

    private func generate() {
        isProcessing = true; result = ""
        Task {
            let prompt = "\(docType.rawValue)を書いてください。\n文体：\(tone.rawValue)\n内容：\(context)"
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: "あなたは優秀なビジネスライターです。"
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: - 📊 アイデア整理
struct IdeaOrganizerView: View {
    @State private var input = ""
    @State private var outputFormat: Format = .structured
    @State private var result = ""
    @State private var isProcessing = false

    enum Format: String, CaseIterable {
        case structured = "構造化"
        case slides     = "スライド構成"
        case mindmap    = "マインドマップ風"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("バラバラなアイデアや箇条書きを入力")
                        .font(.headline).padding(.horizontal)
                    TextEditor(text: $input)
                        .frame(height: 140)
                        .padding(8).background(Color(.systemGray6))
                        .cornerRadius(12).padding(.horizontal)
                }
                Picker("出力形式", selection: $outputFormat) {
                    ForEach(Format.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).padding(.horizontal)
                actionButton { organize() }
                if !result.isEmpty { resultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("📊 アイデア整理")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func organize() {
        isProcessing = true; result = ""
        Task {
            let prompt = "以下のアイデア・メモを\(outputFormat.rawValue)形式で整理してください:\n\(input)"
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: "あなたはアイデア整理の専門家です。"
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: - ✅ TODOリスト作成
struct TodoMakerView: View {
    @State private var situation = ""
    @State private var result = ""
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("状況・やりたいことを書いてください")
                        .font(.headline).padding(.horizontal)
                    TextEditor(text: $situation)
                        .frame(height: 120)
                        .padding(8).background(Color(.systemGray6))
                        .cornerRadius(12).padding(.horizontal)
                    Text("例：来週引越しがある / 新しいプロジェクトを始める")
                        .font(.caption).foregroundColor(.secondary).padding(.horizontal)
                }
                actionButton { makeTodo() }
                if !result.isEmpty { resultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("✅ TODOリスト作成")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func makeTodo() {
        isProcessing = true; result = ""
        Task {
            let prompt = "以下の状況から、具体的なTODOリストを優先度順に作成してください:\n\(situation)"
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: "あなたはタスク管理の専門家です。実行可能な具体的なステップに分解してください。"
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: - 🍳 レシピアドバイザー
struct RecipeToolView: View {
    @State private var ingredients = ""
    @State private var timeLimit = "30分以内"
    @State private var result = ""
    @State private var isProcessing = false
    let times = ["15分以内", "30分以内", "1時間以内", "時間は問わない"]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("冷蔵庫にある食材は？")
                        .font(.headline).padding(.horizontal)
                    TextField("例：鶏肉、玉ねぎ、にんじん、じゃがいも", text: $ingredients)
                        .padding().background(Color(.systemGray6)).cornerRadius(12).padding(.horizontal)
                }
                HStack {
                    Text("調理時間：").font(.subheadline).padding(.leading)
                    Picker("", selection: $timeLimit) {
                        ForEach(times, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu)
                }
                .padding(.horizontal)
                actionButton { getRecipes() }
                if !result.isEmpty { resultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("🍳 レシピアドバイザー")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func getRecipes() {
        isProcessing = true; result = ""
        Task {
            let prompt = "以下の食材で作れる料理を2〜3個提案してください。調理時間：\(timeLimit)\n食材：\(ingredients)"
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: "あなたはプロの料理研究家です。"
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: - ✈️ 旅行プランナー
struct TravelPlannerView: View {
    @State private var destination = ""
    @State private var nights = "2泊3日"
    @State private var budget = "特に指定なし"
    @State private var preferences = ""
    @State private var result = ""
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Group {
                    inputField(label: "行き先", placeholder: "例：京都、沖縄、北海道", text: $destination)
                    inputField(label: "日程", placeholder: "例：2泊3日", text: $nights)
                    inputField(label: "予算目安", placeholder: "例：一人3万円", text: $budget)
                    inputField(label: "こだわり・希望", placeholder: "例：温泉が好き、子ども連れ", text: $preferences)
                }
                actionButton { planTrip() }
                if !result.isEmpty { resultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("✈️ 旅行プランナー")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func inputField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.bold()).padding(.horizontal)
            TextField(placeholder, text: text)
                .padding().background(Color(.systemGray6)).cornerRadius(12).padding(.horizontal)
        }
    }

    private func planTrip() {
        isProcessing = true; result = ""
        Task {
            let prompt = "旅行プランを作ってください。行き先：\(destination)、日程：\(nights)、予算：\(budget)、希望：\(preferences)"
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: "あなたはプロの旅行プランナーです。具体的な観光スポットや食事も含めて提案してください。"
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: - 🌐 翻訳・言い換え
struct TranslationToolView: View {
    @State private var input = ""
    @State private var mode: Mode = .toEnglish
    @State private var result = ""
    @State private var isProcessing = false

    enum Mode: String, CaseIterable {
        case toEnglish  = "日本語→英語"
        case toJapanese = "英語→日本語"
        case simple     = "わかりやすく"
        case formal     = "丁寧・フォーマルに"
        case casual     = "カジュアルに"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("変換モード", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu).padding()
                .background(Color(.systemGray6)).cornerRadius(12).padding(.horizontal)

                TextEditor(text: $input)
                    .frame(height: 120)
                    .padding(8).background(Color(.systemGray6))
                    .cornerRadius(12).padding(.horizontal)

                actionButton { translate() }
                if !result.isEmpty { resultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("🌐 翻訳・言い換え")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func translate() {
        isProcessing = true; result = ""
        Task {
            let prompt: String
            switch mode {
            case .toEnglish:  prompt = "以下を英語に翻訳:\n\(input)"
            case .toJapanese: prompt = "以下を日本語に翻訳:\n\(input)"
            case .simple:     prompt = "以下を子どもでもわかる簡単な言葉に言い換えてください:\n\(input)"
            case .formal:     prompt = "以下を丁寧でフォーマルな表現に変えてください:\n\(input)"
            case .casual:     prompt = "以下をカジュアルで親しみやすい表現に変えてください:\n\(input)"
            }
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: "あなたは言語の専門家です。"
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: - 📝 要約
struct SummaryToolView: View {
    @State private var input = ""
    @State private var length: Length = .short
    @State private var result = ""
    @State private var isProcessing = false

    enum Length: String, CaseIterable {
        case short  = "3行で"
        case medium = "5〜8行で"
        case bullet = "箇条書きで"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("要約の長さ", selection: $length) {
                    ForEach(Length.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).padding(.horizontal)

                TextEditor(text: $input)
                    .frame(height: 160)
                    .padding(8).background(Color(.systemGray6))
                    .cornerRadius(12).padding(.horizontal)

                actionButton { summarize() }
                if !result.isEmpty { resultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("📝 要約")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summarize() {
        isProcessing = true; result = ""
        Task {
            let prompt = "以下の文章を\(length.rawValue)要約してください:\n\(input)"
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: "あなたは文章要約の専門家です。"
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: - 🧪 クイズ作成
struct QuizMakerView: View {
    @State private var material = ""
    @State private var count = 5
    @State private var result = ""
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("問題にしたいテキストを入力")
                        .font(.headline).padding(.horizontal)
                    TextEditor(text: $material)
                        .frame(height: 140)
                        .padding(8).background(Color(.systemGray6))
                        .cornerRadius(12).padding(.horizontal)
                }
                HStack {
                    Text("問題数：").font(.subheadline).padding(.leading)
                    Stepper("\(count)問", value: $count, in: 3...10).padding(.trailing)
                }
                .padding(.horizontal)
                actionButton { makeQuiz() }
                if !result.isEmpty { resultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("🧪 クイズ作成")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func makeQuiz() {
        isProcessing = true; result = ""
        Task {
            let prompt = "以下のテキストから\(count)問の4択クイズを作成してください。答えも書いてください:\n\(material)"
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: "あなたは教育の専門家です。"
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: - 🖊️ 文章添削
struct ProofreadingView: View {
    @State private var input = ""
    @State private var result = ""
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("添削したい文章を入力")
                        .font(.headline).padding(.horizontal)
                    TextEditor(text: $input)
                        .frame(height: 160)
                        .padding(8).background(Color(.systemGray6))
                        .cornerRadius(12).padding(.horizontal)
                }
                actionButton { proofread() }
                if !result.isEmpty { resultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("🖊️ 文章添削")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func proofread() {
        isProcessing = true; result = ""
        Task {
            let prompt = "以下の文章を添削してください。誤字・脱字の修正、読みやすさの改善点、改善後の文章を提示してください:\n\(input)"
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: "あなたはプロの編集者です。"
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: - 💡 ブレインストーミング
struct BrainstormView: View {
    @State private var theme = ""
    @State private var count = 10
    @State private var result = ""
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("テーマを入力してください")
                        .font(.headline).padding(.horizontal)
                    TextField("例：新しいビジネスアイデア、夏休みの計画...", text: $theme)
                        .padding().background(Color(.systemGray6)).cornerRadius(12).padding(.horizontal)
                }
                HStack {
                    Text("アイデア数：").font(.subheadline).padding(.leading)
                    Stepper("\(count)個", value: $count, in: 5...20).padding(.trailing)
                }
                actionButton { brainstorm() }
                if !result.isEmpty { resultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("💡 ブレインストーミング")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func brainstorm() {
        isProcessing = true; result = ""
        Task {
            let prompt = "「\(theme)」に関するアイデアを\(count)個出してください。ユニークで実用的なものをお願いします。"
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: "あなたはクリエイティブなアイデアマンです。型にはまらない発想で。"
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: - 📸 画像について質問
struct ImageQuestionView: View {
    @State private var selectedImage: UIImage?
    @State private var question = ""
    @State private var result = ""
    @State private var showPicker = false
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 画像選択
                Button { showPicker = true } label: {
                    if let img = selectedImage {
                        Image(uiImage: img)
                            .resizable().scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 40)).foregroundColor(.accentColor)
                            Text("写真を選ぶ")
                                .font(.subheadline).foregroundColor(.accentColor)
                        }
                        .frame(maxWidth: .infinity).frame(height: 140)
                        .background(Color(.systemGray6)).cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                TextField("この画像について何を知りたいですか？", text: $question)
                    .padding().background(Color(.systemGray6)).cornerRadius(12).padding(.horizontal)

                // Vision未対応の旨を案内
                if selectedImage != nil {
                    Text("💡 現在は画像についての質問をテキストで記述してAIに送れます。Claude APIのビジョン機能は今後対応予定です。")
                        .font(.caption).foregroundColor(.secondary).padding(.horizontal)
                }

                actionButton { askAboutImage() }
                if !result.isEmpty { resultCard(result) }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("📸 画像について質問")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
    }

    private func askAboutImage() {
        isProcessing = true; result = ""
        Task {
            let prompt = question.isEmpty ? "この画像について説明してください" : question
            var full = ""
            do {
                let llm = LLMService(privacyConfig: .shared)
                for try await c in await llm.sendMessageStream(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    systemPrompt: "あなたは画像解析のアシスタントです。"
                ) { full += c }
                result = full
            } catch { result = "エラー: \(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ p: ImagePicker) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.selectedImage = info[.originalImage] as? UIImage
            parent.dismiss()
        }
    }
}

// MARK: - Shared Helpers (各ツールで共通利用)
private var isProcessingState = false

func actionButton(action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack {
            Image(systemName: "wand.and.sparkles")
            Text("AIに作ってもらう")
        }
        .font(.headline).frame(maxWidth: .infinity)
        .padding().background(Color.accentColor)
        .foregroundColor(.white).cornerRadius(14)
        .padding(.horizontal)
    }
}

func resultCard(_ text: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        HStack {
            Text("✨ 結果").font(.headline)
            Spacer()
            Button { UIPasteboard.general.string = text } label: {
                Label("コピー", systemImage: "doc.on.doc").font(.caption)
            }
            ShareLink(item: text) {
                Label("共有", systemImage: "square.and.arrow.up").font(.caption)
            }
        }
        Text(text)
            .font(.callout).textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding().background(Color(.systemGray6))
    .cornerRadius(14).padding(.horizontal)
}
