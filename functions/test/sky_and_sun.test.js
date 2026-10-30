const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  bearingDeg,
  directionName,
  elevationDeg,
  fistsFromElevation,
  fistsLabel,
  describeCloud,
} = require('../modules/geo/sky_geometry');
const { sunTimesForUtcDate, isDaytime, nextSunrise, SUNRISE_ALTITUDE_DEG } = require('../modules/geo/sun_times');

const takizawa = { latitude: 39.735, longitude: 141.077 };

test('方角を本当の北からの角度と8方位で出す', () => {
  assert.ok(Math.abs(bearingDeg(takizawa, { latitude: 40.0, longitude: 141.077 }) - 0) < 0.5);
  assert.ok(Math.abs(bearingDeg(takizawa, { latitude: 39.735, longitude: 141.5 }) - 90) < 0.5);
  assert.equal(directionName(135), '南東');
  assert.equal(directionName(350), '北');
  assert.equal(directionName(200), '南');
});

test('42km 先の雲は約16°、こぶし1つ半', () => {
  const elevation = elevationDeg(42);
  assert.ok(Math.abs(elevation - 15.9) < 0.2, `${elevation}`);
  assert.equal(fistsFromElevation(elevation), 1.5);
  assert.equal(fistsLabel(1.5), 'こぶし1つ半');
  assert.equal(fistsLabel(1), 'こぶし1つ');
  assert.equal(fistsLabel(0.5), 'こぶし半分');
  assert.equal(fistsFromElevation(2), 0.5);
});

test('利用者から見た雲の見え方をまとめる（南東 約42km）', () => {
  const cloud = { latitude: takizawa.latitude - 0.267, longitude: takizawa.longitude + 0.349 };
  const view = describeCloud(takizawa, cloud);
  assert.equal(view.directionName, '南東');
  assert.ok(Math.abs(view.distanceKm - 42) < 1.5, `${view.distanceKm}`);
  assert.equal(view.fistsLabel, 'こぶし1つ半');
});

// 国立天文台 暦計算室の値（東京 北緯35.6581 東経139.7414、2026年10月20日: 日の出5:51 日の入り17:00）と比べる
const jst = (s) => new Date(`${s}+09:00`);
const tokyo = { latitude: 35.6581, longitude: 139.7414 };
const nearMinutes = (actual, expected, minutes) =>
  Math.abs(actual.getTime() - expected.getTime()) <= minutes * 60 * 1000;

test('東京の日の出・日の入りが国立天文台の値と1分以内で合う', () => {
  const sunrise = nextSunrise(jst('2026-10-20T03:00:00'), tokyo.latitude, tokyo.longitude, SUNRISE_ALTITUDE_DEG);
  const { sunset } = sunTimesForUtcDate(new Date('2026-10-20T00:00:00Z'), tokyo.latitude, tokyo.longitude);
  assert.ok(nearMinutes(sunrise, jst('2026-10-20T05:51:00'), 1), sunrise.toISOString());
  assert.ok(nearMinutes(sunset, jst('2026-10-20T17:00:00'), 1), sunset.toISOString());
});

// 東京 2026-10-20 の市民薄明: はじまり 5:25ごろ、終わり 17:26ごろ（日の出 5:51、日の入り 17:00）
test('昼か夜かは、市民薄明（空が明るいあいだ）で判定する', () => {
  const { latitude, longitude } = tokyo;
  assert.equal(isDaytime(jst('2026-10-20T05:10:00'), latitude, longitude), false);
  assert.equal(isDaytime(jst('2026-10-20T05:40:00'), latitude, longitude), true); // 日の出前でも明るい
  assert.equal(isDaytime(jst('2026-10-20T12:00:00'), latitude, longitude), true);
  assert.equal(isDaytime(jst('2026-10-20T17:10:00'), latitude, longitude), true); // 日の入り後でも明るい
  assert.equal(isDaytime(jst('2026-10-20T17:40:00'), latitude, longitude), false);
  assert.equal(isDaytime(jst('2026-10-20T23:00:00'), latitude, longitude), false);
});

test('次に明るくなる時刻は、市民薄明のはじまり', () => {
  const dawn = nextSunrise(jst('2026-10-20T21:00:00'), tokyo.latitude, tokyo.longitude);
  assert.ok(nearMinutes(dawn, jst('2026-10-21T05:26:00'), 3), dawn.toISOString());
});
