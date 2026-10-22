/**
 * 本物の雲がなくても、通知と方角ガイドを実機で試すための「試しの通知」を送る
 *
 * 使い方: functions フォルダで
 *   npm run test:notify                     … 岩手山に雲があることにして送る
 *   npm run test:notify -- 39.70 141.15     … 緯度・経度を指定した所に雲があることにして送る
 *
 * - 宛先は members で通知のトークンを持っている人。2人以上いるときは送らずに止まる（ほかの人に送らないため）
 * - 方角・距離・見上げる高さは、その人の「いまいる場所」から本物の通知と同じ計算で出す
 *   （目印になる山などを雲の場所にすると、方角ガイドがそちらを指すかを確かめられる）
 * - 雲の ID は test_ で始まる。「見えた」「見えなかった」を押すと reports に test_ の答えが残る
 * - 通知の記録（member_server）は書かないので、本物の通知の回数や間隔には影響しない
 *
 * 手元から本番の Firestore と通知を使うので、先に `gcloud auth application-default login` が要る。
 */

const admin = require('firebase-admin');
const NotificationService = require('../modules/notification/notification_service');
const { describeCloud } = require('../modules/geo/sky_geometry');
const { appearedMessage } = require('../modules/notification/notify_rules');
const { COLLECTIONS } = require('../constants');

// 岩手山の山頂
const DEFAULT_CLOUD = { latitude: 39.8525, longitude: 141.0011 };

(async () => {
  admin.initializeApp({ projectId: 'thunder-cloud-app-292e6' });
  const [lat, lng] = process.argv.slice(2).map(Number);
  const cloud = Number.isFinite(lat) && Number.isFinite(lng) ? { latitude: lat, longitude: lng } : DEFAULT_CLOUD;

  const snap = await admin.firestore().collection(COLLECTIONS.MEMBERS).where('fcmToken', '!=', null).get();
  if (snap.size !== 1) {
    console.error(`通知のトークンを持っている人が ${snap.size} 人います。1人のときだけ送ります。`);
    process.exitCode = 1;
    return;
  }
  const memberDoc = snap.docs[0];
  const member = memberDoc.data();
  if (!member.location || typeof member.location.latitude !== 'number') {
    console.error('いまいる場所がまだ届いていません。アプリを一度開いてから試してください。');
    process.exitCode = 1;
    return;
  }

  const view = describeCloud(member.location, cloud);
  const message = appearedMessage(view);
  const cloudId = `test_${Date.now()}`;
  const result = await new NotificationService().sendCloudNotification(member.fcmToken, message, {
    type: 'cloud_appeared',
    cloudId,
    directionName: view.directionName,
    bearingDeg: view.bearingDeg.toFixed(1),
    distanceKm: view.distanceKm.toFixed(1),
    elevationDeg: view.elevationDeg.toFixed(1),
    fists: view.fists,
    cloudLatitude: cloud.latitude.toFixed(4),
    cloudLongitude: cloud.longitude.toFixed(4),
    pointLabel: '',
    notifiedAt: new Date().toISOString(),
  }, cloudId);

  console.log(`${result.ok ? '送りました' : '送れませんでした'}: 「${message.title}」${message.body}`);
  console.log(`方角 ${view.bearingDeg.toFixed(0)}°（${view.directionName}）、約${view.distanceKm.toFixed(1)}km、` +
    `見上げる高さ ${view.elevationDeg.toFixed(1)}°、雲の ID ${cloudId}`);
  if (!result.ok) process.exitCode = 1;
})().catch((error) => {
  console.error('失敗しました:', error.message);
  process.exitCode = 1;
});
