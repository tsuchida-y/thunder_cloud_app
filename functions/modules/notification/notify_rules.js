/**
 * v2.0 の通知のルールで、いまこの人に知らせるかを決める
 *
 * - 1つの雲には1回だけ
 * - 通知と通知のあいだは30分以上、1日（日本時間）3回まで
 * - 空が暗いあいだ（市民薄明の終わりから次のはじまりまで。sun_times.js）と、その人が決めた「通知しない時間」は鳴らさない
 * - アプリを開いてから10分以内の人には送らない
 * - 範囲は無料 30km、Plus 90km。60km より遠い雲は「見えるかもしれません」
 * - 見張る場所で雨が降っていたら（雲の下か曇り空なので）その場所では知らせない
 * - 見張る場所の空が一面の曇り（アメダスの日照）なら、その場所では知らせない
 * - 見張る場所の視程（アメダス）より遠い雲は、かすんで見えないので知らせない
 * - 雲のいちばん近い所が10kmより近い雲は、真下か近すぎて形が見えないので知らせない
 *   （1つの雲に1回なので、離れてから知らせる）
 *
 * Firestore には触れず、渡された値だけで決める（データの持ち方が変わってもそのまま使えるように）。
 */

const { NOTIFY_RULES } = require('../../constants');
const { describeCloud, nearestDistanceKm, directionName, fistsLabel } = require('../geo/sky_geometry');
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
 * @param {Array<{label:string,latitude:number,longitude:number,raining?:boolean,overcast?:boolean,
 *   visibilityKm?:number|null}>} params.watchPoints
 *   - 見張る場所。raining はいま雨が降っているか、overcast は一面の曇りか、visibilityKm は見通せる距離（null は制限なし）
 * @param {boolean} params.isPlus
 * @param {number} [params.rangeKm] - 設定の範囲（Plus でなければ 30km に抑える）
 * @param {{startMinutes:number,endMinutes:number}|null} [params.quietHours]
 * @param {Date|null} [params.lastOpenedAt]
 * @param {Object} params.history - {notifiedCloudIds, lastNotifiedAt, dailyCount, dailyDate}
 * @param {Array<{id:string,latitude:number,longitude:number,isVisible:boolean,edgePoints?:Array}>} params.clouds
 *   - edgePoints は雲のふちの点（いちばん近い所までの距離に使う）
 * @returns {{notify: Object, candidates: Array}|{skip: string, candidates?: Array}}
 *   知らせるときは雲と見え方、知らせないときは理由。candidates は、範囲内にあった雲ごとの見え方と、知らせなかった理由
 *   （通知の記録に残して、しきい値の調整に使う。reason が null の雲は、条件を全部通った雲）
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

  const notified = new Set(history.notifiedCloudIds || []);
  // 範囲内の雲ごとの見え方（記録用。いちばん近い見張る場所から見たもの）
  const inRange = [];
  for (const cloud of clouds) {
    if (!cloud.isVisible || notified.has(cloud.id)) continue;
    for (const point of daytimePoints) {
      const view = describeCloud(point, cloud);
      if (view.distanceKm > rangeKm) continue;
      inRange.push({ cloud, point, view, nearestEdgeKm: nearestDistanceKm(point, cloud), reason: null });
    }
  }
  const candidates = nearestPerCloud(inRange);

  // 雨の降っている場所は雲の下か曇り空で、入道雲の形が見えない
  const dryPoints = daytimePoints.filter((p) => !p.raining);
  if (dryPoints.length === 0) return { skip: 'raining_here', candidates };
  // 一面の曇り空も、入道雲は雲に隠れて見えない
  const openPoints = dryPoints.filter((p) => !p.overcast);
  if (openPoints.length === 0) return { skip: 'overcast_here', candidates };

  let best = null;
  let tooClose = false;
  let lowElevation = false;
  let hazy = false;
  for (const item of inRange) {
    if (!openPoints.includes(item.point)) {
      item.reason = item.point.raining ? 'raining_here' : 'overcast_here';
      continue;
    }
    const { cloud, point, view } = item;
    if (typeof point.visibilityKm === 'number' && view.distanceKm > point.visibilityKm) {
      hazy = true;
      item.reason = 'beyond_visibility';
      continue;
    }
    if (item.nearestEdgeKm < NOTIFY_RULES.MIN_DISTANCE_KM) {
      tooClose = true;
      item.reason = 'too_close';
      continue;
    }
    // てっぺんを見上げる角度が低い雲は、水平線のすぐ上の小さなふくらみで、山やもやに隠れて見えない
    if (view.elevationDeg < NOTIFY_RULES.MIN_ELEVATION_DEG) {
      lowElevation = true;
      item.reason = 'low_elevation';
      continue;
    }
    if (!best || view.distanceKm < best.view.distanceKm) {
      best = { cloud, point, view, maybeVisible: view.distanceKm > NOTIFY_RULES.MAYBE_VISIBLE_KM };
    }
  }
  const result = nearestPerCloud(inRange);
  if (best) return { notify: best, candidates: result };
  if (tooClose) return { skip: 'too_close', candidates: result };
  if (lowElevation) return { skip: 'low_elevation', candidates: result };
  return { skip: hazy ? 'beyond_visibility' : 'no_cloud_in_range', candidates: result };
}

/**
 * 同じ雲を複数の見張る場所から見ているとき、いちばん近い場所から見たものだけにして、近い順に並べる（最大10個）
 */
function nearestPerCloud(items) {
  const byCloud = new Map();
  for (const item of items) {
    const previous = byCloud.get(item.cloud.id);
    if (!previous || item.view.distanceKm < previous.view.distanceKm) byCloud.set(item.cloud.id, item);
  }
  return [...byCloud.values()].sort((a, b) => a.view.distanceKm - b.view.distanceKm).slice(0, 10);
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

function appearedMessage(view, pointLabel = null, lang = 'ja') {
  const km = Math.round(view.distanceKm);
  if (lang === 'en') return appearedMessageEn(view, pointLabel, km);
  // 登録した場所の雲は「家の北の空に」のように場所の名前を付ける（場所の見せ方_画面一覧.png の「通知（場所名つき）」）
  const place = pointLabel && pointLabel !== CURRENT_PLACE_LABEL ? `${pointLabel}の` : '';
  const title = `${place}${view.directionName}の空に、入道雲が現れました`;
  const body = view.distanceKm > NOTIFY_RULES.MAYBE_VISIBLE_KM
    ? `約${km}km先なので、見えるかもしれません。${view.fistsLabel}の高さを見上げてみて。`
    : `約${km}km先。${view.fistsLabel}の高さを見上げてみて。`;
  return { title, body };
}

/** 英語の通知の文面（端末の言語が英語の人。members.locale が 'en'） */
function appearedMessageEn(view, pointLabel, km) {
  const direction = directionName(view.bearingDeg, 'en');
  const fists = fistsLabel(view.fists, 'en');
  const place = pointLabel && pointLabel !== CURRENT_PLACE_LABEL ? ` of ${pointLabel}` : '';
  const title = `A thunderhead appeared to the ${direction}${place}`;
  const body = view.distanceKm > NOTIFY_RULES.MAYBE_VISIBLE_KM
    ? `About ${km} km away, so it may be visible. Look up about ${fists} high.`
    : `About ${km} km away. Look up about ${fists} high.`;
  return { title, body };
}

module.exports = {
  jstDateKey,
  isInQuietHours,
  decideNotification,
  nextHistory,
  appearedMessage,
};
