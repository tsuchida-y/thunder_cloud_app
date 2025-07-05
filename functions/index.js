/**
 * Firebase Cloud Functions メインエントリーポイント
 *
 * 雷雲アプリのバックエンドサービスを提供するFirebase Functions
 * モジュラー設計により、各機能が独立したサービスクラスとして実装されている
 *
 * 主な機能:
 * - 気象データ取得API (HTTP)
 * - 入道雲監視 (スケジュール)
 * - データクリーンアップ (スケジュール)
 * - リアルタイム通知 (バックグラウンド)
 */

const {onRequest} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

// === サービスクラス群をインポート ===
const WeatherService = require('./modules/weather/weather_service');           // 気象データ処理
const ThunderMonitoring = require('./modules/monitoring/thunder_monitoring'); // 入道雲監視
const CleanupService = require('./modules/cleanup/cleanup_service');         // データクリーンアップ
const HttpHandlers = require('./modules/handlers/http_handlers');            // HTTP API ハンドラー
const ScheduleHandlers = require('./modules/handlers/schedule_handlers');     // スケジュールハンドラー

// Firebase Admin SDK を初期化
admin.initializeApp();

/*
================================================================================
                              サービス初期化
                       各機能モジュールのインスタンス作成
================================================================================
*/

// === コアサービスインスタンス ===
const weatherService = new WeatherService();         // 気象データ処理サービス
const thunderMonitoring = new ThunderMonitoring();   // 入道雲監視サービス
const cleanupService = new CleanupService();         // データクリーンアップサービス

// === ハンドラーインスタンス ===
const httpHandlers = new HttpHandlers(weatherService);
const scheduleHandlers = new ScheduleHandlers(weatherService, thunderMonitoring, cleanupService);

/*
================================================================================
                                HTTP API関数
                      外部からのHTTPリクエストを処理
================================================================================
*/

// 気象データ取得 API: GET /getWeatherData?latitude=xx&longitude=xx
exports.getWeatherData = onRequest((req, res) => httpHandlers.getWeatherData(req, res));

// 各方向気象データ取得 API: GET /getDirectionalWeatherData?latitude=xx&longitude=xx
exports.getDirectionalWeatherData = onRequest((req, res) => httpHandlers.getDirectionalWeatherData(req, res));

// キャッシュ統計情報取得 API: GET /getCacheStats
exports.getCacheStats = onRequest((req, res) => httpHandlers.getCacheStats(req, res));

/*
================================================================================
                             スケジュール関数
                         定期実行される自動処理タスク
================================================================================
*/

/**
 * 気象データ自動キャッシュ処理
 * スケジュール: 5分間隔
 * 処理内容: アクティブユーザーの位置周辺の気象データを事前キャッシュ
 */
exports.cacheWeatherData = onSchedule({
  schedule: 'every 5 minutes',
  timeoutSeconds: 540,         // 9分タイムアウト（大量データ処理対応）
  memory: '1GiB',             // 高メモリ割り当て（バッチ処理用）
  region: 'asia-northeast1'   // 東京リージョン（低レイテンシ）
}, () => scheduleHandlers.cacheWeatherData());

/**
 * 入道雲検知・通知処理
 * スケジュール: 5分間隔
 * 処理内容: アクティブユーザー周辺の入道雲を検知し、該当者に通知送信
 */
exports.checkThunderClouds = onSchedule({
  schedule: 'every 5 minutes',
  timeoutSeconds: 300,         // 5分タイムアウト（キャッシュ活用で高速処理）
  memory: '512MiB',           // 標準メモリ（キャッシュベース処理）
  region: 'asia-northeast1'
}, () => scheduleHandlers.checkThunderClouds());

/**
 * 気象データキャッシュクリーンアップ
 * スケジュール: 毎日午前3時
 * 処理内容: 期限切れの気象キャッシュデータを削除
 */
exports.cleanupWeatherCache = onSchedule('0 3 * * *', () => scheduleHandlers.cleanupWeatherCache());

/**
 * 期限切れ写真削除処理
 * スケジュール: 毎日午前1時
 * 処理内容: 保存期限が切れた写真をStorage & Firestoreから削除
 */
exports.cleanupExpiredPhotos = onSchedule('0 1 * * *', () => scheduleHandlers.cleanupExpiredPhotos());

/**
 * 期限切れいいね削除処理
 * スケジュール: 毎日午前2時
 * 処理内容: 期限切れのいいねデータをFirestoreから削除
 */
exports.cleanupExpiredLikes = onSchedule('0 2 * * *', () => scheduleHandlers.cleanupExpiredLikes());

/**
 * 入道雲監視処理（冗長バックアップ）
 * スケジュール: 5分間隔
 * 処理内容: メイン監視処理のバックアップとして動作
 */
exports.monitorThunderClouds = onSchedule('*/5 * * * *', () => scheduleHandlers.monitorThunderClouds());
