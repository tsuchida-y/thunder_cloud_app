const { test } = require('node:test');
const assert = require('node:assert/strict');
const { distanceKm, trackClouds } = require('../modules/jma/cloud_tracker');
const JmaClient = require('../modules/jma/jma_client');

const now = new Date('2026-08-12T05:30:00Z');
const minutesAgo = (m) => new Date(now.getTime() - m * 60 * 1000);

// 緯度 0.1 度 ≒ 11.1km
const cloud = (id, latitude, longitude, lastSeenMinutesAgo = 5) =>
  ({ id, latitude, longitude, lastSeenAt: minutesAgo(lastSeenMinutesAgo) });
const cluster = (latitude, longitude) => ({ latitude, longitude });

test('距離の計算（滝沢市から盛岡市は約10km）', () => {
  const d = distanceKm({ latitude: 39.735, longitude: 141.077 }, { latitude: 39.702, longitude: 141.154 });
  assert.ok(d > 6 && d < 9, `${d}km`);
});

test('15km以内なら同じ雲として続ける', () => {
  const result = trackClouds([cloud('a', 39.7, 141.1)], [cluster(39.8, 141.1)], now);
  assert.deepEqual(result.updated.map((u) => u.id), ['a']);
  assert.equal(result.created.length, 0);
});

test('15kmより離れていれば新しい雲にする', () => {
  const result = trackClouds([cloud('a', 39.7, 141.1)], [cluster(39.9, 141.1)], now);
  assert.equal(result.updated.length, 0);
  assert.equal(result.created.length, 1);
  assert.deepEqual(result.hidden.map((h) => h.id), ['a']);
});

test('近い組み合わせから1対1で結ぶ', () => {
  const result = trackClouds(
    [cloud('a', 39.70, 141.1), cloud('b', 39.78, 141.1)],
    [cluster(39.77, 141.1), cluster(39.71, 141.1)],
    now
  );
  const byId = Object.fromEntries(result.updated.map((u) => [u.id, u.cluster.latitude]));
  assert.equal(byId.a, 39.71);
  assert.equal(byId.b, 39.77);
});

test('見えなくなっても60分までは追跡を続け、60分たったら終わりにする', () => {
  const result = trackClouds([cloud('recent', 35, 135, 30), cloud('old', 36, 136, 60)], [], now);
  assert.deepEqual(result.hidden.map((h) => h.id), ['recent']);
  assert.deepEqual(result.ended.map((e) => e.id), ['old']);
});

test('60分以内にまた見つかれば同じ雲として続ける', () => {
  const result = trackClouds([cloud('a', 35, 135, 55)], [cluster(35.05, 135)], now);
  assert.deepEqual(result.updated.map((u) => u.id), ['a']);
});

test('気象庁の時刻一覧から最新の解析値を選ぶ', () => {
  const times = [
    { basetime: '20261020062000', validtime: '20261020072000', elements: ['thns'] },
    { basetime: '20261020062000', validtime: '20261020062000', elements: ['liden'] },
    { basetime: '20261020061000', validtime: '20261020061000', elements: ['thns', 'trns'] },
    { basetime: '20261020060000', validtime: '20261020060000', elements: ['thns'] },
  ];
  assert.equal(JmaClient.findLatestAnalysis(times, 'thns'), '20261020061000');
  assert.equal(JmaClient.findLatestAnalysis(times, 'hrpns'), null);
  assert.throws(() => JmaClient.findLatestAnalysis({}, 'thns'));
});

test('気象庁の時刻を UTC として読む', () => {
  assert.equal(JmaClient.parseTime('20261020062500').toISOString(), '2026-10-20T06:25:00.000Z');
  assert.throws(() => JmaClient.parseTime('2026-10-20'));
});
