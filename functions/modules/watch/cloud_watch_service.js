/**
 * 雲の見張りと通知（v2.0）
 *
 * 雲の一覧（clouds）が新しくなるたびに、利用者（members）ごとに見張る場所から雲を調べ、
 * 通知のルール（notify_rules.js）に合えば「現れました」を送る。
 *
 * - 見張る場所: 「いまいる場所」＋登録した場所（無料は1か所、Plus は3か所まで。2026-10-27 に無料でも1か所にした）
 * - いまいる場所は、最後にアプリが送ってきた位置。「常に」の許可がない人は、最後に開いた場所になる
 * - Plus かどうかと通知の記録は member_server にある（サーバーだけが書く）
 * - 見張る場所でいま雨が降っているかは、雲を探したときのタイルから調べる（rain_lookup.js）
 * - 見張る場所の空が一面の曇りか（ひまわりの雲の量とアメダスの日照）、どこまで見通せるか（アメダスの視程）は、
 *   sky_observations.js で調べる
 * - 判断に使った数字は、通知の記録（notification_log）に残す。しきい値を、「見えた」「見えなかった」の答えと
 *   突き合わせて調整するため（docs/検知の見直し案_2026-11-02.md の案D）
 */

const admin = require('firebase-admin');
const NotificationService = require('../notification/notification_service');
const { decideNotification, nextHistory, appearedMessage } = require('../notification/notify_rules');
const { assessSky, visibilityKmNear } = require('../jma/sky_observations');
const {
  COLLECTIONS, JMA_NOWCAST, NOTIFY_RULES, NOTIFICATION_LOG_RETENTION_DAYS, SKY_NOW,
} = require('../../constants');

/** 判断の記録の、しきい値の組の名前（しきい値を変えたら、この名前も変えて、記録を見分けられるようにする） */
const RULES_VERSION = 'detect-2026-11-02';

const round = (value, digits = 1) => {
  if (typeof value !== 'number') return null;
  return Math.round(value * 10 ** digits) / 10 ** digits;
};

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
  const maxPlaces = isPlus ? NOTIFY_RULES.PLUS_MAX_PLACES : NOTIFY_RULES.FREE_MAX_PLACES;
  places.slice(0, maxPlaces).forEach((p) => points.push(p));
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
   * @param {{images:Map, validtime:string, ensureAround:function}|null} [sky.infrared] - ひまわりの赤外画像（雲の量に使う）
   * @param {{rain:string, thunder:string}|null} [sky.times] - ナウキャストの解析時刻（記録用）
   * @param {string|null} [sky.amedasTime] - アメダスの観測時刻（記録用）
   * @returns {Promise<{checked:number, sent:number, skipped:Object<string,number>}>}
   */
  async run(now = new Date(), {
    rainLookup = null, amedasStations = null, infrared = null, times = null, amedasTime = null,
  } = {}) {
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
        // 判断の記録に残す
        topTempC: typeof c.topTempC === 'number' ? c.topTempC : null,
        areaKm2: typeof c.areaKm2 === 'number' ? c.areaKm2 : null,
        pixelCount: typeof c.pixelCount === 'number' ? c.pixelCount : null,
        maxRainMmPerHour: typeof c.maxRainMmPerHour === 'number' ? c.maxRainMmPerHour : null,
        maxThunderLevel: typeof c.maxThunderLevel === 'number' ? c.maxThunderLevel : null,
        isVisible: true,
      }));

    const summary = { checked: 0, sent: 0, skipped: {} };
    if (clouds.length === 0) {
      console.log('👀 [CLOUD_WATCH] いま見えている雲はありません');
      return summary;
    }

    // 読み取りの回数（料金）を減らすため、通知の宛先がある人だけを読み、member_server もその人の分だけ読む
    const memberSnap = await this.firestore.collection(COLLECTIONS.MEMBERS).where('fcmToken', '!=', null).get();
    const targets = memberSnap.docs.filter((doc) => {
      const member = doc.data();
      return member.fcmToken && member.settings?.notifyAppeared !== false;
    });
    const servers = await this._readServers(targets.map((doc) => doc.id));
    const isRaining = this._rainChecker(rainLookup);

    const prepared = targets.map((memberDoc) => {
      const member = memberDoc.data();
      const server = servers.get(memberDoc.id) || {};
      const isPlus = isPlusActive(server, now);
      return { memberDoc, member, server, isPlus, points: watchPointsOf(member, isPlus) };
    });
    // 見張る場所のまわりの雲の量に使う赤外画像のタイルを、足りない分だけ取り足す（取れなければ日照だけで決める）
    if (infrared) {
      try {
        await infrared.ensureAround(prepared.flatMap((item) => item.points));
      } catch (error) {
        console.warn('⚠️ [CLOUD_WATCH] 見張る場所のまわりの赤外画像を取れませんでした（日照だけで決めます）:', error);
      }
    }
    const images = infrared ? infrared.images : null;
    const dataTimes = {
      nowcast: times && times.rain ? times.rain : null,
      himawari: infrared && infrared.validtime ? infrared.validtime : null,
      amedas: amedasTime || null,
    };

    for (const { memberDoc, member, server, isPlus, points } of prepared) {
      summary.checked++;
      const history = server.notification || {};
      const watchPoints = await Promise.all(points.map(async (p) => {
        const sky = assessSky({ stations: amedasStations, point: p, now, images });
        return {
          ...p,
          raining: await isRaining(p),
          overcast: sky.overcast,
          sky,
          visibilityKm: amedasStations ? visibilityKmNear(amedasStations, p) : null,
        };
      }));
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

      let sent = false;
      if (decision.notify) {
        sent = await this._send(memberDoc.id, member, decision.notify, server, now);
        if (sent) summary.sent++;
      } else {
        summary.skipped[decision.skip] = (summary.skipped[decision.skip] || 0) + 1;
      }
      // 判断の記録と、ホームに渡す空のようすは、通知を止めたり遅らせたりしないよう、失敗しても続ける
      try {
        await this._logDecision(memberDoc.id, server, decision, sent, dataTimes, now);
      } catch (error) {
        console.warn('⚠️ [CLOUD_WATCH] 通知の判断を記録できませんでした:', error);
      }
      try {
        await this._writeSkyNow(memberDoc.id, server, watchPoints, now);
      } catch (error) {
        console.warn('⚠️ [CLOUD_WATCH] 空のようすを書けませんでした:', error);
      }
    }

    console.log(`📣 [CLOUD_WATCH] 雲${clouds.length}個、調べた人${summary.checked}人、通知${summary.sent}件、` +
      `送らなかった理由 ${JSON.stringify(summary.skipped)}`);
    return summary;
  }

  /**
   * 通知の判断に使った数字を、notification_log に残す（案D）
   *
   * 範囲内にあった雲ごとに1件。同じ雲で同じ判断（通知した、止めた理由）は、2回目から書かない
   * （member_server.notification.loggedDecisions に覚えておく）。位置は約1kmに丸めた値だけ。
   */
  async _logDecision(uid, server, decision, sent, dataTimes, now) {
    const candidates = decision.candidates || [];
    if (candidates.length === 0) return;
    const chosenId = decision.notify ? decision.notify.cloud.id : null;
    const logged = new Set((server.notification && server.notification.loggedDecisions) || []);
    const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(now.getTime() + NOTIFICATION_LOG_RETENTION_DAYS * 24 * 60 * 60 * 1000));

    const fresh = [];
    for (const { cloud, point, view, nearestEdgeKm, reason } of candidates) {
      let name;
      if (cloud.id === chosenId) name = sent ? 'notified' : 'send_failed';
      else name = reason || decision.skip || 'not_chosen';
      const key = `${cloud.id}:${name}`;
      if (logged.has(key)) continue;
      const sky = point.sky || {};
      fresh.push({
        key,
        record: {
          uid,
          cloudId: cloud.id,
          decision: name,
          rulesVersion: RULES_VERSION,
          loggedAt: admin.firestore.Timestamp.fromDate(now),
          expiresAt,
          viewer: {
            isCurrentLocation: point.label === 'いまいる場所',
            latitude: round(point.latitude, 2),
            longitude: round(point.longitude, 2),
          },
          cloud: {
            topTempC: round(cloud.topTempC),
            topHeightKm: round(cloud.topHeightKm),
            areaKm2: round(cloud.areaKm2),
            pixelCount: cloud.pixelCount,
            maxRainMmPerHour: cloud.maxRainMmPerHour,
            maxThunderLevel: cloud.maxThunderLevel,
            distanceKm: round(view.distanceKm),
            nearestEdgeKm: round(nearestEdgeKm),
            bearingDeg: round(view.bearingDeg, 0),
            elevationDeg: round(view.elevationDeg),
          },
          sky: {
            overcast: Boolean(point.overcast),
            raining: Boolean(point.raining),
            visibilityKm: round(point.visibilityKm),
            surfaceTempC: round(sky.surfaceTempC),
            sunAltitudeDeg: sky.sun ? sky.sun.altitudeDeg : null,
            sunshineUsable: sky.sun ? sky.sun.usable : null,
            sunshineStations: sky.sun ? sky.sun.stations : null,
            sunshineAnyPositive: sky.sun ? sky.sun.anyPositive : null,
            sunshineAllZero: sky.sun ? sky.sun.allZero : null,
            coverFraction: sky.cover ? sky.cover.fraction : null,
            coverFractions: sky.cover ? sky.cover.fractions : null,
            coverMedianDeltaC: sky.cover ? sky.cover.medianDeltaC : null,
          },
          dataTimes,
        },
      });
    }
    if (fresh.length === 0) return;

    const batch = this.firestore.batch();
    fresh.forEach(({ record }) => batch.set(this.firestore.collection(COLLECTIONS.NOTIFICATION_LOG).doc(), record));
    await batch.commit();
    const next = [...logged, ...fresh.map(({ key }) => key)].slice(-60);
    await this.firestore.collection(COLLECTIONS.MEMBER_SERVER).doc(uid)
      .set({ notification: { loggedDecisions: next } }, { merge: true });
  }

  /**
   * 見張る場所ごとの空のようす（一面の曇り、雨、視程）を、アプリのホームが読めるように書く
   *
   * member_server/{uid}.skyNow = { updatedAt, points: [{key, overcast, raining, visibilityKm}] }
   * key は見張る場所の位置を小数第2位に丸めたもの（"39.78,141.13"）。変わったときと、30分たったときだけ書く。
   */
  async _writeSkyNow(uid, server, watchPoints, now) {
    if (watchPoints.length === 0) return;
    const points = watchPoints.map((p) => ({
      // アプリと同じ丸め方（×100 を四捨五入して÷100）。members の位置と登録した場所は、この丸めで保存されている
      key: `${round(p.latitude, 2).toFixed(2)},${round(p.longitude, 2).toFixed(2)}`,
      overcast: Boolean(p.overcast),
      raining: Boolean(p.raining),
      visibilityKm: round(p.visibilityKm),
    }));
    const signature = (list) => (list || [])
      .map((p) => `${p.key}|${p.overcast}|${p.raining}|${p.visibilityKm}`).sort().join(';');
    const previous = server.skyNow;
    const updatedAt = previous && previous.updatedAt && previous.updatedAt.toDate ? previous.updatedAt.toDate() : null;
    const fresh = updatedAt !== null && now.getTime() - updatedAt.getTime() < SKY_NOW.HEARTBEAT_MS;
    if (fresh && signature(previous.points) === signature(points)) return;
    await this.firestore.collection(COLLECTIONS.MEMBER_SERVER).doc(uid)
      .set({ skyNow: { updatedAt: admin.firestore.Timestamp.fromDate(now), points } }, { merge: true });
  }

  /**
   * 指定した人の member_server を読んで、uid から中身を引ける Map にする
   */
  async _readServers(uids) {
    const servers = new Map();
    const CHUNK = 300;
    for (let i = 0; i < uids.length; i += CHUNK) {
      const refs = uids.slice(i, i + CHUNK).map((id) => this.firestore.collection(COLLECTIONS.MEMBER_SERVER).doc(id));
      const snaps = await this.firestore.getAll(...refs);
      snaps.forEach((snap) => {
        if (snap.exists) servers.set(snap.id, snap.data());
      });
    }
    return servers;
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
