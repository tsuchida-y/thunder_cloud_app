# 入道雲サーチアプリ

美しい入道雲の発生を検出・通知する観賞・撮影支援アプリです。

## 📱 アプリ画面

### メイン画面
<img src="assets/images/screen_shot1.png" width="300" alt="メイン画面 - 入道雲サーチ画面">

現在地を中心に東西南北4方向の入道雲発生状況を表示。青い円は各方向の気象状況を示し、入道雲検出時は雲の画像に、晴天時は青空の画像に自動切り替えされます。

### 気象データ詳細画面
<div style="display: flex; gap: 10px;">
  <img src="assets/images/screen_shot2.png" width="300" alt="気象データ画面 - 北方向・南方向の詳細データ">
  <img src="assets/images/screen_shot3.png" width="300" alt="気象データ画面 - 東方向・西方向の詳細データ">
</div>

右上の「気象データ」ボタンから、各方向の詳細な気象データを確認できます。30秒ごとに自動更新され、入道雲発生可能性を総合スコアで表示します。

## ✨ 主な機能

- **🌩️ リアルタイム入道雲検出**: 現在位置周辺12地点を5分間隔で自動監視
- **📊 詳細気象データ表示**: CAPE値、リフティド指数、気温などの専門データを表示
- **🔔 プッシュ通知**: 入道雲発生時に即座に通知
- **🗺️ 地図連携**: Google Maps上で方向を視覚的に表示
- **⚡ 自動更新**: 30秒間隔でのリアルタイムデータ更新

## 🎯 使い方

1. **位置情報許可**: アプリ起動時に位置情報の利用を許可
2. **通知許可**: 入道雲発生時の通知を受け取るため通知を許可
3. **地図確認**: メイン画面で現在地と気象状況を確認
4. **詳細データ**: 右上の「気象データ」ボタンで詳細情報を表示
5. **通知受信**: 入道雲発生時に自動で通知を受信

## 🔬 入道雲判定システム

### 分析指標
| 指標 | 重み | 説明 |
|------|------|------|
| CAPE | 50% | 対流有効位置エネルギー（積乱雲発生の主要指標） |
| リフティド指数 | 35% | 大気の安定度 |
| CIN | 5% | 対流抑制エネルギー |
| 気温 | 10% | 基本的な気象要素 |

### 判定基準
- **50%以上**: 入道雲の可能性あり（通知送信）
- **50%未満**: 入道雲の可能性低い

## 🛡️ プライバシー

本アプリのプライバシーポリシー：[プライバシーポリシー](https://tsuchida-y.github.io/thunder_cloud_app/privacy_policy.html)

## 📞 お問い合わせ

- **開発者**: Tsuchida Yuto
- **GitHub Issues**: https://github.com/tsuchida-y/thunder_cloud_app/issues

---

## 🔧 技術情報（開発者向け）

### 技術スタック
- **Frontend**: Flutter
- **Backend**: Firebase (Cloud Functions, Firestore, FCM)
- **地図**: Google Maps API
- **気象データ**: Open-Meteo API

### アーキテクチャ
サービス指向アーキテクチャ（SOA）を採用し、以下のサービスで構成：

**コアサービス**
- `AppInitialization`: アプリ初期化（並列処理で高速化）
- `FCMToken`: プッシュ通知トークン管理
- `Location`: 位置情報取得・管理
- `WeatherDataService`: 気象データ管理（新機能）

**UI層**
- `WeatherScreen`: メイン画面
- `SettingsScreen`: 気象データ詳細画面（新機能）

### 開発環境セットアップ

```bash
# 依存関係のインストール
flutter pub get

# Firebase設定
# 1. Firebase Consoleでプロジェクト作成
# 2. iOS/Android アプリ登録
# 3. 設定ファイル配置:
#    - iOS: ios/Runner/GoogleService-Info.plist
#    - Android: android/app/google-services.json

# Cloud Functions デプロイ
cd functions
npm install
firebase deploy --only functions

# アプリ起動
flutter run
```

### パフォーマンス最適化
- **並列初期化**: サービス初期化を並列実行し起動速度を大幅改善
- **インテリジェントキャッシュ**: FCMトークン、位置情報のキャッシュで重複処理削減
- **効率的なAPI利用**: 必要最小限のリクエストでコスト削減

### 通知システム
- **サーバーサイド**: Cloud Functions による5分間隔の自動チェック
- **クライアントサイド**: Firebase Cloud Messaging によるプッシュ通知
- **ローカル通知**: アプリ起動中の即座通知

### 今後の展望
- 写真撮影・共有機能
- ユーザー認証システム
- 通知カスタマイズ
- データ分析・可視化機能
