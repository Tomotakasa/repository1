import SwiftUI

// MARK: - Settings View (わかりやすい設定画面)
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var profileManager = ProfileManager.shared
    @StateObject private var memoryService  = MemoryService.shared
    @StateObject private var docService     = DocumentService.shared

    @State private var showAPIKeyInput    = false
    @State private var showGitHubInput    = false
    @State private var showLocalAIGuide   = false
    @State private var showDeleteConfirm  = false

    var body: some View {
        List {
            // ── プロフィール ──────────────────
            Section {
                ForEach(profileManager.profiles) { profile in
                    NavigationLink {
                        EditProfileView(profile: profile)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(profile.color).frame(width: 40, height: 40)
                                Text(profile.iconEmoji).font(.title3)
                            }
                            VStack(alignment: .leading) {
                                Text(profile.name).font(.headline)
                                Text(profile.role.displayName).font(.caption).foregroundColor(.secondary)
                            }
                            if profileManager.currentProfileID == profile.id {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
                            }
                        }
                    }
                }
                NavigationLink {
                    AddProfileView()
                } label: {
                    Label("家族を追加", systemImage: "person.badge.plus")
                        .foregroundColor(.accentColor)
                }
            } header: {
                Text("👨‍👩‍👧‍👦 家族のプロフィール")
            }

            // ── AI設定 ──────────────────────
            Section {
                // APIキー状態
                Button { showAPIKeyInput = true } label: {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.yellow).frame(width: 28)
                        VStack(alignment: .leading) {
                            Text("AIのキー (Claude APIキー)")
                            Text(appState.claudeAPIKey.isEmpty
                                 ? "⚠️ 未設定 — タップして設定"
                                 : "✅ 設定済み")
                                .font(.caption)
                                .foregroundColor(appState.claudeAPIKey.isEmpty ? .red : .green)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                // ローカルAIガイド
                Button { showLocalAIGuide = true } label: {
                    HStack {
                        Image(systemName: "desktopcomputer")
                            .foregroundColor(.purple).frame(width: 28)
                        VStack(alignment: .leading) {
                            Text("ローカルAI (インターネット不要)")
                            Text("Ollamaを使って完全オフラインで動かす")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("🤖 AI設定")
            } footer: {
                Text("「ローカルAI」を使うと、インターネットなし・完全無料でAIが使えます")
            }

            // ── GitHub保存設定 ──────────────
            Section {
                Button { showGitHubInput = true } label: {
                    HStack {
                        Image(systemName: "folder.badge.gearshape")
                            .foregroundColor(.blue).frame(width: 28)
                        VStack(alignment: .leading) {
                            Text("会話を保存するトークン (GitHub)")
                            Text(appState.gitHubToken.isEmpty
                                 ? "未設定 — 設定しなくてもOK"
                                 : "✅ 設定済み")
                                .font(.caption)
                                .foregroundColor(appState.gitHubToken.isEmpty ? .secondary : .green)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if appState.isGitHubAuthenticated {
                    Button(role: .destructive) { appState.logoutGitHub() } label: {
                        Label("GitHubとの連携を解除", systemImage: "person.fill.xmark")
                    }
                }
            } header: {
                Text("📁 会話の保存先")
            } footer: {
                Text("設定しなくても会話はこのiPhoneに保存されます。GitHubに保存すると機種変更後もデータが残ります。")
            }

            // ── データ管理 ──────────────────
            Section {
                HStack {
                    Image(systemName: "brain").foregroundColor(.purple).frame(width: 28)
                    Text("AIが覚えていること")
                    Spacer()
                    Text("\(memoryService.memories.count)件")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Image(systemName: "doc.fill").foregroundColor(.orange).frame(width: 28)
                    Text("学習させた資料")
                    Spacer()
                    Text("\(docService.documents.count)件")
                        .foregroundColor(.secondary)
                }
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("すべての履歴・記憶を削除", systemImage: "trash")
                }
            } header: {
                Text("📊 データ管理")
            }

            // ── アプリ情報 ──────────────────
            Section("ℹ️ アプリ情報") {
                HStack {
                    Text("バージョン")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("設定")
        .sheet(isPresented: $showAPIKeyInput) {
            SimpleKeyInputView(
                title: "AIのキー (Claude APIキー)",
                hint: "sk-ant-から始まる文字列",
                helpText: "Anthropic Console (console.anthropic.com) から取得できます",
                currentValue: appState.claudeAPIKey
            ) { key in appState.saveClaudeAPIKey(key) }
        }
        .sheet(isPresented: $showGitHubInput) {
            SimpleKeyInputView(
                title: "GitHub トークン",
                hint: "ghp_から始まる文字列",
                helpText: "github.com → Settings → Developer settings → Personal access tokens で取得",
                currentValue: appState.gitHubToken
            ) { token in appState.saveGitHubToken(token) }
        }
        .sheet(isPresented: $showLocalAIGuide) {
            LocalAIGuideView()
        }
        .confirmationDialog("データを削除しますか？", isPresented: $showDeleteConfirm) {
            Button("削除する", role: .destructive) {
                try? ConversationStorageManager.shared.deleteAll()
                memoryService.memories.removeAll()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("会話履歴とAIの記憶がすべて削除されます。元に戻せません。")
        }
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var pm = ProfileManager.shared

    @State var profile: FamilyProfile
    let colors = ["#4A90D9","#E74C3C","#2ECC71","#F39C12","#9B59B6","#1ABC9C","#E67E22","#34495E"]

    var body: some View {
        Form {
            Section("名前") {
                TextField("名前", text: $profile.name)
            }
            Section("誰ですか？") {
                Picker("種別", selection: $profile.role) {
                    ForEach(FamilyRole.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                .pickerStyle(.segmented)
            }
            if profile.role == .adult {
                Section("お仕事の種類（任意）") {
                    Picker("職業", selection: Binding(
                        get: { profile.workType },
                        set: { profile.workType = $0 }
                    )) {
                        Text("設定しない").tag(WorkType?.none)
                        ForEach(WorkType.allCases) { wt in
                            Text("\(wt.emoji) \(wt.displayName)").tag(WorkType?.some(wt))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            Section("アイコン") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                    ForEach(profile.role.defaultEmojis, id: \.self) { e in
                        Button { profile.iconEmoji = e } label: {
                            Text(e).font(.title2)
                                .frame(width: 40, height: 40)
                                .background(profile.iconEmoji == e ? Color.accentColor.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            Section("カラー") {
                HStack(spacing: 14) {
                    ForEach(colors, id: \.self) { hex in
                        Button { profile.colorHex = hex } label: {
                            ZStack {
                                Circle().fill(Color(hex: hex) ?? .blue).frame(width: 32, height: 32)
                                if profile.colorHex == hex {
                                    Image(systemName: "checkmark").font(.caption.bold()).foregroundColor(.white)
                                }
                            }
                        }
                    }
                }
            }
            Section {
                Button(role: .destructive) {
                    pm.deleteProfile(profile)
                    dismiss()
                } label: {
                    Label("このプロフィールを削除", systemImage: "trash")
                }
            }
        }
        .navigationTitle("プロフィール編集")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { pm.updateProfile(profile); dismiss() }.bold()
            }
        }
    }
}

// MARK: - Simple Key Input View
struct SimpleKeyInputView: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let hint: String
    let helpText: String
    let currentValue: String
    let onSave: (String) -> Void

    @State private var value: String
    @State private var showValue = false

    init(title: String, hint: String, helpText: String, currentValue: String, onSave: @escaping (String) -> Void) {
        self.title = title; self.hint = hint; self.helpText = helpText
        self.currentValue = currentValue; self.onSave = onSave
        self._value = State(initialValue: currentValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Group {
                            if showValue {
                                TextField(hint, text: $value)
                            } else {
                                SecureField(hint, text: $value)
                            }
                        }
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.body.monospaced())

                        Button { showValue.toggle() } label: {
                            Image(systemName: showValue ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text(title)
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(helpText)
                        Text("🔒 入力した情報はこのiPhoneのみに保存されます")
                            .foregroundColor(.green)
                    }
                }
                if !value.isEmpty {
                    Section {
                        Button(role: .destructive) { value = "" } label: {
                            Label("クリア", systemImage: "xmark.circle")
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { onSave(value); dismiss() }.bold()
                }
            }
        }
    }
}

// MARK: - Local AI Guide (ローカルAI設定ガイド)
struct LocalAIGuideView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var config = PrivacyConfig.shared
    @State private var showEndpointEdit = false

    // 軽量モデル一覧（容量小さい順）
    let recommendedModels: [OllamaModel] = [
        OllamaModel(name: "qwen2.5:0.5b",  size: "約0.4GB", speed: "超高速", quality: "★★☆",  desc: "超軽量。基本的な質問に"),
        OllamaModel(name: "phi3:mini",      size: "約2.2GB", speed: "高速",  quality: "★★★",  desc: "Microsoftが開発。日本語も◎"),
        OllamaModel(name: "gemma2:2b",      size: "約1.6GB", speed: "高速",  quality: "★★★",  desc: "Googleが開発。バランス型"),
        OllamaModel(name: "llama3.2:3b",    size: "約2.0GB", speed: "高速",  quality: "★★★",  desc: "Metaが開発。日本語対応"),
        OllamaModel(name: "llama3.1:8b",    size: "約4.7GB", speed: "普通",  quality: "★★★★", desc: "高品質。Mac推奨"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // ヘッダー
                    VStack(spacing: 8) {
                        Text("🖥️")
                            .font(.system(size: 50))
                        Text("ローカルAI設定ガイド")
                            .font(.title2.bold())
                        Text("MacやPCにOllamaをインストールすると、\niPhoneとWi-Fi経由で接続できます。\nインターネット不要・完全無料！")
                            .multilineTextAlignment(.center)
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    .padding()

                    // セットアップ手順
                    VStack(alignment: .leading, spacing: 16) {
                        Text("セットアップ手順（Mac）").font(.headline).padding(.horizontal)

                        StepCard(step: 1, title: "Ollamaをダウンロード",
                                 detail: "ollama.com からダウンロードしてインストール",
                                 action: "ollama.com を開く")
                        StepCard(step: 2, title: "モデルをダウンロード",
                                 detail: "ターミナルで下記コマンドを実行（1〜5分）",
                                 code: "ollama pull phi3:mini")
                        StepCard(step: 3, title: "Ollamaを起動",
                                 detail: "ターミナルで起動（iPhoneから接続するために必要）",
                                 code: "OLLAMA_HOST=0.0.0.0 ollama serve")
                        StepCard(step: 4, title: "iPhoneのIPアドレスを設定",
                                 detail: "MacのIPアドレスを確認して下に入力してください",
                                 isLast: true)
                    }

                    // IPアドレス設定
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MacのIPアドレス").font(.headline).padding(.horizontal)
                        HStack {
                            TextField("例: http://192.168.1.10:11434", text: $config.customLLMEndpoint)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)

                            Button {
                                config.llmBackend = .ollama
                            } label: {
                                Text("設定")
                                    .bold()
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        Text("💡 MacのIPアドレス確認：システム設定 → Wi-Fi → 詳細 → IPアドレス")
                            .font(.caption).foregroundColor(.secondary).padding(.horizontal)
                    }

                    // モデル一覧
                    VStack(alignment: .leading, spacing: 10) {
                        Text("おすすめモデル（容量の小さい順）")
                            .font(.headline).padding(.horizontal)

                        ForEach(recommendedModels, id: \.name) { model in
                            Button {
                                config.ollamaModel = model.name
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text(model.name)
                                                .font(.subheadline.bold().monospaced())
                                                .foregroundColor(.primary)
                                            if config.ollamaModel == model.name {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.caption).foregroundColor(.green)
                                            }
                                        }
                                        Text(model.desc)
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(model.size).font(.caption.bold())
                                            .foregroundColor(.orange)
                                        Text("速度: \(model.speed)").font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("品質: \(model.quality)").font(.caption2)
                                    }
                                }
                                .padding()
                                .background(config.ollamaModel == model.name
                                            ? Color.green.opacity(0.08)
                                            : Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }

                    // 現在の設定状態
                    VStack(alignment: .leading, spacing: 8) {
                        Text("現在のAI設定").font(.headline).padding(.horizontal)
                        VStack(alignment: .leading, spacing: 6) {
                            SettingRow(label: "バックエンド", value: config.llmBackend.displayName,
                                       isGood: config.llmBackend == .ollama)
                            SettingRow(label: "エンドポイント", value: config.effectiveLLMBaseURL, isGood: true)
                            SettingRow(label: "使用モデル", value: config.ollamaModel, isGood: true)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 30)
                }
            }
            .navigationTitle("ローカルAI設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

struct OllamaModel {
    let name: String
    let size: String
    let speed: String
    let quality: String
    let desc: String
}

struct StepCard: View {
    let step: Int
    let title: String
    let detail: String
    var code: String? = nil
    var action: String? = nil
    var isLast: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack {
                ZStack {
                    Circle().fill(Color.accentColor).frame(width: 28, height: 28)
                    Text("\(step)").font(.caption.bold()).foregroundColor(.white)
                }
                if !isLast {
                    Rectangle().fill(Color(.systemGray4)).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.subheadline.bold())
                Text(detail).font(.caption).foregroundColor(.secondary)
                if let code {
                    Text(code)
                        .font(.caption.monospaced())
                        .padding(8).background(Color.black.opacity(0.06)).cornerRadius(6)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, isLast ? 0 : 4)
    }
}

struct SettingRow: View {
    let label: String
    let value: String
    let isGood: Bool

    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary).frame(width: 90, alignment: .leading)
            Text(value).font(.caption.bold()).lineLimit(1)
            Spacer()
            Circle().fill(isGood ? Color.green : Color.orange).frame(width: 8, height: 8)
        }
    }
}
