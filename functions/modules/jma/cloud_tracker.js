/**
 * 雲の追跡
 *
 * 今回見つけた塊を、前回までの雲と結びつける。
 * - 前回の雲から15km以内なら同じ雲として追いかける（近い組み合わせから順に1対1で結ぶ）
 * - どの雲とも結びつかない塊は新しい雲
 * - 見えなくなった雲は、60分たつまでは「いまは見えない」まま残し、そのあいだに近くで
 *   また見つかれば同じ雲とする。60分たったら終わりにする（そのあと出た雲は別の雲）
 *
 * Firestore には触れず、何を書けばよいかだけを返す。
 */

const { JMA_NOWCAST } = require('../../constants');

const EARTH_RADIUS_KM = 6371;

/**
 * 2点間の距離 (km)
 */
function distanceKm(a, b) {
  const toRad = (deg) => (deg * Math.PI) / 180;
  const dLat = toRad(b.latitude - a.latitude);
  const dLon = toRad(b.longitude - a.longitude);
  const h = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.latitude)) * Math.cos(toRad(b.latitude)) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(h));
}

/**
 * @param {Array<{id:string,latitude:number,longitude:number,lastSeenAt:Date}>} activeClouds - 追跡中の雲
 * @param {Array<{latitude:number,longitude:number}>} clusters - 今回見つけた塊
 * @param {Date} observedAt - 今回の観測時刻（気象庁の解析時刻）
 * @returns {{updated: Array, created: Array, hidden: Array, ended: Array}}
 *   updated: 続いている雲 {id, cluster}
 *   created: 新しい雲 {cluster}
 *   hidden: いまは見えないが追跡を続ける雲 {id}
 *   ended: 終わりにする雲 {id}
 */
function trackClouds(activeClouds, clusters, observedAt) {
  const pairs = [];
  activeClouds.forEach((cloud, cloudIndex) => {
    clusters.forEach((cluster, clusterIndex) => {
      const distance = distanceKm(cloud, cluster);
      if (distance <= JMA_NOWCAST.TRACKING_DISTANCE_KM) {
        pairs.push({ cloudIndex, clusterIndex, distance });
      }
    });
  });
  pairs.sort((a, b) => a.distance - b.distance);

  const usedClouds = new Set();
  const usedClusters = new Set();
  const updated = [];
  for (const pair of pairs) {
    if (usedClouds.has(pair.cloudIndex) || usedClusters.has(pair.clusterIndex)) continue;
    usedClouds.add(pair.cloudIndex);
    usedClusters.add(pair.clusterIndex);
    updated.push({ id: activeClouds[pair.cloudIndex].id, cluster: clusters[pair.clusterIndex] });
  }

  const created = clusters
    .filter((_, index) => !usedClusters.has(index))
    .map((cluster) => ({ cluster }));

  const hidden = [];
  const ended = [];
  activeClouds.forEach((cloud, index) => {
    if (usedClouds.has(index)) return;
    const unseenMs = observedAt.getTime() - cloud.lastSeenAt.getTime();
    if (unseenMs >= JMA_NOWCAST.CLOUD_EXPIRE_MS) {
      ended.push({ id: cloud.id });
    } else {
      hidden.push({ id: cloud.id });
    }
  });

  return { updated, created, hidden, ended };
}

module.exports = { distanceKm, trackClouds };
