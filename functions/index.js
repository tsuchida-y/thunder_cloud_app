/**
 * Firebase Cloud Functions メインエントリーポイント（入道雲サーチ v2.0）
 *
 * 主な機能:
 * - 気象庁ナウキャストから雲の一覧を作り、利用者ごとに見張って通知する (スケジュール)
 * - 古いデータの掃除 (スケジュール)
 *
 * 注意: v1 の Open-Meteo を使う関数（cacheWeatherData, checkThunderClouds, monitorThunderClouds,
 * cleanupWeatherCache, getWeatherData など）は、v2.0 の公開まで本番で動かし続ける（今のアプリ 1.0.4 が使っているため）。
 * ここから外したので、デプロイは必ず関数名を指定して行う（`firebase deploy --only functions:関数名`）。
 * 指定せずにデプロイすると、本番の v1 の関数を消すかを聞かれる。
 */

const {onSchedule} = require('firebase-functions/v2/scheduler');
const {onRequest} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const admin = require('firebase-admin');

const NowcastService = require('./modules/jma/nowcast_service');            // 気象庁ナウキャストから雲の一覧を作る
const { CloudWatchService } = require('./modules/watch/cloud_watch_service'); // 雲の見張りと通知
const CleanupService = require('./modules/cleanup/cleanup_service');        // データクリーンアップ
const { handleWebhook } = require('./modules/plus/revenuecat_webhook');     // Plus（RevenueCat）

// RevenueCat の webhook の合言葉（Authorization ヘッダー）。
// `firebase functions:secrets:set REVENUECAT_WEBHOOK_AUTH` で登録し、RevenueCat の管理画面にも同じ値を入れる
const revenuecatWebhookAuth = defineSecret('REVENUECAT_WEBHOOK_AUTH');

// Firebase Admin SDK を初期化
admin.initializeApp();

const nowcastService = new NowcastService();
const cloudWatchService = new CloudWatchService();
const cleanupService = new CleanupService();

/**
 * 雲の一覧の更新と通知
 * スケジュール: 5分間隔（全ユーザー分をまとめて1回だけ気象庁へアクセス）
 * 処理内容: 強い雨か雷のある塊を clouds に保存し、新しい解析値があったときだけ利用者ごとに見張って通知する
 */
exports.updateNowcastClouds = onSchedule({
  schedule: 'every 5 minutes',
  timeZone: 'Asia/Tokyo',
  timeoutSeconds: 120,
  memory: '512MiB',
  region: 'asia-northeast1'
}, async () => {
  const updated = await nowcastService.updateClouds();
  if (updated) {
    await cloudWatchService.run();
  }
});

/**
 * 終わった雲の削除
 * スケジュール: 毎日 3:30（日本時間）
 */
exports.cleanupOldClouds = onSchedule({
  schedule: '30 3 * * *',
  timeZone: 'Asia/Tokyo',
  region: 'asia-northeast1'
}, () => cleanupService.cleanupOldClouds());

/**
 * 期限切れ写真削除処理
 * スケジュール: 毎日午前1時
 * 処理内容: 保存期限が切れた写真をStorage & Firestoreから削除
 * v1 から本番で動いている関数なので、名前と設定（リージョン・時刻）は v1 のまま
 */
exports.cleanupExpiredPhotos = onSchedule('0 1 * * *', () => cleanupService.cleanupExpiredPhotos());

/**
 * Plus の購入・更新・期限切れ（RevenueCat の webhook）
 * 処理内容: member_server/{uid} の isPlus と plusExpiresAt を書く
 */
exports.revenuecatWebhook = onRequest({
  region: 'asia-northeast1',
  secrets: [revenuecatWebhookAuth],
}, (req, res) => handleWebhook(req, res, { authToken: revenuecatWebhookAuth.value() }));

/**
 * 最後にアプリを開いてから1年たった利用者の情報の削除（プライバシーポリシーの「保存する期間」）
 * スケジュール: 毎日 4:00（日本時間）
 */
exports.cleanupInactiveMembers = onSchedule({
  schedule: '0 4 * * *',
  timeZone: 'Asia/Tokyo',
  region: 'asia-northeast1',
}, () => cleanupService.cleanupInactiveMembers());
