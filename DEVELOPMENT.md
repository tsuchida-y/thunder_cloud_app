# 入道雲サーチアプリ - 開発者向け詳細ドキュメント

このドキュメントは、入道雲サーチアプリの詳細な技術情報、開発メモ、アーキテクチャ設計について記載しています。

## 📋 目次

- [背景・開発目的](#背景開発目的)
- [詳細なアーキテクチャ設計](#詳細なアーキテクチャ設計)
- [ファイル構成](#ファイル構成)
- [積乱雲判定ロジック詳細](#積乱雲判定ロジック詳細)
- [Firebase Cloud Functions詳細](#firebase-cloud-functions詳細)
- [写真管理システム詳細](#写真管理システム詳細)
- [コミュニティ機能詳細](#コミュニティ機能詳細)
- [夜間モード詳細](#夜間モード詳細)
- [APIリクエスト最適化](#apiリクエスト最適化)
- [プライバシー保護機能](#プライバシー保護機能)
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

### **写真共有コミュニティ**
単なる監視アプリではなく、入道雲愛好家が写真を共有し、コミュニティを形成できるプラットフォームを目指しました。

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
- **`FCMTokenManager`**: Firebase Cloud Messagingトークンの取得・管理・キャッシュ、リトライロジック
- **`LocationService`**: 位置情報の取得・監視・キャッシュ、リソース管理
- **`PushNotificationService`**: プッシュ通知メッセージの処理・表示
- **`NotificationService`**: ローカル通知の管理
- **`Logger`**: 統一されたログ管理システム
- **`WeatherDataService`**: 気象データの管理・自動更新
- **`WeatherCacheService`**: 気象データキャッシュの効率的管理

### **写真関連サービス**
- **`PhotoService`**: 写真のアップロード・管理・削除、Firestore/Storage連携
- **`LocalPhotoService`**: ローカル写真の保存・管理、SharedPreferences活用
- **`CameraService`**: カメラ機能の制御
- **`UserService`**: ユーザー情報の管理・プロフィール機能

### **コミュニティ関連サービス**
- **`CommunityService`**: コミュニティ機能のビジネスロジック、いいね・ダウンロード機能

### **天気関連サービス**
- **`WeatherDebugService`**: 気象データのデバッグ・詳細ログ出力、Open-Meteo APIとの通信
- **`Analyzer`**: 積乱雲分析ロジック

### **ユーティリティ**
- **`Coordinate`**: 座標計算・距離計算のユーティリティ

## ファイル構成

```
thunder_cloud_app/
├── lib/
│   ├── main.dart                                // アプリのエントリーポイント
│   ├── firebase_options.dart                    // Firebase設定
│   ├── constants/
│   │   ├── app_constants.dart                   // アプリ全体の定数
│   │   ├── avatar_positions.dart                // ウィジェットの配置位置定数
│   │   └── weather_constants.dart               // 気象分析の重み係数定数
│   ├── models/
│   │   ├── assessment.dart                      // 積乱雲評価結果モデル
│   │   └── photo.dart                           // 写真データモデル
│   ├── screens/
│   │   ├── weather_screen.dart                  // メイン画面
│   │   ├── settings_screen.dart                 // 気象データ詳細画面
│   │   ├── camera_screen.dart                   // カメラ撮影画面
│   │   ├── gallery_screen.dart                  // ギャラリー画面
│   │   ├── community_screen.dart                // コミュニティ画面
│   │   ├── camera/
│   │   │   └── photo_preview_screen.dart        // 写真プレビュー画面
│   │   ├── gallery/
│   │   │   ├── gallery_photo_detail_screen.dart // ギャラリー詳細画面
│   │   │   └── gallery_service.dart             // ギャラリーサービス
│   │   ├── community/
│   │   │   ├── community_photo_card.dart        // コミュニティ写真カード
│   │   │   └── community_service.dart           // コミュニティサービス
│   │   └── settings/
│   │       └── settings_service.dart            // 設定サービス
│   ├── services/                                // コアサービス層
│   │   ├── core/
│   │   │   └── app_initialization.dart          // アプリ初期化サービス
│   │   ├── location/
│   │   │   └── location_service.dart            // 位置情報サービス
│   │   ├── notification/
│   │   │   ├── fcm_token_manager.dart           // FCMトークン管理
│   │   │   ├── notification_service.dart        // ローカル通知サービス
│   │   │   └── push_notification_service.dart   // プッシュ通知サービス
│   │   ├── photo/
│   │   │   ├── camera_service.dart              // カメラサービス
│   │   │   ├── local_photo_service.dart         // ローカル写真サービス
│   │   │   ├── photo_service.dart               // 写真サービス
│   │   │   └── user_service.dart                // ユーザーサービス
│   │   └── weather/
│   │       ├── analyzer.dart                    // 積乱雲分析ロジック
│   │       ├── weather_cache_service.dart       // 気象キャッシュサービス
│   │       ├── weather_data_service.dart        // 気象データサービス
│   │       └── weather_debug_service.dart       // 気象デバッグサービス
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
│   ├── constants.js                             // 定数管理（夜間モード設定含む）
│   ├── package.json                             // Node.js依存関係
│   └── eslint.config.js                         // ESLint設定
├── firestore.rules                              // Firestore セキュリティルール
├── firestore.indexes.json                      // Firestore インデックス設定
├── storage.rules                                // Firebase Storage セキュリティルール
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

### **総合判定**
- **50%以上**: 積乱雲の可能性あり（プッシュ通知送信）
- **50%未満**: 積乱雲の可能性低い
- **信頼度**: データの完整性に基づく信頼度（通常100%）

## Firebase Cloud Functions詳細

### **Cloud Functions 構成**
- **`index.js`**: メイン関数とFirebase初期化
- **`coordinate_utils.js`**: 座標計算・距離計算ユーティリティ
- **`thunder_cloud_analyzer.js`**: 高度気象分析・積乱雲判定ロジック
- **`constants.js`**: 夜間モード設定、閾値、重み係数などの定数管理

### **主要関数**
- **`checkThunderClouds`**: 5分間隔での入道雲チェック（夜間モード対応）
- **`cacheWeatherData`**: 5分間隔での気象データキャッシュ（夜間モード対応）
- **`getWeatherData`**: 気象データ取得API（夜間モード対応）
- **`cleanupExpiredPhotos`**: 期限切れ写真の自動削除（毎日午前1時）
- **`cleanupExpiredLikes`**: 期限切れいいねの自動削除（毎日午前2時）

### **JavaScript移行の利点**
- **シンプルな開発環境**: TypeScriptのビルドプロセスが不要
- **直接実行**: Node.jsで直接実行可能
- **軽量な依存関係**: 型定義ファイルが不要
- **同等の機能**: TypeScript版と完全に同じ機能を提供

## 写真管理システム詳細

### **Firebase Storage構成**
```
storage/
├── photos/
│   └── {userId}/
│       └── thunder_cloud_{timestamp}.jpg
```

### **Firestore写真データ構造**
```javascript
/photos/{photoId}
├── id: string              // 写真ID
├── userId: string          // 投稿者ID
├── userName: string        // 投稿者名
├── imageUrl: string        // Firebase Storage URL
├── caption: string         // キャプション
├── timestamp: timestamp    // 投稿日時
├── expiresAt: timestamp    // 期限切れ日時（30日後）
├── isPublic: boolean       // 公開設定
├── likes: number           // いいね数
├── latitude: number        // 撮影位置（小数点2位）
├── longitude: number       // 撮影位置（小数点2位）
├── locationName: string    // 撮影地名
├── weatherData: map        // 気象データ（削除済み）
└── tags: array            // タグ
```

### **ローカル写真管理**
- **SharedPreferences**: 写真メタデータの保存
- **アプリ内ディレクトリ**: 実画像ファイルの保存
- **自動同期**: Firestore投稿とローカル保存の両方実行

## コミュニティ機能詳細

### **いいね機能**
- **Firestore構造**: `/likes/{photoId}_{userId}`
- **TTL対応**: 30日後の自動削除
- **楽観的更新**: UI即座更新でUX向上
- **バッチ処理**: 複数写真のいいね状態を効率的に取得

### **写真ダウンロード機能**
- **HTTP経由**: 画像URLから直接ダウンロード
- **ローカル保存**: ギャラリーアプリに保存
- **メタデータ付与**: ダウンロード元情報を記録

### **写真削除機能**
- **権限確認**: 投稿者のみ削除可能
- **関連データ削除**: Storage画像、Firestoreデータ、いいねを一括削除

## 夜間モード詳細

### **設定**
- **夜間時間帯**: 20時〜8時（日本時間基準）
- **対象機能**: 気象データ取得、入道雲チェック、プッシュ通知

### **実装箇所**
- **Cloud Functions**: `isNightMode()`関数で判定
- **Flutter アプリ**: 設定画面で夜間モード表示
- **API最適化**: 夜間は全APIリクエストを停止

### **省エネ効果**
- **APIリクエスト**: 夜間12時間で約144回のリクエストを削減
- **サーバー負荷**: Cloud Functions実行回数を大幅削減
- **バッテリー**: クライアント側の処理負荷軽減

## APIリクエスト最適化

### **削減施策**
1. **夜間モード**: 20時〜8時の全APIリクエスト停止
2. **写真投稿最適化**: 投稿時の気象データ取得を削除
3. **手動更新削除**: 設定画面の手動更新機能を削除
4. **キャッシュ活用**: 5分間隔の自動更新データを効率活用

### **APIリクエスト数試算（50人利用時）**
| 項目 | 頻度 | 回数/日 | 説明 |
|------|------|---------|------|
| 自動チェック（昼間） | 5分間隔×12時間 | 144回 | Cloud Functions |
| 自動キャッシュ（昼間） | 5分間隔×12時間 | 144回 | Cloud Functions |
| アプリ起動時取得 | 7回/人/日×50人 | 350回 | クライアント |
| **合計** | - | **638回** | **6.4%（上限10,000回）** |

### **削減効果**
- **従来想定**: 約2,000回/日 → **現在**: 638回/日
- **削減率**: 約68%の大幅削減
- **安全マージン**: 上限の93.6%の余裕

## プライバシー保護機能

### **位置情報保護**
- **座標精度制限**: 小数点2位（約1km精度）に統一
- **プライバシー重視**: 詳細な住所特定を防止
- **一貫性**: 表示・保存・送信で統一した精度

### **自動削除システム**
- **写真データ**: 投稿から30日後に自動削除
- **いいねデータ**: 30日後に自動削除
- **クリーンアップ**: 毎日自動実行でストレージ最適化

### **データ最小化**
- **気象データ削除**: 写真投稿時の不要な気象データ取得を停止
- **必要最小限**: 機能に必要な最小限のデータのみ収集

## パフォーマンス最適化

### **実装された最適化**
- **並列初期化**: サービス初期化を並列実行し、起動速度を大幅改善
- **インテリジェントキャッシュ**: FCMトークン、位置情報、気象データのキャッシュにより重複処理を削減
- **リソース管理**: 適切なリソース解放とライフサイクル管理
- **効率的なAPI利用**: 夜間モード・手動更新削除によりAPIリクエスト数を大幅削減
- **CPU使用率削減**: リトライループの最適化により高CPU使用率問題を解決
- **画像最適化**: キャッシュ機能付きの効率的な画像表示

### **パフォーマンス指標**
- **起動時間**: 大幅短縮（並列初期化により）
- **CPU使用率**: 99% → 正常レベル（最適化後）
- **メモリ使用量**: 効率的なキャッシュ戦略により安定化
- **APIリクエスト**: 68%削減で大幅な負荷軽減

## 通知機能詳細

### **プッシュ通知（Firebase Cloud Messaging）**
- **サーバーサイド通知**: Cloud Functions からの自動通知
- **iOS/Android両対応**: プラットフォーム固有の設定に対応
- **バックグラウンド動作**: アプリが非アクティブでも通知受信可能
- **夜間モード対応**: 20時〜8時は通知チェックを停止

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
- **夜間モード**: 入道雲発生確率の低い夜間のリソース使用を停止

### **Firebase統合**
- **Cloud Functions**: サーバーサイドでの定期的な積乱雲チェック
- **Firestore**: スケーラブルなデータストレージ
- **FCM**: 信頼性の高いプッシュ通知システム
- **Storage**: 写真ファイルの安全な保存

### **高度気象分析**
- **専門的な気象データ**: CAPE、LI、CINなどの気象学的指標を活用
- **重み付きスコア計算**: 各指標の重要度を考慮した精密な判定
- **座標計算**: 緯度による経度距離の変動を考慮した正確な距離計算

### **ユーザー体験**
- **リアルタイム更新**: 5分間隔での自動チェック（サーバー）、30秒間隔（クライアント）
- **視覚的フィードバック**: 雲/青空画像の動的切り替え
- **直感的なUI**: GoogleMap連携による分かりやすい方向表示
- **写真共有**: コミュニティ機能による入道雲愛好家の交流促進

### **プライバシー配慮**
- **座標精度制限**: 小数点2位（約1km精度）でプライバシー保護
- **自動削除**: 30日後の自動削除でデータ蓄積を防止
- **データ最小化**: 必要最小限のデータのみ収集・保存

## Firebase プロジェクト設定

### **プロジェクト情報**
- **プロジェクトID**: `thunder-cloud-app-292e6`
- **使用サービス**: Authentication, Firestore, Cloud Functions, Cloud Messaging, Analytics, Storage

### **Firestore データ構造**
```
/users/{fcmToken}
├── fcmToken: string      // Firebase Cloud Messaging トークン
├── latitude: number      // 緯度（小数点2位）
├── longitude: number     // 経度（小数点2位）
├── lastUpdated: timestamp // 最終更新日時
└── isActive: boolean     // アクティブ状態

/photos/{photoId}
├── id: string              // 写真ID
├── userId: string          // 投稿者ID
├── userName: string        // 投稿者名
├── imageUrl: string        // Firebase Storage URL
├── caption: string         // キャプション
├── timestamp: timestamp    // 投稿日時
├── expiresAt: timestamp    // 期限切れ日時（30日後）
├── isPublic: boolean       // 公開設定
├── likes: number           // いいね数
├── latitude: number        // 撮影位置（小数点2位）
├── longitude: number       // 撮影位置（小数点2位）
├── locationName: string    // 撮影地名
├── weatherData: map        // 気象データ（削除済み）
└── tags: array            // タグ

/likes/{photoId}_{userId}
├── photoId: string       // 写真ID
├── userId: string        // ユーザーID
├── timestamp: timestamp  // いいね日時
└── expiresAt: timestamp  // 期限切れ日時（30日後）

/weather_cache/{cacheKey}
├── latitude: number      // 緯度
├── longitude: number     // 経度
├── data: map            // 気象データ
├── timestamp: timestamp  // キャッシュ日時
└── expiresAt: timestamp  // 期限切れ日時
```

### **セキュリティルール**
- **users**: 認証済みユーザーのみ自身のデータにアクセス可能
- **photos**: 公開写真は全員読み取り可能、作成・更新・削除は所有者のみ
- **likes**: 認証済みユーザーのみ操作可能
- **weather_cache**: 全員読み取り可能、Firebase Functionsのみ書き込み可能

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

### **夜間モードログ出力例**
```
[Cloud Functions] 🌙 夜間モード（20時〜8時）: 入道雲チェックを完全にスキップ
[Cloud Functions] 🌙 夜間モード: 気象データキャッシュをスキップ
[SettingsScreen] 夜間モード表示: 20時〜8時は監視停止中
```

### **写真投稿ログ出力例**
```
[PhotoPreviewScreen] 投稿処理開始
[PhotoPreviewScreen] 位置情報取得: LatLng(39.80, 141.14)
[PhotoService] 写真アップロード開始
[PhotoService] Firebase Storage アップロード完了
[PhotoService] Firestore 写真データ保存完了
[LocalPhotoService] ローカル写真保存完了
[PhotoPreviewScreen] 投稿処理完了
```

## 今後の展望

### **機能拡張**
- **ユーザー認証**: Firebase Authentication による個人データ管理
- **通知カスタマイズ**: ユーザー別の通知設定（閾値調整、時間帯設定）
- **データ分析**: 積乱雲出現パターンの分析・可視化
- **履歴機能**: 過去の入道雲検出履歴の表示
- **お気に入り地点**: 複数地点の監視機能
- **写真フィルター**: 撮影日時、場所、気象条件での絞り込み

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

### **コミュニティ機能強化**
- **プロフィール機能**: アバター、自己紹介、統計情報
- **コメント機能**: 写真へのコメント・返信
- **フォロー機能**: 他のユーザーをフォロー
- **ランキング**: いいね数、投稿数でのランキング表示

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

# Storage ルール デプロイ
firebase deploy --only storage
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
- **写真機能**: 実機でのカメラ・ギャラリー機能テストが必要

### **パフォーマンス監視**
- **CPU使用率**: 高い場合はリトライロジックを確認
- **メモリ使用量**: キャッシュサイズとライフサイクル管理を確認
- **ネットワーク**: API呼び出し頻度と応答時間を監視
- **バッテリー**: 位置情報取得頻度とバックグラウンド処理を最適化
- **ストレージ**: 写真ファイルのサイズと自動削除を監視

### **セキュリティチェックリスト**
- **Firestore Rules**: 適切なアクセス制御の実装
- **Storage Rules**: 写真ファイルの適切な権限設定
- **API Key**: Firebase設定ファイルの適切な管理
- **位置情報**: 精度制限の実装確認
- **データ削除**: TTLと自動削除の動作確認

---