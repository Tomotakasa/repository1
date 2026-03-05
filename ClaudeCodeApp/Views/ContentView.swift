import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else {
                mainTabView
            }
        }
        .alert("エラー", isPresented: .init(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK") { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }

    // MARK: - Main Tab View
    private var mainTabView: some View {
        TabView(selection: $appState.selectedTab) {

            // 💬 チャット
            NavigationStack { ChatView() }
                .tabItem { Label(AppTab.chat.title, systemImage: AppTab.chat.icon) }
                .tag(AppTab.chat)

            // 📚 資料ライブラリ
            NavigationStack { DocumentLibraryView() }
                .tabItem { Label(AppTab.library.title, systemImage: AppTab.library.icon) }
                .tag(AppTab.library)

            // 🧠 記憶
            NavigationStack { MemoryView() }
                .tabItem { Label(AppTab.memory.title, systemImage: AppTab.memory.icon) }
                .tag(AppTab.memory)

            // 📁 GitHub保存
            NavigationStack { GitHubSaveView() }
                .tabItem { Label(AppTab.save.title, systemImage: AppTab.save.icon) }
                .tag(AppTab.save)

            // ⚙️ 設定
            NavigationStack { SettingsView() }
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.icon) }
                .tag(AppTab.settings)
        }
    }
}

// MARK: - GitHub Save View (シンプル保存画面)
struct GitHubSaveView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = GitHubSaveViewModel()

    var body: some View {
        Group {
            if appState.isGitHubAuthenticated {
                authenticatedView
            } else {
                notConnectedView
            }
        }
        .navigationTitle("📁 保存する")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if appState.isGitHubAuthenticated {
                await viewModel.load(service: appState.gitHubService)
            }
        }
    }

    // MARK: - Not Connected
    private var notConnectedView: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("📁").font(.system(size: 70))
            Text("会話を保存しよう").font(.title2.bold())
            Text("GitHubと連携すると、AIとの大切な会話や\nメモをクラウドに保存できます。\n機種変更しても残ります！")
                .multilineTextAlignment(.center).foregroundColor(.secondary)
            NavigationLink {
                SettingsView()
            } label: {
                Label("設定からGitHubを連携する", systemImage: "arrow.right.circle.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding()
                    .background(Color.accentColor).foregroundColor(.white)
                    .cornerRadius(14).padding(.horizontal, 32)
            }
            Spacer()
        }
    }

    // MARK: - Authenticated
    private var authenticatedView: some View {
        VStack(spacing: 0) {
            if let user = appState.gitHubUser {
                HStack(spacing: 10) {
                    AsyncImage(url: URL(string: user.avatarUrl)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.circle.fill").foregroundColor(.secondary)
                    }
                    .frame(width: 32, height: 32).clipShape(Circle())
                    Text("@\(user.login)").font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                }
                .padding().background(Color(.systemGray6))
            }

            List {
                Section("今すぐ保存") {
                    Button { viewModel.showQuickSave = true } label: {
                        Label("会話・メモを保存", systemImage: "square.and.arrow.down")
                            .foregroundColor(.accentColor)
                    }
                }
                Section("保存先リポジトリ") {
                    if viewModel.isLoading {
                        HStack { ProgressView(); Text("読み込み中...").foregroundColor(.secondary) }
                    } else {
                        ForEach(viewModel.repositories) { repo in
                            NavigationLink {
                                RepositoryBrowserView(repository: repo).environmentObject(appState)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: repo.isPrivate ? "lock.fill" : "doc.fill")
                                        .foregroundColor(repo.isPrivate ? .orange : .blue)
                                    VStack(alignment: .leading) {
                                        Text(repo.name).font(.subheadline.bold())
                                        if let desc = repo.description {
                                            Text(desc).font(.caption).foregroundColor(.secondary).lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await viewModel.load(service: appState.gitHubService) }
        }
        .sheet(isPresented: $viewModel.showQuickSave) {
            QuickSaveView(service: appState.gitHubService, repos: viewModel.repositories)
        }
    }
}

// MARK: - GitHub Save ViewModel
@MainActor
class GitHubSaveViewModel: ObservableObject {
    @Published var repositories: [GitHubRepository] = []
    @Published var isLoading = false
    @Published var showQuickSave = false

    func load(service: GitHubService) async {
        isLoading = true
        repositories = (try? await service.fetchRepositories(page: 1, perPage: 20)) ?? []
        isLoading = false
    }
}

// MARK: - Quick Save View
struct QuickSaveView: View {
    @Environment(\.dismiss) var dismiss
    let service: GitHubService
    let repos: [GitHubRepository]

    @State private var selectedRepo: GitHubRepository?
    @State private var filename = "memo-\(Date().formatted(.dateTime.year().month().day())).md"
    @State private var content = ""
    @State private var commitMessage = "AIとの会話を保存"
    @State private var isSaving = false
    @State private var savedSuccessfully = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("保存先") {
                    Picker("リポジトリ", selection: $selectedRepo) {
                        Text("選択してください").tag(Optional<GitHubRepository>(nil))
                        ForEach(repos) { repo in
                            Text(repo.name).tag(Optional(repo))
                        }
                    }
                }
                Section("ファイル名") {
                    TextField("ファイル名", text: $filename)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                }
                Section("内容") {
                    TextEditor(text: $content)
                        .frame(minHeight: 150).font(.callout)
                }
                Section("コメント") {
                    TextField("保存コメント", text: $commitMessage)
                }
                if savedSuccessfully {
                    Section {
                        Label("保存しました！", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("会話・メモを保存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中..." : "保存") { save() }
                        .disabled(selectedRepo == nil || content.isEmpty || isSaving)
                        .bold()
                }
            }
            .alert("エラー", isPresented: .init(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func save() {
        guard let repo = selectedRepo else { return }
        isSaving = true
        Task {
            do {
                _ = try await service.createOrUpdateFile(
                    owner: repo.owner.login, repo: repo.name,
                    path: filename, content: content,
                    message: commitMessage, branch: repo.defaultBranch
                )
                savedSuccessfully = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
