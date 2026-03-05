import SwiftUI

// MARK: - Onboarding (初回セットアップ)
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var profileManager = ProfileManager.shared
    @State private var currentStep = 0

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // プログレスバー
                StepProgressBar(currentStep: currentStep, totalSteps: 4)
                    .padding()

                // ステップコンテンツ
                TabView(selection: $currentStep) {
                    WelcomeStepView(onNext: { currentStep = 1 })
                        .tag(0)
                    APIKeyStepView(onNext: { currentStep = 2 }, onSkip: { currentStep = 2 })
                        .tag(1)
                    CreateProfileStepView(onNext: { currentStep = 3 })
                        .tag(2)
                    GitHubStepView(onFinish: { appState.completeOnboarding() })
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
            }
        }
    }
}

// MARK: - Progress Bar
struct StepProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .frame(height: 4)
                    .foregroundColor(i <= currentStep ? .accentColor : Color(.systemGray4))
                    .animation(.easeInOut, value: currentStep)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Step 1: ようこそ
struct WelcomeStepView: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // ロゴ・タイトル
            VStack(spacing: 16) {
                Text("🤖")
                    .font(.system(size: 80))

                Text("AI おしゃべり帳")
                    .font(.largeTitle.bold())

                Text("家族みんなで使える\nAIアシスタントアプリです")
                    .multilineTextAlignment(.center)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            // 特徴カード
            VStack(spacing: 12) {
                FeatureCard(emoji: "💬", title: "何でも聞けます",
                            desc: "料理レシピ、旅行プラン、勉強の質問…なんでもOK！")
                FeatureCard(emoji: "👨‍👩‍👧‍👦", title: "家族で使えます",
                            desc: "お父さん・お母さん・子ども、それぞれの設定で使えます")
                FeatureCard(emoji: "📝", title: "大事な話は保存できます",
                            desc: "気に入った回答をGitHubに保存しておけます（任意）")
            }
            .padding(.horizontal)

            Spacer()

            Button {
                onNext()
            } label: {
                Text("はじめる  →")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .padding(.horizontal, 32)
            }

            Spacer().frame(height: 20)
        }
    }
}

struct FeatureCard: View {
    let emoji: String
    let title: String
    let desc: String

    var body: some View {
        HStack(spacing: 16) {
            Text(emoji)
                .font(.title2)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
}

// MARK: - Step 2: APIキー設定
struct APIKeyStepView: View {
    @EnvironmentObject var appState: AppState
    let onNext: () -> Void
    let onSkip: () -> Void

    @State private var apiKey = ""
    @State private var showKey = false
    @State private var showHelp = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // ヘッダー
                VStack(spacing: 12) {
                    Text("🔑")
                        .font(.system(size: 60))
                    Text("AI を使うための\nキーを入力してください")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text("AIと話すために「Claude APIキー」が必要です。\n取得方法は下のボタンで確認できます。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                // 入力フォーム
                VStack(alignment: .leading, spacing: 8) {
                    Text("APIキー")
                        .font(.headline)
                        .padding(.horizontal)

                    HStack {
                        Group {
                            if showKey {
                                TextField("sk-ant-から始まるキー", text: $apiKey)
                            } else {
                                SecureField("sk-ant-から始まるキー", text: $apiKey)
                            }
                        }
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.body.monospaced())

                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    Text("💡 入力したキーはこのデバイスにのみ保存され、他には送られません")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }

                // APIキー取得ボタン
                Button {
                    showHelp = true
                } label: {
                    HStack {
                        Image(systemName: "questionmark.circle")
                        Text("APIキーの取得方法を見る")
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                }

                Spacer()

                // ボタン
                VStack(spacing: 12) {
                    Button {
                        if !apiKey.isEmpty {
                            appState.saveClaudeAPIKey(apiKey)
                        }
                        onNext()
                    } label: {
                        Text(apiKey.isEmpty ? "あとで設定する" : "設定して次へ  →")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(apiKey.isEmpty ? Color(.systemGray4) : Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .padding(.horizontal, 32)
                    }

                    if apiKey.isEmpty {
                        Text("あとで設定からいつでも変更できます")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showHelp) {
            APIKeyHelpView()
        }
    }
}

// MARK: - APIキー取得ガイド
struct APIKeyHelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("APIキーの取得方法")
                        .font(.title2.bold())
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 16) {
                        StepGuide(step: 1,
                                  title: "Anthropicのサイトを開く",
                                  desc: "ブラウザで console.anthropic.com を開いてください",
                                  icon: "safari")
                        StepGuide(step: 2,
                                  title: "アカウントを作る",
                                  desc: "まだアカウントがない場合は「Sign up」でメール登録します（無料）",
                                  icon: "person.badge.plus")
                        StepGuide(step: 3,
                                  title: "「API Keys」を選ぶ",
                                  desc: "左メニューの「API Keys」をタップします",
                                  icon: "key")
                        StepGuide(step: 4,
                                  title: "「Create Key」をタップ",
                                  desc: "新しいキーを作ります。名前は「iPhone」などわかりやすい名前でOK",
                                  icon: "plus.circle")
                        StepGuide(step: 5,
                                  title: "キーをコピーしてアプリに貼り付ける",
                                  desc: "「sk-ant-...」から始まる文字列をコピーして、アプリに戻って貼り付けてください",
                                  icon: "doc.on.clipboard")
                    }
                    .padding(.horizontal)

                    // 料金についての説明
                    VStack(alignment: .leading, spacing: 8) {
                        Label("料金について", systemImage: "creditcard")
                            .font(.headline)
                        Text("APIは使った分だけ料金がかかります。普通に使う場合、月に数百円程度が目安です。使いすぎが心配な場合は、コンソールで上限額を設定できます。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

struct StepGuide: View {
    let step: Int
    let title: String
    let desc: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 32, height: 32)
                Text("\(step)")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Step 3: プロフィール作成
struct CreateProfileStepView: View {
    @StateObject private var profileManager = ProfileManager.shared
    let onNext: () -> Void

    @State private var name = ""
    @State private var selectedEmoji = "😊"
    @State private var selectedRole: FamilyRole = .adult
    @State private var selectedColor = "#4A90D9"

    let presetColors = ["#4A90D9", "#E74C3C", "#2ECC71", "#F39C12", "#9B59B6", "#1ABC9C"]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // ヘッダー
                VStack(spacing: 12) {
                    Text("👤")
                        .font(.system(size: 60))
                    Text("あなたのプロフィールを\n作りましょう")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text("家族それぞれのプロフィールを作ると\nみんなで使いやすくなります")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                // プレビュー
                ZStack {
                    Circle()
                        .fill(Color(hex: selectedColor) ?? .blue)
                        .frame(width: 80, height: 80)
                    Text(selectedEmoji)
                        .font(.system(size: 40))
                }

                // 名前入力
                VStack(alignment: .leading, spacing: 8) {
                    Text("名前")
                        .font(.headline)
                        .padding(.horizontal)
                    TextField("例：お父さん、太郎など", text: $name)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                // 誰が使う？
                VStack(alignment: .leading, spacing: 12) {
                    Text("誰が使いますか？")
                        .font(.headline)
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        ForEach(FamilyRole.allCases, id: \.self) { role in
                            Button {
                                selectedRole = role
                                selectedEmoji = role.defaultEmojis.first ?? "😊"
                            } label: {
                                Text(role.displayName)
                                    .font(.body)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(selectedRole == role ? Color.accentColor : Color(.systemGray5))
                                    .foregroundColor(selectedRole == role ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // 絵文字選択
                VStack(alignment: .leading, spacing: 12) {
                    Text("アイコン")
                        .font(.headline)
                        .padding(.horizontal)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(selectedRole.defaultEmojis, id: \.self) { emoji in
                            Button {
                                selectedEmoji = emoji
                            } label: {
                                Text(emoji)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(selectedEmoji == emoji ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // カラー選択
                VStack(alignment: .leading, spacing: 12) {
                    Text("カラー")
                        .font(.headline)
                        .padding(.horizontal)

                    HStack(spacing: 16) {
                        ForEach(presetColors, id: \.self) { hex in
                            Button {
                                selectedColor = hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: hex) ?? .blue)
                                        .frame(width: 36, height: 36)
                                    if selectedColor == hex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Button {
                    let profile = FamilyProfile(
                        name: name.isEmpty ? "私" : name,
                        iconEmoji: selectedEmoji,
                        colorHex: selectedColor,
                        role: selectedRole
                    )
                    profileManager.addProfile(profile)
                    onNext()
                } label: {
                    Text("作成して次へ  →")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Step 4: GitHub保存の設定（任意）
struct GitHubStepView: View {
    @EnvironmentObject var appState: AppState
    let onFinish: () -> Void

    @State private var token = ""
    @State private var showKey = false
    @State private var showHelp = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // ヘッダー
                VStack(spacing: 12) {
                    Text("📁")
                        .font(.system(size: 60))
                    Text("会話を保存する場所を\n設定しましょう（任意）")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    // スキップ可能であることを強調
                    Text("この設定はあとでもできます。\nスキップしてもアプリはすぐ使えます！")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                .padding(.top, 24)

                // GitHubとは？
                VStack(alignment: .leading, spacing: 12) {
                    Text("GitHubって何？")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("無料で使えるファイル保存サービスです")
                        BulletPoint("AIとの大事な会話をいつでも見返せます")
                        BulletPoint("スマホを変えてもデータが残ります")
                    }
                    .padding(.horizontal)
                }

                // トークン入力
                VStack(alignment: .leading, spacing: 8) {
                    Text("GitHubのトークン（パスワード的なもの）")
                        .font(.headline)
                        .padding(.horizontal)

                    HStack {
                        Group {
                            if showKey {
                                TextField("ghp_から始まるトークン", text: $token)
                            } else {
                                SecureField("ghp_から始まるトークン", text: $token)
                            }
                        }
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                        Button { showKey.toggle() } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    Button {
                        showHelp = true
                    } label: {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("トークンの取得方法を見る")
                        }
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal)
                    }
                }

                Spacer()

                // ボタン
                VStack(spacing: 12) {
                    if !token.isEmpty {
                        Button {
                            appState.saveGitHubToken(token)
                            onFinish()
                        } label: {
                            Text("設定して始める  →")
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .padding(.horizontal, 32)
                        }
                    }

                    Button {
                        onFinish()
                    } label: {
                        Text(token.isEmpty ? "スキップしてアプリを始める  →" : "スキップする")
                            .font(token.isEmpty ? .title3.bold() : .subheadline)
                            .frame(maxWidth: token.isEmpty ? .infinity : nil)
                            .padding(.vertical, token.isEmpty ? 18 : 10)
                            .padding(.horizontal, token.isEmpty ? 0 : 20)
                            .background(token.isEmpty ? Color.accentColor : Color(.systemGray5))
                            .foregroundColor(token.isEmpty ? .white : .secondary)
                            .cornerRadius(token.isEmpty ? 16 : 20)
                            .padding(.horizontal, token.isEmpty ? 32 : 0)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showHelp) {
            GitHubTokenHelpView()
        }
    }
}

// MARK: - GitHub Token Help
struct GitHubTokenHelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("GitHubトークンの取得方法")
                        .font(.title2.bold())
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 16) {
                        StepGuide(step: 1,
                                  title: "github.com にアクセス",
                                  desc: "まずGitHubのアカウントを作ります（無料・メール登録だけでOK）",
                                  icon: "globe")
                        StepGuide(step: 2,
                                  title: "右上のアイコンをタップ",
                                  desc: "「Settings（設定）」を選びます",
                                  icon: "gearshape")
                        StepGuide(step: 3,
                                  title: "「Developer settings」を探す",
                                  desc: "左メニューの一番下にあります",
                                  icon: "chevron.left.forwardslash.chevron.right")
                        StepGuide(step: 4,
                                  title: "「Personal access tokens」→「Tokens (classic)」",
                                  desc: "「Generate new token (classic)」をタップ",
                                  icon: "key")
                        StepGuide(step: 5,
                                  title: "設定をして「Generate token」",
                                  desc: "Noteに「iPhone」と入力、「repo」にチェックを入れて作成",
                                  icon: "checkmark.circle")
                        StepGuide(step: 6,
                                  title: "「ghp_...」をコピーして貼り付け",
                                  desc: "表示されたトークンをコピーしてアプリに貼り付けます（一度しか表示されないので注意！）",
                                  icon: "doc.on.clipboard")
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Bullet Point Helper
struct BulletPoint: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("✓")
                .foregroundColor(.green)
                .fontWeight(.bold)
            Text(text)
                .font(.subheadline)
        }
    }
}
