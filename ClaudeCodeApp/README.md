# Claude Code - iPhone App

Claude Code風のiPhoneアプリです。AIを使ったコード支援とGitHubリポジトリ連携機能を提供します。

## 機能

### AIコード支援
- **チャット**: Claude / ローカルLLMとの自然なコード相談
- **コード生成**: 説明からコードを自動生成
- **コード説明**: コードの動作を日本語で解説
- **コードレビュー**: 問題点・改善案を指摘
- **バグ修正**: エラー内容からバグを特定・修正
- **ストリーミング**: リアルタイムで回答を表示

### GitHub連携
- GitHub / GitHub Enterprise / Gitea / GitLab 対応
- リポジトリの閲覧・検索
- ファイル・ディレクトリのブラウズ
- **ファイルの新規作成**（AIコード生成 → そのままコミット）
- ファイルの編集・コミット
- ブランチ切り替え

### プライバシー・セキュリティ

```
外部送信なし ← Ollama/ローカルLLM + GitHub Enterprise/Gitea
最小限送信   ← Claude API + GitHub Enterprise/Gitea
標準        ← Claude API + GitHub.com
```

| 機能 | 詳細 |
|------|------|
| ローカルLLM | Ollamaで完全オフライン処理 |
| プライベートVCS | GitHub Enterprise / Gitea / GitLabに対応 |
| AES-256-GCM暗号化 | 会話履歴をデバイス内で暗号化保存 |
| Keychain保存 | APIキー・トークンはKeychainに安全保存 |
| 自己署名証明書対応 | プライベートサーバーのHTTPS対応 |
| プロキシ設定 | 社内ネットワーク対応 |

---

## セットアップ

### 必要な環境
- Xcode 15.0以上
- iOS 17.0以上のデバイスまたはシミュレーター
- Apple Developer アカウント（実機ビルド時）

### 1. プロジェクトを開く

```bash
open ClaudeCodeApp.xcodeproj
```

### 2. GitHub OAuth App の設定

> GitHub.comを使用しない場合（GitHub Enterprise / Gitea等）はスキップ可

1. [GitHub Developer Settings](https://github.com/settings/developers) → **New OAuth App**
2. 以下を設定:
   - **Homepage URL**: `https://your-app.com`
   - **Authorization callback URL**: `claudecodeapp://oauth/callback`
3. Client ID と Client Secret を取得

**Xcodeでの設定:**
1. Xcode → プロジェクト設定 → Build Settings
2. User-Defined に追加:
   - `GITHUB_CLIENT_ID` = `your_client_id`
   - `GITHUB_CLIENT_SECRET` = `your_client_secret`

> ⚠️ Client Secretはコードにハードコードしないでください。
> 本番環境では認証フローをサーバーサイドで処理することを推奨します。

### 3. ビルド・実行

Xcodeでターゲットデバイスを選択して実行（`Cmd + R`）

---

## 使い方

### パターン1: 完全プライベートモード（推奨）

外部にデータを送信しない完全クローズな環境:

1. **設定** → **AIモデル設定** → **Ollama（ローカル）** を選択
2. MacでOllamaを起動:
   ```bash
   # Ollamaのインストール (初回のみ)
   brew install ollama

   # モデルのダウンロード (例: llama3.2, codestral等)
   ollama pull llama3.2
   # または コード特化モデル
   ollama pull codestral

   # サーバー起動
   ollama serve
   ```
3. iPhoneと同じWi-Fiネットワークに接続
4. エンドポイントURLをMacのIPアドレスに変更:
   `http://192.168.x.x:11434`

5. **VCS設定** → **GitHub Enterprise / Gitea** を選択（社内サーバー使用時）

### パターン2: Claude API + プライベートVCS

AIはAnthropicのClaudeを使用し、コードは社内サーバーで管理:

1. **設定** → **AIモデル設定** → **Claude API** を選択
2. **Claude APIキー** を入力（Anthropic Consoleから取得）
3. **VCS設定** → 社内のGitHub Enterprise / Gitea等を設定
4. **アクセストークン** を入力

### パターン3: フル外部サービス利用

1. **設定** → **AIモデル設定** → **Claude API** を選択
2. **Claude APIキー** を入力
3. **GitHubでログイン** でOAuth認証

---

## プロジェクト構成

```
ClaudeCodeApp/
├── App/
│   ├── ClaudeCodeApp.swift      # アプリエントリーポイント
│   └── AppState.swift           # アプリ全体の状態管理
├── Views/
│   ├── ContentView.swift        # タブバーナビゲーション
│   ├── ChatView.swift           # チャット画面 + コードエディタ
│   ├── GitHubView.swift         # GitHub連携画面 (リポジトリブラウザ等)
│   └── SettingsView.swift       # 設定画面 (プライバシー設定含む)
├── Models/
│   ├── ChatMessage.swift        # チャットメッセージ + 暗号化ストレージ
│   └── GitHubModels.swift       # GitHubデータモデル
├── Services/
│   ├── ClaudeService.swift      # Claude API クライアント
│   ├── GitHubService.swift      # GitHub/GitLab/Gitea API クライアント
│   ├── KeychainService.swift    # Keychain操作
│   └── LLMService.swift         # LLM統合サービス (Claude/Ollama/OpenAI互換)
├── Configuration/
│   ├── PrivacyConfig.swift      # プライバシー・セキュリティ設定
│   └── Config.swift             # アプリ定数
└── Resources/
    └── Info.plist               # アプリ設定・パーミッション
```

---

## セキュリティ設計

### データ保護の仕組み

```
[ユーザー入力]
     ↓
[LLMService]
     ├── Claude API (オプション) → Anthropicサーバー
     ├── Ollama            → ローカル/社内ネットワークのみ
     └── OpenAI互換        → 自社サーバーのみ
     ↓
[会話履歴]
     ├── AES-256-GCM暗号化 (オプション)
     ├── iOS ファイル保護 (.completeFileProtection)
     └── KeychainにAES鍵を保存
```

### APIキー・トークンの保護
- すべての認証情報はiOS **Keychain** に保存
- メモリ上のみで処理し、ログには記録しない
- クリップボード自動クリア（設定でON可能）

### ネットワーク設定
- HTTPSデフォルト
- プライベートサーバー向けに自己署名証明書対応（要設定）
- 社内プロキシ設定対応
- ローカルネットワーク（Ollama）向けにHTTP許可

---

## 対応バックエンド

### LLM
| バックエンド | データ送信先 | オフライン |
|------------|------------|---------|
| Claude API | Anthropicサーバー | ✗ |
| Ollama | ローカル/LAN | ✓ |
| OpenAI互換 | 自社サーバー | 設定次第 |

### VCS / リポジトリ
| バックエンド | データ保存先 |
|------------|------------|
| GitHub.com | GitHubサーバー |
| GitHub Enterprise | 社内サーバー |
| Gitea | 社内サーバー |
| GitLab (セルフホスト) | 社内サーバー |

---

## ライセンス

MIT License
