const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  grayToTempC,
  coldestTopTempC,
  topHeightKm,
  isTallEnough,
  surfaceTempNear,
  isOvercast,
  visibilityKmNear,
} = require('../modules/jma/sky_observations');

const morioka = { latitude: 39.70, longitude: 141.15 };
// 盛岡の夏の昼（太陽は十分高い）と、日の入りの少し前（太陽が低い）
const summerNoon = new Date('2026-08-12T12:30:00+09:00');
const summerEvening = new Date('2026-08-12T18:00:00+09:00');

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
  // 太陽が低い時間は、晴れていても日照なしになるので判定しない
  assert.equal(isOvercast([near(0)], morioka, summerEvening), false);
});

test('視程は20km 未満のときだけ使う', () => {
  const station = (visibilityM) => ({ latitude: 39.70, longitude: 141.17, visibilityM });
  assert.equal(visibilityKmNear([station(12300)], morioka), 12.3);
  assert.equal(visibilityKmNear([station(20000)], morioka), null);
  assert.equal(visibilityKmNear([], morioka), null);
});
