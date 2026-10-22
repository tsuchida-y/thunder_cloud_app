/**
 * 雲の見張りと通知（v2.0）
 *
 * 雲の一覧（clouds）が新しくなるたびに、利用者（members）ごとに見張る場所から雲を調べ、
 * 通知のルール（notify_rules.js）に合えば「現れました」を送る。
 *
 * - 見張る場所: 無料は「いまいる場所」（なければ登録した1か所目）、Plus は「いまいる場所」＋登録した場所3か所まで
 * - いまいる場所は、最後にアプリが送ってきた位置。「常に」の許可がない人は、最後に開いた場所になる
 * - Plus かどうかと通知の記録は member_server にある（サーバーだけが書く）
 * - 見張る場所でいま雨が降っているかは、雲を探したときのタイルから調べる（rain_lookup.js）
 * - 見張る場所の空が一面の曇りか、どこまで見通せるかは、アメダスから調べる（sky_observations.js）
 */

const admin = require('firebase-admin');
const NotificationService = require('../notification/notification_service');
const { decideNotification, nextHistory, appearedMessage } = require('../notification/notify_rules');
const { isOvercast, visibilityKmNear } = require('../jma/sky_observations');
const { COLLECTIONS, JMA_NOWCAST, NOTIFY_RULES } = require('../../constants');

/**
 * Plus かどうか（期限つき。期限がなければ Plus のまま）
 */
function isPlusActive(server, now) {
  if (!server || !server.isPlus) return false;
  const expiresAt = server.plusExpiresAt ? server.plusExpiresAt.toDate() : null;
  return !expiresAt || expiresAt > now;
}

/**
 * 見張る場所の一覧
 */
function watchPointsOf(member, isPlus) {
  const points = [];
  if (member.location && typeof member.location.latitude === 'number') {
    points.push({ label: 'いまいる場所', latitude: member.location.latitude, longitude: member.location.longitude });
  }
  const places = (member.places || []).filter((p) => typeof p.latitude === 'number');
  if (isPlus) {
    places.slice(0, NOTIFY_RULES.PLUS_MAX_PLACES).forEach((p) => points.push(p));
  } else if (points.length === 0 && places.length > 0) {
    points.push(places[0]);
  }
  return points;
}

const toDate = (value) => (value && typeof value.toDate === 'function' ? value.toDate() : value || null);

class CloudWatchService {
  constructor(notificationService = new NotificationService()) {
    this.notifications = notificationService;
  }

  get firestore() {
    return admin.firestore();
  }

  /**
   * いまの雲の一覧で全員を調べ、知らせる人に通知を送る
   *
   * @param {Date} now
   * @param {Object} [sky] - 雲を探したときに取った観測（nowcast_service.js の updateClouds の戻り値）
   * @param {import('../jma/rain_lookup').RainLookup|null} [sky.rainLookup] - なければ雨は調べない
   * @param {Array|null} [sky.amedasStations] - なければ曇りと視程は調べない
   * @returns {Promise<{checked:number, sent:number, skipped:Object<string,number>}>}
   */
  async run(now = new Date(), { rainLookup = null, amedasStations = null } = {}) {
    const cloudSnap = await this.firestore.collection(JMA_NOWCAST.CLOUDS_COLLECTION)
      .where('status', '==', 'active').get();
    const clouds = cloudSnap.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((c) => c.isVisible)
      .map((c) => ({
        id: c.id,
        latitude: c.center.latitude,
        longitude: c.center.longitude,
        edgePoints: c.edgePoints || [],
        topHeightKm: typeof c.topHeightKm === 'number' ? c.topHeightKm : null,
        isVisible: true,
      }));

    const summary = { checked: 0, sent: 0, skipped: {} };
    if (clouds.length === 0) {
      console.log('👀 [CLOUD_WATCH] いま見えている雲はありません');
      return summary;
    }

    const [memberSnap, serverSnap] = await Promise.all([
      this.firestore.collection(COLLECTIONS.MEMBERS).get(),
      this.firestore.collection(COLLECTIONS.MEMBER_SERVER).get(),
    ]);
    const servers = new Map(serverSnap.docs.map((doc) => [doc.id, doc.data()]));
    const isRaining = this._rainChecker(rainLookup);

    for (const memberDoc of memberSnap.docs) {
      const member = memberDoc.data();
      if (!member.fcmToken || member.settings?.notifyAppeared === false) continue;
      summary.checked++;

      const server = servers.get(memberDoc.id) || {};
      const isPlus = isPlusActive(server, now);
      const history = server.notification || {};
      const watchPoints = await Promise.all(watchPointsOf(member, isPlus)
        .map(async (p) => ({
          ...p,
          raining: await isRaining(p),
          overcast: amedasStations ? isOvercast(amedasStations, p, now) : false,
          visibilityKm: amedasStations ? visibilityKmNear(amedasStations, p) : null,
        })));
      const decision = decideNotification({
        now,
        watchPoints,
        isPlus,
        rangeKm: member.settings?.rangeKm,
        quietHours: member.settings?.quietHours || null,
        lastOpenedAt: toDate(member.lastOpenedAt),
        history: { ...history, lastNotifiedAt: toDate(history.lastNotifiedAt) },
        clouds,
      });
      if (decision.skip) {
        summary.skipped[decision.skip] = (summary.skipped[decision.skip] || 0) + 1;
        continue;
      }

      const sent = await this._send(memberDoc.id, member, decision.notify, server, now);
      if (sent) summary.sent++;
    }

    console.log(`📣 [CLOUD_WATCH] 雲${clouds.length}個、調べた人${summary.checked}人、通知${summary.sent}件、` +
      `送らなかった理由 ${JSON.stringify(summary.skipped)}`);
    return summary;
  }

  /**
   * 見張る場所で雨が降っているかを返す関数を作る（同じ場所は1回だけ調べる）
   *
   * 気象庁のタイルが取れなかったときは、雨なしとして今までどおり知らせる（通知が止まるよりよいため）
   */
  _rainChecker(rainLookup) {
    if (!rainLookup) return async () => false;
    const cache = new Map();
    let warned = false;
    return (point) => {
      const key = `${point.latitude.toFixed(3)},${point.longitude.toFixed(3)}`;
      if (!cache.has(key)) {
        cache.set(key, rainLookup.isRaining(point.latitude, point.longitude).catch((error) => {
          if (!warned) {
            console.warn('⚠️ [CLOUD_WATCH] 見張る場所の雨を調べられませんでした（雨なしとして続けます）:', error);
            warned = true;
          }
          return false;
        }));
      }
      return cache.get(key);
    };
  }

  async _send(uid, member, { cloud, point, view }, server, now) {
    const message = appearedMessage(view, point.label);
    const result = await this.notifications.sendCloudNotification(member.fcmToken, message, {
      type: 'cloud_appeared',
      // アプリが「見えた」「見えなかった」の答えをどの雲に結びつけるかに使う
      cloudId: cloud.id,
      directionName: view.directionName,
      bearingDeg: view.bearingDeg.toFixed(1),
      distanceKm: view.distanceKm.toFixed(1),
      elevationDeg: view.elevationDeg.toFixed(1),
      fists: view.fists,
      cloudLatitude: cloud.latitude.toFixed(4),
      cloudLongitude: cloud.longitude.toFixed(4),
      pointLabel: point.label || '',
      notifiedAt: now.toISOString(),
    }, cloud.id);

    if (result.invalidToken) {
      // アプリを消した人などは、次に開いたときに新しいトークンが届くまで送らない
      await this.firestore.collection(COLLECTIONS.MEMBERS).doc(uid).update({
        fcmToken: null,
        fcmTokenInvalidAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return false;
    }
    if (!result.ok) return false;

    const next = nextHistory(server.notification || {}, cloud.id, now);
    const update = {
      notification: { ...next, lastNotifiedAt: admin.firestore.Timestamp.fromDate(next.lastNotifiedAt) },
    };
    if (!server.firstNotifiedAt) {
      // 「移動先も見張るお願い」は最初の通知のあとに1回だけ出すので、アプリが分かるように残す
      update.firstNotifiedAt = admin.firestore.Timestamp.fromDate(now);
    }
    await this.firestore.collection(COLLECTIONS.MEMBER_SERVER).doc(uid).set(update, { merge: true });
    return true;
  }
}

module.exports = { CloudWatchService, isPlusActive, watchPointsOf };
