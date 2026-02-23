import SwiftUI

// MARK: - GitHub メイン画面
struct GitHubView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = GitHubViewModel()

    var body: some View {
        Group {
            if appState.isGitHubAuthenticated {
                repositoryListView
            } else {
                notAuthenticatedView
            }
        }
        .navigationTitle("GitHub")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if appState.isGitHubAuthenticated {
                await viewModel.loadRepositories(service: appState.gitHubService)
            }
        }
    }

    // MARK: - Not Authenticated
    private var notAuthenticatedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 70))
                .foregroundColor(.secondary)

            Text("GitHub連携")
                .font(.title2.bold())

            Text("リポジトリのブラウズやファイルの作成には\nGitHubアカウントの連携が必要です")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            // バックエンド選択の案内
            if PrivacyConfig.shared.vcsBackend != .githubCloud {
                HStack {
                    Image(systemName: "building.2")
                    Text("\(PrivacyConfig.shared.vcsBackend.displayName)に接続中")
                        .font(.caption)
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
            }

            Button {
                authenticateWithGitHub()
            } label: {
                HStack {
                    Image(systemName: "person.badge.key")
                    Text("GitHubでログイン")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal, 40)
            }

            Button {
                appState.selectedTab = .settings
            } label: {
                Text("トークンを手動で設定する")
                    .font(.callout)
                    .foregroundColor(.accentColor)
            }

            Spacer()
        }
    }

    // MARK: - Repository List
    private var repositoryListView: some View {
        VStack(spacing: 0) {
            // ユーザー情報ヘッダー
            if let user = appState.gitHubUser {
                userHeader(user: user)
            }

            // 検索バー
            searchBar

            // リポジトリ一覧
            if viewModel.isLoading && viewModel.repositories.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.filteredRepositories) { repo in
                        NavigationLink {
                            RepositoryBrowserView(repository: repo)
                                .environmentObject(appState)
                        } label: {
                            RepositoryRow(repository: repo)
                        }
                    }

                    if viewModel.hasMoreRepositories {
                        Button("もっと見る") {
                            Task { await viewModel.loadMoreRepositories(service: appState.gitHubService) }
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.accentColor)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await viewModel.loadRepositories(service: appState.gitHubService)
                }
            }
        }
    }

    private func userHeader(user: GitHubUser) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: user.avatarUrl)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.secondary)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading) {
                Text(user.name ?? user.login)
                    .font(.headline)
                Text("@\(user.login)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // バックエンドインジケーター
            if PrivacyConfig.shared.vcsBackend.isPrivate {
                Label("プライベート", systemImage: "lock.fill")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("リポジトリを検索...", text: $viewModel.searchText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Actions
    private func authenticateWithGitHub() {
        if let url = appState.gitHubService.buildOAuthURLSync() {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Repository Row
struct RepositoryRow: View {
    let repository: GitHubRepository

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: repository.isPrivate ? "lock.fill" : "book.fill")
                    .foregroundColor(repository.isPrivate ? .orange : .accentColor)
                    .font(.caption)

                Text(repository.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if let lang = repository.language {
                    Text(lang)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }
            }

            if let desc = repository.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                Label("\(repository.stargazersCount)", systemImage: "star")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if let updatedAt = repository.updatedAt {
                    Text("更新: \(updatedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Repository Browser
struct RepositoryBrowserView: View {
    @EnvironmentObject var appState: AppState
    let repository: GitHubRepository

    @StateObject private var viewModel = RepositoryBrowserViewModel()
    @State private var showCreateFile = false
    @State private var selectedBranch: String = ""

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else {
                fileList
            }
        }
        .navigationTitle(repository.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    branchPicker
                    Button {
                        showCreateFile = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateFile) {
            FileCreatorView(
                repository: repository,
                currentPath: viewModel.currentPath,
                currentBranch: selectedBranch.isEmpty ? repository.defaultBranch : selectedBranch
            )
            .environmentObject(appState)
        }
        .task {
            selectedBranch = repository.defaultBranch
            await viewModel.loadContents(
                repository: repository,
                service: appState.gitHubService
            )
        }
    }

    private var fileList: some View {
        List {
            // パンくずナビゲーション
            if !viewModel.pathStack.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Button {
                            viewModel.navigateToRoot(repository: repository, service: appState.gitHubService)
                        } label: {
                            Text(repository.name)
                                .font(.caption)
                        }
                        ForEach(viewModel.pathStack.indices, id: \.self) { i in
                            Text("/")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button {
                                viewModel.navigateTo(index: i, repository: repository, service: appState.gitHubService)
                            } label: {
                                Text(viewModel.pathStack[i])
                                    .font(.caption)
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            // ファイル/ディレクトリ一覧
            ForEach(viewModel.contents) { content in
                if content.isDirectory {
                    Button {
                        viewModel.navigateInto(
                            content: content,
                            repository: repository,
                            service: appState.gitHubService
                        )
                    } label: {
                        ContentRow(content: content)
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink {
                        FileEditorView(
                            content: content,
                            repository: repository,
                            branch: selectedBranch.isEmpty ? repository.defaultBranch : selectedBranch
                        )
                        .environmentObject(appState)
                    } label: {
                        ContentRow(content: content)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var branchPicker: some View {
        Menu {
            ForEach(viewModel.branches) { branch in
                Button {
                    selectedBranch = branch.name
                    Task {
                        await viewModel.loadContents(
                            repository: repository,
                            branch: branch.name,
                            service: appState.gitHubService
                        )
                    }
                } label: {
                    Label(branch.name, systemImage: selectedBranch == branch.name ? "checkmark" : "")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                Text(selectedBranch.isEmpty ? repository.defaultBranch : selectedBranch)
                    .font(.caption)
            }
        }
        .task {
            await viewModel.loadBranches(repository: repository, service: appState.gitHubService)
        }
    }
}

// MARK: - Content Row
struct ContentRow: View {
    let content: GitHubContent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: content.systemIcon)
                .foregroundColor(content.isDirectory ? .accentColor : .secondary)
                .frame(width: 20)

            Text(content.name)
                .lineLimit(1)

            Spacer()

            if !content.isDirectory {
                Text(ByteCountFormatter.string(fromByteCount: Int64(content.size), countStyle: .file))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - File Editor View
struct FileEditorView: View {
    @EnvironmentObject var appState: AppState
    let content: GitHubContent
    let repository: GitHubRepository
    let branch: String

    @State private var fileContent = ""
    @State private var originalContent = ""
    @State private var fileSHA = ""
    @State private var isLoading = true
    @State private var showCommitDialog = false
    @State private var commitMessage = ""
    @State private var isSaving = false
    @State private var showAIActions = false

    var hasChanges: Bool { fileContent != originalContent }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                VStack(spacing: 0) {
                    // ファイル情報バー
                    fileInfoBar

                    // コードエディタ
                    TextEditor(text: $fileContent)
                        .font(.system(.caption, design: .monospaced))
                        .padding(4)
                }
            }
        }
        .navigationTitle(content.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // AI操作ボタン
                    Button {
                        showAIActions = true
                    } label: {
                        Image(systemName: "wand.and.sparkles")
                    }

                    // 保存ボタン
                    if hasChanges {
                        Button {
                            commitMessage = "Update \(content.name)"
                            showCommitDialog = true
                        } label: {
                            Text("保存")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .confirmationDialog("コミットメッセージ", isPresented: $showCommitDialog, titleVisibility: .visible) {
            Button("コミット・保存") {
                saveFile()
            }
        } message: {
            Text("変更を'\(branch)'ブランチにコミットします")
        }
        .sheet(isPresented: $showAIActions) {
            AIFileActionsView(
                filename: content.name,
                language: content.languageFromExtension,
                fileContent: $fileContent
            )
        }
        .task {
            await loadFile()
        }
    }

    private var fileInfoBar: some View {
        HStack {
            Text(content.languageFromExtension)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .cornerRadius(4)

            Spacer()

            Text("Branch: \(branch)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    private func loadFile() async {
        isLoading = true
        do {
            let fileData = try await appState.gitHubService.fetchFileContent(
                owner: repository.owner.login,
                repo: repository.name,
                path: content.path,
                branch: branch
            )
            fileContent = fileData.decodedContent ?? ""
            originalContent = fileContent
            fileSHA = fileData.sha
        } catch {
            fileContent = "// ファイルの読み込みに失敗しました: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func saveFile() {
        isSaving = true
        Task {
            do {
                _ = try await appState.gitHubService.createOrUpdateFile(
                    owner: repository.owner.login,
                    repo: repository.name,
                    path: content.path,
                    content: fileContent,
                    message: commitMessage.isEmpty ? "Update \(content.name)" : commitMessage,
                    branch: branch,
                    sha: fileSHA
                )
                originalContent = fileContent
            } catch {
                // エラー処理
            }
            isSaving = false
        }
    }
}

// MARK: - AI File Actions
struct AIFileActionsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let filename: String
    let language: String
    @Binding var fileContent: String

    @State private var isProcessing = false
    @State private var result = ""
    @State private var selectedAction: AIFileAction? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // アクション選択
                List(AIFileAction.allCases, id: \.self) { action in
                    Button {
                        selectedAction = action
                        Task { await performAction(action) }
                    } label: {
                        HStack {
                            Image(systemName: action.icon)
                                .frame(width: 24)
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading) {
                                Text(action.displayName)
                                    .font(.body)
                                Text(action.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .frame(maxHeight: 250)

                Divider()

                // 結果表示
                if isProcessing {
                    ProgressView("処理中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !result.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(selectedAction?.displayName ?? "結果")
                                .font(.headline)
                            Spacer()
                            if selectedAction?.appliesChanges == true {
                                Button("コードに適用") {
                                    fileContent = extractCode(from: result)
                                    dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                        .padding(.horizontal)

                        ScrollView {
                            Text(result)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("AIアシスタント")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func performAction(_ action: AIFileAction) async {
        isProcessing = true
        result = ""

        do {
            let llmService = LLMService(privacyConfig: .shared)
            let prompt = action.buildPrompt(code: fileContent, language: language, filename: filename)
            let messages = [ChatMessage(role: .user, content: prompt)]
            var fullResult = ""

            for try await chunk in await llmService.sendMessageStream(
                messages: messages,
                systemPrompt: action.systemPrompt
            ) {
                fullResult += chunk
            }
            result = fullResult
        } catch {
            result = "エラー: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    private func extractCode(from text: String) -> String {
        let pattern = "```(?:\\w+)?\\n([\\s\\S]+?)\\n```"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return text
    }
}

enum AIFileAction: CaseIterable {
    case explain
    case review
    case refactor
    case addTests
    case addComments

    var displayName: String {
        switch self {
        case .explain: return "コードを説明"
        case .review: return "コードレビュー"
        case .refactor: return "リファクタリング"
        case .addTests: return "テストを追加"
        case .addComments: return "コメントを追加"
        }
    }

    var description: String {
        switch self {
        case .explain: return "このファイルの目的と処理を説明します"
        case .review: return "問題点と改善案を指摘します"
        case .refactor: return "コードの品質を改善します"
        case .addTests: return "ユニットテストを生成します"
        case .addComments: return "ドキュメントコメントを追加します"
        }
    }

    var icon: String {
        switch self {
        case .explain: return "doc.text.magnifyingglass"
        case .review: return "checkmark.seal"
        case .refactor: return "arrow.triangle.2.circlepath"
        case .addTests: return "checkmark.circle"
        case .addComments: return "text.bubble"
        }
    }

    var appliesChanges: Bool {
        switch self {
        case .explain, .review: return false
        case .refactor, .addTests, .addComments: return true
        }
    }

    var systemPrompt: String {
        switch self {
        case .explain: return ClaudePrompts.codeExplanation
        case .review: return ClaudePrompts.codeReview
        case .refactor, .addTests, .addComments: return ClaudePrompts.codeGeneration
        }
    }

    func buildPrompt(code: String, language: String, filename: String) -> String {
        switch self {
        case .explain:
            return "ファイル名: \(filename)\n\n```\(language)\n\(code)\n```\n\nこのコードを詳しく説明してください。"
        case .review:
            return "```\(language)\n\(code)\n```\n\nこの\(language)コードをレビューし、問題点と改善案を指摘してください。"
        case .refactor:
            return "```\(language)\n\(code)\n```\n\nこの\(language)コードをリファクタリングしてください。クリーンで読みやすく、効率的なコードにしてください。"
        case .addTests:
            return "```\(language)\n\(code)\n```\n\nこの\(language)コードに対するユニットテストを書いてください。"
        case .addComments:
            return "```\(language)\n\(code)\n```\n\nこの\(language)コードにドキュメントコメントと必要なインラインコメントを追加してください。"
        }
    }
}

// MARK: - File Creator View
struct FileCreatorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let repository: GitHubRepository
    let currentPath: String
    let currentBranch: String

    @State private var request = FileCreateRequest()
    @State private var isCreating = false
    @State private var showGenerateWithAI = false
    @State private var aiPrompt = ""
    @State private var isGenerating = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("ファイル情報") {
                    TextField("ファイル名 (例: main.swift)", text: $request.filename)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    TextField("保存先パス (例: src/utils/)", text: $request.targetPath)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if !currentPath.isEmpty {
                        Text("現在のディレクトリ: \(currentPath)/")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            .onTapGesture {
                                request.targetPath = currentPath
                            }
                    }
                }

                Section {
                    TextField("コミットメッセージ", text: $request.commitMessage)
                        .autocorrectionDisabled()
                } header: {
                    Text("コミット情報")
                } footer: {
                    Text("ブランチ: \(currentBranch)")
                        .font(.caption)
                }

                Section {
                    // AIで生成
                    Button {
                        showGenerateWithAI = true
                    } label: {
                        HStack {
                            Image(systemName: "wand.and.sparkles")
                                .foregroundColor(.accentColor)
                            Text("AIでコードを生成")
                        }
                    }

                    if isGenerating {
                        HStack {
                            ProgressView()
                            Text("生成中...")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("コンテンツ")
                }

                Section {
                    TextEditor(text: $request.content)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("新規ファイル作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") {
                        createFile()
                    }
                    .disabled(!request.isValid || isCreating)
                    .bold()
                }
            }
            .alert("エラー", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .sheet(isPresented: $showGenerateWithAI) {
            AICodeGeneratorView(prompt: $aiPrompt, result: $request.content) { prompt in
                generateWithAI(prompt: prompt)
            }
        }
    }

    private func createFile() {
        isCreating = true
        Task {
            do {
                _ = try await appState.gitHubService.createOrUpdateFile(
                    owner: repository.owner.login,
                    repo: repository.name,
                    path: request.fullPath,
                    content: request.content,
                    message: request.commitMessage,
                    branch: currentBranch
                )
                dismiss()
            } catch {
                errorMessage = "ファイルの作成に失敗しました: \(error.localizedDescription)"
            }
            isCreating = false
        }
    }

    private func generateWithAI(prompt: String) {
        isGenerating = true
        showGenerateWithAI = false
        Task {
            do {
                let llmService = LLMService(privacyConfig: .shared)
                let language = detectLanguage(from: request.filename)
                let userMessage = ChatMessage(role: .user, content: "\(language)で\(prompt)")
                var fullCode = ""

                for try await chunk in await llmService.sendMessageStream(
                    messages: [userMessage],
                    systemPrompt: ClaudePrompts.codeGeneration
                ) {
                    fullCode += chunk
                }

                // コードブロックを抽出
                request.content = extractCode(from: fullCode)
                if request.commitMessage.isEmpty {
                    request.commitMessage = "Add \(request.filename)"
                }
            } catch {
                errorMessage = "コードの生成に失敗しました: \(error.localizedDescription)"
            }
            isGenerating = false
        }
    }

    private func detectLanguage(from filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "Swift"
        case "kt": return "Kotlin"
        case "py": return "Python"
        case "js": return "JavaScript"
        case "ts": return "TypeScript"
        case "go": return "Go"
        case "rs": return "Rust"
        default: return ext.isEmpty ? "コード" : ext.uppercased()
        }
    }

    private func extractCode(from text: String) -> String {
        let pattern = "```(?:\\w+)?\\n([\\s\\S]+?)\\n```"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return text
    }
}

// MARK: - AI Code Generator View
struct AICodeGeneratorView: View {
    @Binding var prompt: String
    @Binding var result: String
    let onGenerate: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("生成したいコードの説明...", text: $prompt, axis: .vertical)
                    .lineLimit(3...6)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                Text("例: \"ユーザー認録フォームのバリデーション\", \"ファイル読み書きのユーティリティ\"")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("AIでコードを生成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("生成") {
                        onGenerate(prompt)
                        dismiss()
                    }
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .bold()
                }
            }
        }
    }
}

// MARK: - GitHub View Model
@MainActor
class GitHubViewModel: ObservableObject {
    @Published var repositories: [GitHubRepository] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var currentPage = 1
    @Published var hasMoreRepositories = false

    var filteredRepositories: [GitHubRepository] {
        if searchText.isEmpty { return repositories }
        return repositories.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    func loadRepositories(service: GitHubService) async {
        isLoading = true
        currentPage = 1
        do {
            repositories = try await service.fetchRepositories(page: 1, perPage: 30)
            hasMoreRepositories = repositories.count == 30
        } catch {
            // エラー処理
        }
        isLoading = false
    }

    func loadMoreRepositories(service: GitHubService) async {
        currentPage += 1
        do {
            let more = try await service.fetchRepositories(page: currentPage, perPage: 30)
            repositories.append(contentsOf: more)
            hasMoreRepositories = more.count == 30
        } catch {
            currentPage -= 1
        }
    }
}

// MARK: - Repository Browser View Model
@MainActor
class RepositoryBrowserViewModel: ObservableObject {
    @Published var contents: [GitHubContent] = []
    @Published var branches: [GitHubBranch] = []
    @Published var isLoading = false
    @Published var currentPath = ""
    @Published var pathStack: [String] = []

    func loadContents(repository: GitHubRepository, branch: String? = nil, service: GitHubService) async {
        isLoading = true
        do {
            contents = try await service.fetchContents(
                owner: repository.owner.login,
                repo: repository.name,
                path: currentPath,
                branch: branch
            )
            .sorted { a, b in
                if a.isDirectory != b.isDirectory {
                    return a.isDirectory
                }
                return a.name < b.name
            }
        } catch {
            // エラー処理
        }
        isLoading = false
    }

    func loadBranches(repository: GitHubRepository, service: GitHubService) async {
        do {
            branches = try await service.fetchBranches(
                owner: repository.owner.login,
                repo: repository.name
            )
        } catch {
            // エラー処理
        }
    }

    func navigateInto(content: GitHubContent, repository: GitHubRepository, service: GitHubService) {
        pathStack.append(content.name)
        currentPath = pathStack.joined(separator: "/")
        Task {
            await loadContents(repository: repository, service: service)
        }
    }

    func navigateToRoot(repository: GitHubRepository, service: GitHubService) {
        pathStack = []
        currentPath = ""
        Task {
            await loadContents(repository: repository, service: service)
        }
    }

    func navigateTo(index: Int, repository: GitHubRepository, service: GitHubService) {
        pathStack = Array(pathStack.prefix(index + 1))
        currentPath = pathStack.joined(separator: "/")
        Task {
            await loadContents(repository: repository, service: service)
        }
    }
}

// MARK: - GitHubService Extension
extension GitHubService {
    nonisolated func buildOAuthURLSync() -> URL? {
        var components = URLComponents(string: "https://github.com/login/oauth/authorize")
        let clientID = Bundle.main.infoDictionary?["GITHUB_CLIENT_ID"] as? String ?? ""
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "scope", value: "repo,user"),
            URLQueryItem(name: "redirect_uri", value: "claudecodeapp://oauth/callback")
        ]
        return components?.url
    }
}
