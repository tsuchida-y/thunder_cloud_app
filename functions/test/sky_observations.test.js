const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  grayToTempC,
  coldestTopTempC,
  topHeightKm,
  isTallEnough,
  surfaceTempNear,
  isOvercast,
  sunMinutesAbove,
  nearbySunshine,
  cloudCover,
  assessSky,
  visibilityKmNear,
} = require('../modules/jma/sky_observations');
const { latLngToPixel } = require('../modules/jma/rain_lookup');

const morioka = { latitude: 39.70, longitude: 141.15 };
// 盛岡の夏の昼（太陽は十分高い）と、日の入りの直前（前の1時間のほとんどで太陽が低い）
const summerNoon = new Date('2026-08-12T12:30:00+09:00');
const summerEvening = new Date('2026-08-12T18:30:00+09:00');

test('赤外画像の明るさを温度にする（白いほど冷たい）', () => {
  assert.equal(Math.round(grayToTempC(38)), 25);
  assert.equal(Math.round(grayToTempC(225)), -73);
  assert.ok(grayToTempC(150) < grayToTempC(100));
});

test('塊のまわり（衛星から斜めに見るずれの分）までで、いちばん冷たいてっぺんを探す', () => {
  const data = new Uint8Array(256 * 256 * 4).fill(40);
  // 塊の四角から北へ5ピクセルの所に冷たい雲
  const set = (x, y, gray) => data.fill(gray, (y * 256 + x) * 4, (y * 256 + x) * 4 + 4);
  set(100, 95, 210);
  const images = new Map([['3,7', { width: 256, height: 256, data }]]);
  const bounds = { minX: 3 * 256 + 98, maxX: 3 * 256 + 102, minY: 7 * 256 + 100, maxY: 7 * 256 + 104 };
  assert.equal(coldestTopTempC(bounds, images), grayToTempC(210));
  // 画像がなければ null
  assert.equal(coldestTopTempC(bounds, new Map()), null);
});

test('てっぺんの高さは地上の気温との差から見積もり、6〜16km に収める', () => {
  assert.equal(topHeightKm(-35, 30), 10);
  assert.equal(topHeightKm(-100, 30), 16);
  assert.equal(topHeightKm(10, 25), 6);
  assert.equal(isTallEnough(-25), true);
  assert.equal(isTallEnough(-5), false);
  assert.equal(isTallEnough(null), true);
});

test('地上の気温は近くのアメダスから（なければ25℃）', () => {
  const stations = [{ latitude: 39.70, longitude: 141.17, tempC: 31.2 }, { latitude: 35, longitude: 139, tempC: 20 }];
  assert.equal(surfaceTempNear(stations, morioka), 31.2);
  assert.equal(surfaceTempNear([], morioka), 25);
});

test('近くのアメダスがどこも1時間日が差していなければ一面の曇り', () => {
  const near = (sun1h) => ({ latitude: 39.72, longitude: 141.14, sun1h });
  const far = (sun1h) => ({ latitude: 39.90, longitude: 141.40, sun1h });
  assert.equal(isOvercast([near(0), { ...near(0), latitude: 39.65 }], morioka, summerNoon), true);
  // 1地点でも日が差していれば曇りとしない（雲の影に入っただけのこともある）
  assert.equal(isOvercast([near(0), { ...near(0.4), latitude: 39.65 }], morioka, summerNoon), false);
  // 20km より遠い地点しかなければ判定しない
  assert.equal(isOvercast([far(0)], morioka, summerNoon), false);
  // 前の1時間のほとんどで太陽が低い時間は、晴れていても日照なしになるので判定しない
  assert.equal(isOvercast([near(0)], morioka, summerEvening), false);
});

test('日照を使えるのは、前の1時間のうち太陽が10°以上だった時間が30分以上あるとき', () => {
  assert.equal(sunMinutesAbove(summerNoon, morioka, 10), 60);
  assert.ok(sunMinutesAbove(summerEvening, morioka, 10) < 30);
  // 見えなかった通知の時刻（2026-10-30 15:10、15:55、11-02 08:30）は、どれも日照を使える
  for (const at of ['2026-10-30T15:10:00+09:00', '2026-10-30T15:55:00+09:00', '2026-11-02T08:30:00+09:00']) {
    assert.ok(sunMinutesAbove(new Date(at), { latitude: 39.78, longitude: 141.13 }, 10) >= 30, at);
  }
});

test('近くのアメダスの日照のまとめ（地点の数、日差しのあった地点、どこも0か）', () => {
  const near = (sun1h, extra = {}) => ({ latitude: 39.72, longitude: 141.14, sun1h, ...extra });
  assert.deepEqual(nearbySunshine([near(0), near(0)], morioka), { stations: 2, anyPositive: false, allZero: true });
  assert.deepEqual(nearbySunshine([near(0), near(0.5)], morioka), { stations: 2, anyPositive: true, allZero: false });
  assert.deepEqual(nearbySunshine([near(null)], morioka), { stations: 0, anyPositive: false, allZero: false });
  assert.deepEqual(nearbySunshine([], morioka), { stations: 0, anyPositive: false, allZero: false });
});

// 見張る場所のまわりの z6 の赤外画像を、同じ明るさで埋めたものを作る（まわりのタイルも）
function infraredAround(point, grayAt) {
  const center = latLngToPixel(point.latitude, point.longitude, 6);
  const images = new Map();
  const tx = Math.floor(center.x / 256);
  const ty = Math.floor(center.y / 256);
  for (const x of [tx - 1, tx, tx + 1]) {
    for (const y of [ty - 1, ty, ty + 1]) {
      const data = new Uint8Array(256 * 256 * 4);
      for (let py = 0; py < 256; py++) {
        for (let px = 0; px < 256; px++) {
          const gray = grayAt(x * 256 + px, y * 256 + py, center);
          data.fill(gray, (py * 256 + px) * 4, (py * 256 + px) * 4 + 3);
          data[(py * 256 + px) * 4 + 3] = 255;
        }
      }
      images.set(`${x},${y}`, { width: 256, height: 256, data });
    }
  }
  return images;
}
// 気温8℃のとき、赤外の温度が8℃になる明るさ（晴れ）と、-30℃になる明るさ（厚い雲）
const GRAY_CLEAR = Math.round((45 - 8) * 1.9);
const GRAY_CLOUD = Math.round((45 + 30) * 1.9);

test('雲の量: 一面が冷たければ100%、晴れなら0%、半分なら約50%。気温が分からなければ判断しない', () => {
  const allCloud = infraredAround(morioka, () => GRAY_CLOUD);
  const clear = infraredAround(morioka, () => GRAY_CLEAR);
  const half = infraredAround(morioka, (x, y, c) => (x < c.x ? GRAY_CLOUD : GRAY_CLEAR));

  assert.equal(cloudCover(morioka, allCloud, 8).fraction, 1);
  assert.equal(cloudCover(morioka, clear, 8).fraction, 0);
  const halfCover = cloudCover(morioka, half, 8).fraction;
  assert.ok(halfCover > 0.4 && halfCover < 0.6, `半分のはず: ${halfCover}`);
  // 記録に残す、ほかのしきい値の割合も出る
  assert.deepEqual(Object.keys(cloudCover(morioka, allCloud, 8).fractions), ['5', '8', '12']);
  // 気温が分からない、画像がない、画像が半分以上足りない
  assert.equal(cloudCover(morioka, allCloud, null), null);
  assert.equal(cloudCover(morioka, new Map(), 8), null);
  const center = latLngToPixel(morioka.latitude, morioka.longitude, 6);
  const farOnly = new Map([[`${Math.floor(center.x / 256) + 5},${Math.floor(center.y / 256)}`, allCloud.values().next().value]]);
  assert.equal(cloudCover(morioka, farOnly, 8), null);
});

test('一面の曇りの判断: 日照でも、雲の量でも、曇りになる。日差しがあれば雲の量だけでは曇りにしない', () => {
  const stations = (sun1h, tempC = 8) => [
    { latitude: 39.72, longitude: 141.14, sun1h, tempC },
    { latitude: 39.65, longitude: 141.10, sun1h, tempC },
  ];
  const cloud = infraredAround(morioka, () => GRAY_CLOUD);
  const clear = infraredAround(morioka, () => GRAY_CLEAR);

  // 昼（日照を使える）: どこも日照0なら、雲の量に関係なく曇り
  assert.equal(assessSky({ stations: stations(0), point: morioka, now: summerNoon, images: clear }).overcast, true);
  // 昼: 雲の量が多くても、日差しがあれば（薄い雲、切れ間）曇りとしない
  assert.equal(assessSky({ stations: stations(0.6), point: morioka, now: summerNoon, images: cloud }).overcast, false);
  // 昼: 日差しがあり、雲も少なければ晴れ
  assert.equal(assessSky({ stations: stations(0.9), point: morioka, now: summerNoon, images: clear }).overcast, false);
  // 夕方（日照を使えない）: 日照0でも、雲が少なければ曇りとしない。雲が多ければ曇り
  const evening = (images) => assessSky({ stations: stations(0), point: morioka, now: summerEvening, images });
  assert.equal(evening(clear).overcast, false);
  assert.equal(evening(cloud).overcast, true);
  // ひまわりが取れなかったとき（images なし）は、日照だけ。夕方は判断できないので曇りとしない
  assert.equal(evening(null).overcast, false);
  assert.equal(assessSky({ stations: stations(0), point: morioka, now: summerNoon, images: null }).overcast, true);
});

test('空のようすの記録: 太陽の高さ、日照、雲の量、気温を返す', () => {
  const stations = [{ latitude: 39.72, longitude: 141.14, sun1h: 0, tempC: 8 }];
  const sky = assessSky({ stations, point: morioka, now: summerNoon, images: infraredAround(morioka, () => GRAY_CLOUD) });
  assert.equal(sky.surfaceTempC, 8);
  assert.equal(sky.sun.usable, true);
  assert.equal(sky.sun.stations, 1);
  assert.equal(sky.sun.allZero, true);
  assert.ok(sky.sun.altitudeDeg > 50 && sky.sun.altitudeDeg < 80);
  assert.equal(sky.cover.fraction, 1);
});

test('視程は20km 未満のときだけ使う', () => {
  const station = (visibilityM) => ({ latitude: 39.70, longitude: 141.17, visibilityM });
  assert.equal(visibilityKmNear([station(12300)], morioka), 12.3);
  assert.equal(visibilityKmNear([station(20000)], morioka), null);
  assert.equal(visibilityKmNear([], morioka), null);
});
