/**
 * v2.0 の通知のルールで、いまこの人に知らせるかを決める
 *
 * - 1つの雲には1回だけ
 * - 通知と通知のあいだは30分以上、1日（日本時間）3回まで
 * - 空が暗いあいだ（市民薄明の終わりから次のはじまりまで。sun_times.js）と、その人が決めた「通知しない時間」は鳴らさない
 * - アプリを開いてから10分以内の人には送らない
 * - 範囲は無料 30km、Plus 90km。60km より遠い雲は「見えるかもしれません」
 * - 見張る場所で雨が降っていたら（雲の下か曇り空なので）その場所では知らせない
 * - 雲のいちばん近い所が10kmより近い雲は、真下か近すぎて形が見えないので知らせない
 *   （1つの雲に1回なので、離れてから知らせる）
 *
 * Firestore には触れず、渡された値だけで決める（データの持ち方が変わってもそのまま使えるように）。
 */

const { NOTIFY_RULES } = require('../../constants');
const { describeCloud, nearestDistanceKm } = require('../geo/sky_geometry');
const { isDaytime } = require('../geo/sun_times');

/**
 * 日本時間の日付 "YYYY-MM-DD"
 */
function jstDateKey(date) {
  return new Date(date.getTime() + NOTIFY_RULES.JST_OFFSET_MS).toISOString().slice(0, 10);
}

/**
 * 日本時間の 0:00 からの分
 */
function jstMinutesOfDay(date) {
  const jst = new Date(date.getTime() + NOTIFY_RULES.JST_OFFSET_MS);
  return jst.getUTCHours() * 60 + jst.getUTCMinutes();
}

/**
 * 「通知しない時間」に入っているか（22:00〜6:00 のように日をまたぐ指定にも対応）
 *
 * @param {{startMinutes:number,endMinutes:number}|null} quietHours - 日本時間の 0:00 からの分
 */
function isInQuietHours(now, quietHours) {
  if (!quietHours) return false;
  const { startMinutes, endMinutes } = quietHours;
  if (startMinutes === endMinutes) return false;
  const minutes = jstMinutesOfDay(now);
  return startMinutes < endMinutes
    ? minutes >= startMinutes && minutes < endMinutes
    : minutes >= startMinutes || minutes < endMinutes;
}

/**
 * @param {Object} params
 * @param {Date} params.now
 * @param {Array<{label:string,latitude:number,longitude:number,raining?:boolean}>} params.watchPoints
 *   - 見張る場所。raining はいまその場所で雨が降っているか
 * @param {boolean} params.isPlus
 * @param {number} [params.rangeKm] - 設定の範囲（Plus でなければ 30km に抑える）
 * @param {{startMinutes:number,endMinutes:number}|null} [params.quietHours]
 * @param {Date|null} [params.lastOpenedAt]
 * @param {Object} params.history - {notifiedCloudIds, lastNotifiedAt, dailyCount, dailyDate}
 * @param {Array<{id:string,latitude:number,longitude:number,isVisible:boolean,edgePoints?:Array}>} params.clouds
 *   - edgePoints は雲のふちの点（いちばん近い所までの距離に使う）
 * @returns {{notify: Object}|{skip: string}} 知らせるときは雲と見え方、知らせないときは理由
 */
function decideNotification(params) {
  const { now, watchPoints, isPlus, quietHours = null, lastOpenedAt = null, history = {}, clouds } = params;
  const rangeKm = isPlus
    ? Math.min(params.rangeKm || NOTIFY_RULES.PLUS_RANGE_KM, NOTIFY_RULES.PLUS_RANGE_KM)
    : NOTIFY_RULES.FREE_RANGE_KM;

  if (!watchPoints || watchPoints.length === 0) return { skip: 'no_location' };
  if (isInQuietHours(now, quietHours)) return { skip: 'quiet_hours' };
  if (lastOpenedAt && now.getTime() - lastOpenedAt.getTime() < NOTIFY_RULES.RECENTLY_OPENED_MS) {
    return { skip: 'recently_opened' };
  }
  if (history.lastNotifiedAt && now.getTime() - history.lastNotifiedAt.getTime() < NOTIFY_RULES.MIN_INTERVAL_MS) {
    return { skip: 'interval' };
  }
  const todayCount = history.dailyDate === jstDateKey(now) ? (history.dailyCount || 0) : 0;
  if (todayCount >= NOTIFY_RULES.DAILY_LIMIT) return { skip: 'daily_limit' };

  // 夜の場所は見張らない
  const daytimePoints = watchPoints.filter((p) => isDaytime(now, p.latitude, p.longitude));
  if (daytimePoints.length === 0) return { skip: 'night' };

  // 雨の降っている場所は雲の下か曇り空で、入道雲の形が見えない
  const dryPoints = daytimePoints.filter((p) => !p.raining);
  if (dryPoints.length === 0) return { skip: 'raining_here' };

  const notified = new Set(history.notifiedCloudIds || []);
  let best = null;
  let tooClose = false;
  for (const cloud of clouds) {
    if (!cloud.isVisible || notified.has(cloud.id)) continue;
    for (const point of dryPoints) {
      const view = describeCloud(point, cloud);
      if (view.distanceKm > rangeKm) continue;
      if (nearestDistanceKm(point, cloud) < NOTIFY_RULES.MIN_DISTANCE_KM) {
        tooClose = true;
        continue;
      }
      if (!best || view.distanceKm < best.view.distanceKm) {
        best = { cloud, point, view, maybeVisible: view.distanceKm > NOTIFY_RULES.MAYBE_VISIBLE_KM };
      }
    }
  }
  if (best) return { notify: best };
  return { skip: tooClose ? 'too_close' : 'no_cloud_in_range' };
}

/**
 * 知らせたあとの記録（次の判定に渡す history）を作る
 */
function nextHistory(history, cloudId, now) {
  const today = jstDateKey(now);
  return {
    // 雲は見えなくなって60分で終わるので、直近の分だけ覚えておけば足りる
    notifiedCloudIds: [...(history.notifiedCloudIds || []), cloudId].slice(-50),
    lastNotifiedAt: now,
    dailyDate: today,
    dailyCount: (history.dailyDate === today ? history.dailyCount || 0 : 0) + 1,
  };
}

/**
 * 「現れました」の通知の文面（docs/design/Notify.html の文言）
 */
/** いまいる場所の見張りの名前（cloud_watch_service.js の watchPointsOf と同じ） */
const CURRENT_PLACE_LABEL = 'いまいる場所';

function appearedMessage(view, pointLabel = null) {
  const km = Math.round(view.distanceKm);
  // 登録した場所の雲は「家の北の空に」のように場所の名前を付ける（場所の見せ方_画面一覧.png の「通知（場所名つき）」）
  const place = pointLabel && pointLabel !== CURRENT_PLACE_LABEL ? `${pointLabel}の` : '';
  const title = `${place}${view.directionName}の空に、入道雲が現れました`;
  const body = view.distanceKm > NOTIFY_RULES.MAYBE_VISIBLE_KM
    ? `約${km}km先なので、見えるかもしれません。${view.fistsLabel}の高さを見上げてみて。`
    : `約${km}km先。${view.fistsLabel}の高さを見上げてみて。`;
  return { title, body };
}

module.exports = {
  jstDateKey,
  isInQuietHours,
  decideNotification,
  nextHistory,
  appearedMessage,
};
