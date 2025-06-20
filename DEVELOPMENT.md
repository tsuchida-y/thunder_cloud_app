# 入道雲サーチアプリ - 開発者向け詳細ドキュメント

このドキュメントは、入道雲サーチアプリの詳細な技術情報、開発メモ、アーキテクチャ設計について記載しています。

## 📋 目次

- [背景・開発目的](#背景開発目的)
- [詳細なアーキテクチャ設計](#詳細なアーキテクチャ設計)
- [ファイル構成](#ファイル構成)
- [積乱雲判定ロジック詳細](#積乱雲判定ロジック詳細)
- [Firebase Cloud Functions詳細](#firebase-cloud-functions詳細)
- [パフォーマンス最適化](#パフォーマンス最適化)
- [通知機能詳細](#通知機能詳細)
- [工夫した点](#工夫した点)
- [Firebase プロジェクト設定](#firebase-プロジェクト設定)
- [アプリの動作例](#アプリの動作例)
- [今後の展望](#今後の展望)
- [開発用メモ](#開発用メモ)

## 背景・開発目的

### **入道雲を見逃さないために**
自分の好きな入道雲が、どの方向で出現しているかを知りたいという思いから開発しました。

### **自分の好きなもののためにアプリ開発に挑戦**
趣味としての入道雲観察と Flutter を利用して、実用的なアプリ作成に挑戦。

## 詳細なアーキテクチャ設計

### **サービス指向アーキテクチャ（SOA）**
アプリは複数の独立したサービスから構成され、各サービスが特定の責務を持ちます：

### **SOA選定理由**
1. **パフォーマンス問題の解決**: 初期版では単一ファイルに機能が集中していた。サービス分離により並列処理とリソース管理を最適化
2. **保守性の向上**: 各サービスが独立した責務を持つため、コードの理解・修正・テストが容易
3. **拡張性の確保**: 新機能追加時に既存コードへの影響を最小化し、モジュール単位での開発が可能
4. **モバイルアプリに適合**: マイクロサービスほど複雑でなく、モノリシックより柔軟な、Flutter アプリに最適な規模感

### **コアサービス詳細**
- **`AppInitialization`**: アプリの初期化プロセスを統括、並列処理により起動速度を大幅に改善
- **`FCMToken`**: Firebase Cloud Messagingトークンの取得・管理・キャッシュ、リトライロジック
- **`Location`**: 位置情報の取得・監視・キャッシュ、リソース管理
- **`PushNotification`**: プッシュ通知メッセージの処理・表示
- **`Notification`**: ローカル通知の管理
- **`Logger`**: 統一されたログ管理システム
- **`WeatherDataService`**: 気象データの管理・自動更新（新機能）

### **天気関連サービス**
- **`WeatherDebug`**: 気象データのデバッグ・詳細ログ出力、Open-Meteo APIとの通信
- **`Analyzer`**: 積乱雲分析ロジック

### **ユーティリティ**
- **`Coordinate`**: 座標計算・距離計算のユーティリティ

## ファイル構成

```
thunder_cloud_app/
├── lib/
│   ├── main.dart                                // アプリのエントリーポイント（簡素化済み）
│   ├── firebase_options.dart                    // Firebase設定
│   ├── constants/
│   │   ├── avatar_positions.dart                // ウィジェットの配置位置などの定数
│   │   └── weather.dart                         // 気象分析の重み係数定数
│   ├── models/
│   │   └── assessment.dart                      // 積乱雲評価結果モデル
│   ├── screens/
│   │   ├── weather_screen.dart                  // メイン画面（軽量化済み）
│   │   └── settings_screen.dart                 // 気象データ詳細画面（新機能）
│   ├── services/                                // コアサービス層
│   │   ├── app_initialization.dart              // アプリ初期化サービス
│   │   ├── fcm_token.dart                       // FCMトークン管理
│   │   ├── location.dart                        // 位置情報サービス
│   │   ├── notification.dart                    // ローカル通知サービス
│   │   ├── push_notification.dart               // プッシュ通知サービス
│   │   ├── weather_data_service.dart            // 気象データ管理サービス（新機能）
│   │   ├── weather_debug.dart                   // 気象デバッグサービス
│   │   └── weather/
│   │       └── analyzer.dart                    // 積乱雲分析ロジック
│   ├── utils/                                   // ユーティリティ層
│   │   ├── logger.dart                          // 統一ログ管理
│   │   └── coordinate.dart                      // 座標計算ユーティリティ
│   └── widgets/
│       ├── cloud/
│       │   ├── cloud_avatar.dart                // 雲/青空画像ウィジェット
│       │   ├── cloud_status_overlay.dart        // 積乱雲情報オーバーレイ
│       │   └── direction_image.dart             // 方向画像ウィジェット
│       ├── common/
│       │   └── app_bar.dart                     // AppBar専用ウィジェット
│       └── map/
│           └── background.dart                  // GoogleMap背景ウィジェット
│
├── functions/                                   // Firebase Cloud Functions (JavaScript)
│   ├── index.js                                 // 定期実行される積乱雲チェック機能
│   ├── coordinate_utils.js                      // 座標計算ユーティリティ
│   ├── thunder_cloud_analyzer.js                // 積乱雲分析ロジック
│   ├── package.json                             // Node.js依存関係
│   └── eslint.config.js                         // ESLint設定
├── firestore.rules                              // Firestore セキュリティルール
├── firestore.indexes.json                      // Firestore インデックス設定
└── firebase.json                                // Firebase プロジェクト設定
```

## 積乱雲判定ロジック詳細

### **分析指標と重み配分**
| 指標 | 重み | 説明 | 判定基準 |
|------|------|------|----------|
| CAPE | 50% | 対流有効位置エネルギー | 2500+ J/kg: 100%、1000-2500: 80%、500-1000: 60%、100-500: 30%、100未満: 0% |
| リフティド指数 | 35% | 大気安定度 | -6以下: 100%、-3～-6: 80%、0～-3: 60%、3～0: 40%、6～3: 20%、6以上: 0% |
| CIN | 5% | 対流抑制 | 10以下: 30%、50以下: 10%、50以上: 0% |
| 気温 | 10% | 基本気象要素 | 30°C以上: 100%、25-30°C: 80%、20-25°C: 60%、15-20°C: 40%、15°C未満: 0% |

### **検索範囲設定**
- **距離**: 50km（近距離）、160km（中距離）、250km（遠距離）
- **方向**: 北・南・東・西の4方向
- **総チェック地点**: 12地点（4方向 × 3距離）
- **Cloud Functions自動実行**: 5分間隔で全アクティブユーザーをチェック
- **API使用量**: 約17,280リクエスト/日（全ユーザー分、制限内で安全運用）

### **総合判定**
- **50%以上**: 積乱雲の可能性あり（プッシュ通知送信）
- **50%未満**: 積乱雲の可能性低い
- **信頼度**: データの完整性に基づく信頼度（通常100%）

## Firebase Cloud Functions詳細

### **Cloud Functions 構成**
- **`index.js`**: メイン関数とFirebase初期化
- **`coordinate_utils.js`**: 座標計算・距離計算ユーティリティ
- **`thunder_cloud_analyzer.js`**: 高度気象分析・積乱雲判定ロジック

### **`checkThunderClouds` 関数**
- **実行間隔**: 5分間隔（Pub/Sub トリガー）
- **処理内容**:
  1. Firestoreから全アクティブユーザーの位置情報を取得
  2. 各ユーザーの周辺12地点で気象データを分析
  3. 積乱雲検出時、該当ユーザーにプッシュ通知を送信
  4. エラーハンドリングとログ出力

### **JavaScript移行の利点**
- **シンプルな開発環境**: TypeScriptのビルドプロセスが不要
- **直接実行**: Node.jsで直接実行可能
- **軽量な依存関係**: 型定義ファイルが不要
- **同等の機能**: TypeScript版と完全に同じ機能を提供

### **デプロイコマンド**
```bash
cd functions
npm install
firebase deploy --only functions
```

## パフォーマンス最適化

### **実装された最適化**
- **並列初期化**: サービス初期化を並列実行し、起動速度を大幅改善
- **インテリジェントキャッシュ**: FCMトークン、位置情報のキャッシュにより重複処理を削減
- **リソース管理**: 適切なリソース解放とライフサイクル管理
- **効率的なAPI利用**: 必要最小限のAPIリクエストによるパフォーマンス向上
- **CPU使用率削減**: リトライループの最適化により高CPU使用率問題を解決

### **パフォーマンス指標**
- **起動時間**: 大幅短縮（並列初期化により）
- **CPU使用率**: 99% → 正常レベル（最適化後）
- **メモリ使用量**: 効率的なキャッシュ戦略により安定化

## 通知機能詳細

### **プッシュ通知（Firebase Cloud Messaging）**
- **サーバーサイド通知**: Cloud Functions からの自動通知
- **iOS/Android両対応**: プラットフォーム固有の設定に対応
- **バックグラウンド動作**: アプリが非アクティブでも通知受信可能

### **ローカル通知**
- **フォアグラウンド通知**: アプリ起動中の即座通知
- **権限管理**: iOS/Android の通知権限を適切に管理

### **通知の種類**
- **積乱雲発見通知**: 「⛈️ 入道雲を発見！○○方向に入道雲が出現しています」
- **システム通知**: FCMトークン取得、位置情報更新など

## 工夫した点

### **アーキテクチャ設計**
- **サービス指向アーキテクチャ**: 各サービスが独立した責務を持つ設計により、保守性と拡張性を大幅に向上
- **統一ログ管理**: `Logger`による一元化されたログ管理で、デバッグとモニタリングを効率化
- **適切な分離関心**: UI、ビジネスロジック、データアクセス層の明確な分離
- **ファイル命名規則**: ディレクトリ構造で役割を明示し、冗長な接尾辞を排除した簡潔な命名

### **パフォーマンス最適化**
- **並列処理**: アプリ初期化の並列実行により起動時間を大幅短縮
- **インテリジェントキャッシュ**: FCMトークンと位置情報のキャッシュによる重複処理削減
- **リソース管理**: メモリリークを防ぐ適切なライフサイクル管理

### **Firebase統合**
- **Cloud Functions**: サーバーサイドでの定期的な積乱雲チェック
- **Firestore**: スケーラブルなデータストレージ
- **FCM**: 信頼性の高いプッシュ通知システム

### **高度気象分析**
- **専門的な気象データ**: CAPE、LI、CINなどの気象学的指標を活用
- **重み付きスコア計算**: 各指標の重要度を考慮した精密な判定
- **座標計算**: 緯度による経度距離の変動を考慮した正確な距離計算

### **ユーザー体験**
- **リアルタイム更新**: 5分間隔での自動チェック（サーバー）、30秒間隔（クライアント）
- **視覚的フィードバック**: 雲/青空画像の動的切り替え
- **直感的なUI**: GoogleMap連携による分かりやすい方向表示

### **新機能: 詳細気象データ表示**
- **30秒間隔の自動更新**: 最新の気象状況を常に把握
- **4方向別データ表示**: 北・南・東・西の各方向の独立した気象分析
- **視覚的なリスクレベル表示**: HIGH（赤）・MEDIUM（橙）・LOW（黄）のカラーコード
- **座標情報**: 各観測地点の正確な位置情報
- **手動更新の無効化**: API保護のため、ユーザーによる手動更新を制限

## Firebase プロジェクト設定

### **プロジェクト情報**
- **プロジェクトID**: `thunder-cloud-app-292e6`
- **使用サービス**: Authentication, Firestore, Cloud Functions, Cloud Messaging, Analytics

### **Firestore データ構造**
```
/users/{fcmToken}
├── fcmToken: string      // Firebase Cloud Messaging トークン
├── latitude: number      // 緯度
├── longitude: number     // 経度
├── lastUpdated: timestamp // 最終更新日時
└── isActive: boolean     // アクティブ状態
```

### **セキュリティルール**
現在は開発用の緩いルール設定ですが、本番環境では適切な認証・認可ルールの設定が必要

### **開発環境と本番環境の分離**
- **開発環境（kDebugMode=true）**: Firestore への位置情報保存を無効化
- **本番環境（kDebugMode=false）**: 通常の動作で位置情報保存が有効
- **開発用トークン**: `dev_token_`で始まるトークンはFirestore保存対象外

## アプリの動作例

### **高度気象分析ログ出力例**
```
[WeatherDebugService] === 積乱雲分析結果（Open-Meteoのみ）===
[WeatherDebugService] 総合判定: 積乱雲の可能性あり
[WeatherDebugService] 総合スコア: 73.2%
[WeatherDebugService] 信頼度: 100.0%
[WeatherDebugService] リスクレベル: 高い
[WeatherDebugService] East: 積乱雲あり（スコア: 73.2%）
[WeatherDebugService] 詳細分析:
[WeatherDebugService]   - CAPE: 2,847 J/kg (スコア: 100%)
[WeatherDebugService]   - LI: -4.2 (スコア: 80%)
[WeatherDebugService]   - CIN: 8.3 J/kg (スコア: 30%)
[WeatherDebugService]   - 気温: 28.5°C (スコア: 80%)
```

### **WeatherDataService ログ出力例**
```
[WeatherDataService] 気象データ取得開始: 39.8028, 141.1374
[WeatherDataService] 4方向の気象データ分析完了
[WeatherDataService] 北方向: スコア 32.0% (入道雲なし)
[WeatherDataService] 南方向: スコア 40.0% (入道雲なし)
[WeatherDataService] 東方向: スコア 48.5% (入道雲なし)
[WeatherDataService] 西方向: スコア 24.5% (入道雲なし)
[WeatherDataService] データ更新完了
```

## 今後の展望

### **機能拡張**
- **写真撮影・共有機能**: 入道雲の写真撮影とSNS共有
- **ユーザー認証**: Firebase Authentication による個人データ管理
- **通知カスタマイズ**: ユーザー別の通知設定（閾値調整、時間帯設定）
- **データ分析**: 積乱雲出現パターンの分析・可視化
- **履歴機能**: 過去の入道雲検出履歴の表示
- **お気に入り地点**: 複数地点の監視機能

### **技術改善**
- **Push通知最適化**: 高度な通知スケジューリング
- **UI/UX改善**: アニメーション、アクセシビリティ対応
- **テスト自動化**: ユニットテスト、統合テストの拡充
- **Cloud Functions**: 必要に応じてTypeScriptへの再移行も可能
- **エラーハンドリング**: より詳細なエラー処理とユーザーフィードバック
- **オフライン対応**: ネットワーク切断時の対応

### **スケーラビリティ**
- **マルチリージョン対応**: 世界各地での利用を想定した拡張
- **負荷分散**: Cloud Functions の最適化
- **監視・アラート**: システム監視とエラー通知の強化
- **API制限対応**: Open-Meteo API の制限を考慮した最適化

## 開発用メモ

### **iOSシミュレータ操作**
```bash
# 利用可能なシミュレータ一覧
xcrun simctl list devices

# シミュレータ起動
xcrun simctl boot <UDID>
xcrun simctl boot CD928AEE-F546-4212-A73D-E491C33E041F

# iPhone 13 Pro Max
xcrun simctl boot 60748703-0EE0-4B9E-A44C-0EBA7C730054

# iPad Pro 13-inch (M4)
xcrun simctl boot "79D1CEF9-A34A-4F9A-A9C8-DFCDC855595E"

# iPhone 16
xcrun simctl boot 36E813A4-893B-4712-8A34-431C6A3BB54C

# Simulatorアプリを開く
open -a Simulator
```

### **Firebase コマンド**
```bash
# Functions ログ確認
firebase functions:log

# Functions エミュレータ実行（JavaScript）
firebase emulators:start --only functions

# Firestore データ確認
firebase firestore:delete --all-collections

# プロジェクト情報確認
firebase projects:list

# Functions デプロイ
firebase deploy --only functions

# Firestore ルール デプロイ
firebase deploy --only firestore:rules
```

### **デバッグコマンド**
```bash
# Flutter デバッグビルド
flutter run --debug

# リリースビルド
flutter build apk --release
flutter build ios --release

# パッケージ更新
flutter pub get
flutter pub upgrade

# クリーンビルド
flutter clean
flutter pub get
```

### **App Store 関連**
```bash
# iOS アーカイブ作成
# Xcode → Product → Archive

# アップロード用スクリプト
./upload_script.sh
```

### **開発中の注意点**
- **API制限**: Open-Meteo APIの制限を考慮し、過度なリクエストを避ける
- **デバッグモード**: `kDebugMode`でFirestore保存を無効化
- **FCMトークン**: 開発用トークンは`dev_token_`プレフィックスを使用
- **位置情報**: シミュレータでは固定座標を使用
- **通知テスト**: 実機でのテストが必要（シミュレータは制限あり）

### **パフォーマンス監視**
- **CPU使用率**: 高い場合はリトライロジックを確認
- **メモリ使用量**: キャッシュサイズとライフサイクル管理を確認
- **ネットワーク**: API呼び出し頻度と応答時間を監視
- **バッテリー**: 位置情報取得頻度とバックグラウンド処理を最適化

---