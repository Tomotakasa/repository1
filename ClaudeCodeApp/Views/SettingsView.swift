import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var privacyConfig = PrivacyConfig.shared
    @State private var showPrivacySettings = false
    @State private var showAPIKeyInput = false
    @State private var showGitHubTokenInput = false
    @State private var showDeleteDataConfirmation = false

    var body: some View {
        List {
            // プライバシー・セキュリティセクション（最上部に配置）
            Section {
                NavigationLink {
                    PrivacySettingsView()
                } label: {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                            .frame(width: 28)
                        VStack(alignment: .leading) {
                            Text("プライバシー・セキュリティ")
                                .font(.body)
                            Text(privacyStatusText)
                                .font(.caption)
                                .foregroundColor(privacyConfig.isFullyLocalMode ? .green : .orange)
                        }
                    }
                }
            } header: {
                Text("セキュリティ")
            } footer: {
                if privacyConfig.isFullyLocalMode {
                    Label("完全ローカルモード: データは外部に送信されません", systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("一部データが外部サービスに送信されます", systemImage: "exclamationmark.shield")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            // LLM設定セクション
            Section {
                NavigationLink {
                    LLMSettingsView()
                } label: {
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(.accentColor)
                            .frame(width: 28)
                        VStack(alignment: .leading) {
                            Text("AIモデル設定")
                            Text(privacyConfig.llmBackend.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if privacyConfig.llmBackend == .claudeAPI {
                    Button {
                        showAPIKeyInput = true
                    } label: {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.yellow)
                                .frame(width: 28)
                            VStack(alignment: .leading) {
                                Text("Claude APIキー")
                                Text(appState.claudeAPIKey.isEmpty ? "未設定" : "設定済み ●●●●●●●●")
                                    .font(.caption)
                                    .foregroundColor(appState.claudeAPIKey.isEmpty ? .red : .green)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if privacyConfig.llmBackend == .customOpenAICompatible {
                    Button {
                        showAPIKeyInput = true
                    } label: {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.yellow)
                                .frame(width: 28)
                            VStack(alignment: .leading) {
                                Text("カスタムサーバー APIキー")
                                Text("（不要な場合は空欄でOK）")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("AIモデル")
            }

            // GitHub/VCS設定セクション
            Section {
                NavigationLink {
                    VCSSettingsView()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundColor(.purple)
                            .frame(width: 28)
                        VStack(alignment: .leading) {
                            Text("VCS設定")
                            Text(privacyConfig.vcsBackend.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Button {
                    showGitHubTokenInput = true
                } label: {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.purple)
                            .frame(width: 28)
                        VStack(alignment: .leading) {
                            Text("アクセストークン")
                            Text(appState.gitHubToken.isEmpty ? "未設定" : "設定済み ●●●●●●●●")
                                .font(.caption)
                                .foregroundColor(appState.gitHubToken.isEmpty ? .orange : .green)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if appState.isGitHubAuthenticated {
                    Button(role: .destructive) {
                        appState.logoutGitHub()
                    } label: {
                        HStack {
                            Image(systemName: "person.fill.xmark")
                                .frame(width: 28)
                            Text("GitHubからログアウト")
                        }
                    }
                }
            } header: {
                Text("リポジトリ連携")
            }

            // データ管理セクション
            Section {
                Toggle(isOn: $privacyConfig.persistConversationHistory) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                            .frame(width: 28)
                        Text("会話履歴を保存")
                    }
                }

                Toggle(isOn: $privacyConfig.enableLocalEncryption) {
                    HStack {
                        Image(systemName: "lock.doc.fill")
                            .foregroundColor(.orange)
                            .frame(width: 28)
                        Text("ローカルデータを暗号化")
                    }
                }

                Toggle(isOn: $privacyConfig.autoClearClipboard) {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundColor(.gray)
                            .frame(width: 28)
                        Text("クリップボードを自動クリア")
                    }
                }

                Button(role: .destructive) {
                    showDeleteDataConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                            .frame(width: 28)
                        Text("すべての会話履歴を削除")
                    }
                }
            } header: {
                Text("データ管理")
            } footer: {
                Text("「暗号化」をONにすると、会話データがAES-256-GCMで暗号化されてデバイスに保存されます。キーはKeychainに安全に保管されます。")
            }

            // アプリ情報セクション
            Section("アプリ情報") {
                HStack {
                    Text("バージョン")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundColor(.secondary)
                }

                Link(destination: URL(string: "https://github.com/anthropics/claude-code")!) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.accentColor)
                        Text("Claude Code (公式)")
                    }
                }
            }
        }
        .navigationTitle("設定")
        .sheet(isPresented: $showAPIKeyInput) {
            APIKeyInputView(
                title: privacyConfig.llmBackend == .claudeAPI ? "Claude APIキー" : "APIキー",
                currentKey: privacyConfig.llmBackend == .claudeAPI ? appState.claudeAPIKey : (KeychainService().load(key: KeychainKeys.customLLMAPIKey) ?? ""),
                isOptional: privacyConfig.llmBackend == .customOpenAICompatible,
                hint: privacyConfig.llmBackend == .claudeAPI ? "sk-ant-..." : "任意"
            ) { key in
                if privacyConfig.llmBackend == .claudeAPI {
                    appState.saveClaudeAPIKey(key)
                } else {
                    KeychainService().save(key: KeychainKeys.customLLMAPIKey, value: key)
                }
            }
        }
        .sheet(isPresented: $showGitHubTokenInput) {
            APIKeyInputView(
                title: "アクセストークン",
                currentKey: appState.gitHubToken,
                isOptional: false,
                hint: "ghp_... または glpat-... (Gitea/GitLab)"
            ) { token in
                appState.saveGitHubToken(token)
            }
        }
        .confirmationDialog("会話履歴の削除", isPresented: $showDeleteDataConfirmation) {
            Button("すべて削除", role: .destructive) {
                try? ConversationStorageManager.shared.deleteAll()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("すべての会話履歴が完全に削除されます。この操作は取り消せません。")
        }
    }

    private var privacyStatusText: String {
        if privacyConfig.isFullyLocalMode {
            return "完全ローカルモード"
        } else if privacyConfig.vcsBackend.isPrivate || privacyConfig.llmBackend != .claudeAPI {
            return "部分的にプライベート"
        } else {
            return "外部サービス使用中"
        }
    }
}

// MARK: - Privacy Settings View
struct PrivacySettingsView: View {
    @StateObject private var config = PrivacyConfig.shared

    var body: some View {
        List {
            Section {
                privacyStatusCard
            }

            Section("データフロー") {
                DataFlowRow(
                    service: "AIモデル",
                    destination: config.llmBackend.displayName,
                    isPrivate: config.llmBackend.isPrivate,
                    detail: config.llmBackend == .claudeAPI ? "チャット内容がAnthropicサーバーに送信されます" : "データはローカルまたは自社サーバーのみに送信されます"
                )

                DataFlowRow(
                    service: "コードリポジトリ",
                    destination: config.vcsBackend.displayName,
                    isPrivate: config.vcsBackend.isPrivate,
                    detail: config.vcsBackend == .githubCloud ? "コードがGitHubに保存されます" : "コードは自社サーバーのみに保存されます"
                )

                DataFlowRow(
                    service: "会話履歴",
                    destination: "デバイス内",
                    isPrivate: true,
                    detail: config.enableLocalEncryption ? "AES-256-GCMで暗号化されて保存" : "暗号化なしでローカル保存"
                )
            }

            Section("ネットワーク設定") {
                Toggle("SSL証明書の検証をスキップ", isOn: $config.skipSSLVerification)
                    .tint(.orange)

                if config.skipSSLVerification {
                    Label("自己署名証明書のプライベートサーバー向けの設定です", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                TextField("プロキシホスト (任意)", text: $config.proxyHost)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)

                if !config.proxyHost.isEmpty {
                    HStack {
                        Text("プロキシポート")
                        Spacer()
                        TextField("8080", value: $config.proxyPort, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            }
        }
        .navigationTitle("プライバシー・セキュリティ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var privacyStatusCard: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: config.isFullyLocalMode ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.title2)
                    .foregroundColor(config.isFullyLocalMode ? .green : .orange)

                VStack(alignment: .leading) {
                    Text(config.isFullyLocalMode ? "完全ローカルモード" : "外部サービス使用中")
                        .font(.headline)
                    Text(config.isFullyLocalMode ?
                         "機密データは外部に送信されません" :
                         "設定を変更して外部送信を最小化できます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - LLM Settings View
struct LLMSettingsView: View {
    @StateObject private var config = PrivacyConfig.shared

    var body: some View {
        List {
            Section {
                ForEach(LLMBackend.allCases) { backend in
                    Button {
                        config.llmBackend = backend
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(backend.displayName)
                                        .foregroundColor(.primary)
                                    if backend.isPrivate {
                                        Image(systemName: "lock.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                                Text(backend.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if config.llmBackend == backend {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("AIバックエンド")
            }

            if config.llmBackend == .ollama || config.llmBackend == .customOpenAICompatible {
                Section {
                    TextField(
                        config.llmBackend == .ollama ? "http://localhost:11434" : "http://your-server.com/v1",
                        text: $config.customLLMEndpoint
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                } header: {
                    Text("エンドポイントURL")
                } footer: {
                    if config.llmBackend == .ollama {
                        Text("OllamaはiPhoneと同じネットワーク上のMac/PCで動作している必要があります。\nMacでの起動: ollama serve")
                    } else {
                        Text("OpenAI互換API (例: LM Studio, vLLM, llama.cpp server など)")
                    }
                }

                Section {
                    TextField("モデル名 (例: llama3.2, codestral)", text: $config.ollamaModel)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("使用するモデル")
                } footer: {
                    if config.llmBackend == .ollama {
                        Text("モデルのダウンロード: ollama pull llama3.2")
                    }
                }
            }
        }
        .navigationTitle("AIモデル設定")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - VCS Settings View
struct VCSSettingsView: View {
    @StateObject private var config = PrivacyConfig.shared

    var body: some View {
        List {
            Section {
                ForEach(VCSBackend.allCases) { backend in
                    Button {
                        config.vcsBackend = backend
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(backend.displayName)
                                        .foregroundColor(.primary)
                                    if backend.isPrivate {
                                        Image(systemName: "building.2")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                                Text(backend.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if config.vcsBackend == backend {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("リポジトリサービス")
            }

            if config.vcsBackend != .githubCloud {
                Section {
                    TextField(
                        "https://github.your-company.com/api/v3",
                        text: $config.customVCSBaseURL
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                } header: {
                    Text("APIベースURL")
                } footer: {
                    switch config.vcsBackend {
                    case .githubEnterprise:
                        Text("GitHub Enterprise: https://[hostname]/api/v3")
                    case .gitea:
                        Text("Gitea: https://[your-gitea-server]/api/v1")
                    case .gitlab:
                        Text("GitLab: https://[your-gitlab-server]/api/v4")
                    default:
                        EmptyView()
                    }
                }
            }
        }
        .navigationTitle("VCS設定")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - API Key Input View
struct APIKeyInputView: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let currentKey: String
    let isOptional: Bool
    let hint: String
    let onSave: (String) -> Void

    @State private var inputKey: String
    @State private var showKey = false

    init(title: String, currentKey: String, isOptional: Bool, hint: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.currentKey = currentKey
        self.isOptional = isOptional
        self.hint = hint
        self.onSave = onSave
        self._inputKey = State(initialValue: currentKey)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if showKey {
                            TextField(hint, text: $inputKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField(hint, text: $inputKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text(title)
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("キーはデバイスのKeychainに安全に保存されます。外部に送信されることはありません。")
                        if isOptional {
                            Text("このフィールドは任意です。サーバーが認証を必要としない場合は空欄でOKです。")
                        }
                    }
                }

                if !inputKey.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            inputKey = ""
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("クリア")
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(inputKey)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Data Flow Row
struct DataFlowRow: View {
    let service: String
    let destination: String
    let isPrivate: Bool
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(service)
                    .font(.body)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: isPrivate ? "lock.fill" : "cloud")
                        .font(.caption)
                    Text(destination)
                        .font(.caption)
                }
                .foregroundColor(isPrivate ? .green : .orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((isPrivate ? Color.green : Color.orange).opacity(0.1))
                .cornerRadius(6)
            }
            Text(detail)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}
