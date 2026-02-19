# 町内会班長アプリ

町内会の班長業務をスムーズに行うためのiPhoneアプリです。
React Native (Expo) で開発されており、iPhone・Androidの両方で動作します。

## 主な機能

### 1. ホーム (ダッシュボード)
- 世帯数・回覧中件数・未収金件数の一覧表示
- 未読お知らせの通知
- 直近の行事予定
- クイックアクセスボタン

### 2. 住民名簿
- 世帯主の氏名・ふりがな・住所・電話番号・メールを管理
- 名前・住所での検索機能
- タップ1つで電話・メール送信
- 住民の追加・編集・削除

### 3. 回覧板管理
- 回覧板の作成（タイトル・内容・期限）
- 各世帯の回覧済み状況をタップで更新
- 進捗バーで一目で確認
- 期限超過アラート

### 4. 集金管理
- 町内会費などの集金管理
- 各世帯の支払い状況をタップで更新
- 収納済み金額・未収金額の集計
- 集金の締め切り機能

### 5. 行事予定
- 班長会議・清掃・祭り・防災訓練などをカテゴリ別管理
- 今後・過去・全件のフィルタリング
- 月ごとのグループ表示

### 6. 設定
- 町内会名・班名・班長名の設定
- 年会費の設定
- データ利用状況の確認

## セットアップ

### 必要環境
- Node.js 18以上
- npm または yarn
- Expo CLI
- iOS Simulator (macOS) または Expo Go アプリ (iPhone実機)

### インストール

```bash
# 依存パッケージのインストール
npm install

# 開発サーバーの起動
npx expo start
```

### 実機での実行

1. App StoreからExpo Goをインストール
2. `npx expo start` を実行
3. 表示されたQRコードをExpo Goアプリでスキャン

### iPhoneアプリとしてビルド

```bash
# EASビルドの設定（初回のみ）
npx eas build:configure

# iOSビルド
npx eas build --platform ios
```

## 技術スタック

- **フレームワーク**: React Native (Expo SDK 51)
- **言語**: TypeScript
- **ナビゲーション**: React Navigation v6 (Bottom Tabs + Stack)
- **データ保存**: AsyncStorage（端末内ローカル保存）
- **UI**: カスタムコンポーネント（iOS スタイル）
- **アイコン**: @expo/vector-icons (Ionicons)

## ディレクトリ構成

```
src/
├── types/          # TypeScript型定義
├── store/          # AppContext (グローバル状態管理)
├── navigation/     # React Navigation設定
├── screens/        # 各画面
│   ├── HomeScreen.tsx
│   ├── ResidentsScreen.tsx
│   ├── CircularScreen.tsx
│   ├── FeesScreen.tsx
│   ├── EventsScreen.tsx
│   └── SettingsScreen.tsx
├── components/     # 共通UIコンポーネント
│   └── common/
└── utils/          # ユーティリティ・テーマ・サンプルデータ
```

## データの保存

すべてのデータはAsyncStorageを使用してデバイス内に保存されます。
クラウド同期には対応していませんが、デバイス内で永続的に保存されます。
