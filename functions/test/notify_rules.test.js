const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  jstDateKey,
  isInQuietHours,
  decideNotification,
  nextHistory,
  appearedMessage,
} = require('../modules/notification/notify_rules');

const jst = (s) => new Date(`${s}+09:00`);
const now = jst('2026-08-12T15:24:00');
const home = { label: 'いまいる場所', latitude: 39.735, longitude: 141.077 };

// home から南東へ約25km、約42km、約75km、約120km
const near = { id: 'near', latitude: 39.576, longitude: 141.285, isVisible: true };
const mid = { id: 'mid', latitude: 39.468, longitude: 141.426, isVisible: true };
const far = { id: 'far', latitude: 39.26, longitude: 141.70, isVisible: true };
const tooFar = { id: 'tooFar', latitude: 38.97, longitude: 142.08, isVisible: true };

const base = { now, watchPoints: [home], isPlus: false, history: {}, clouds: [near] };

test('範囲内の見えている雲を知らせる', () => {
  const result = decideNotification(base);
  assert.equal(result.notify.cloud.id, 'near');
  assert.equal(result.notify.view.directionName, '南東');
  assert.equal(result.notify.maybeVisible, false);
});

test('無料は30km、Plus は90kmまで', () => {
  assert.equal(decideNotification({ ...base, clouds: [mid] }).skip, 'no_cloud_in_range');
  assert.equal(decideNotification({ ...base, isPlus: true, clouds: [mid] }).notify.cloud.id, 'mid');
  const plus = decideNotification({ ...base, isPlus: true, rangeKm: 90, clouds: [far, tooFar] });
  assert.equal(plus.notify.cloud.id, 'far');
  assert.equal(plus.notify.maybeVisible, true);
  // Plus でも 30km を選んでいれば 30km まで
  assert.equal(decideNotification({ ...base, isPlus: true, rangeKm: 30, clouds: [far] }).skip, 'no_cloud_in_range');
});

test('いちばん近い雲を選び、見えていない雲は除く', () => {
  const hidden = { ...near, id: 'hidden', latitude: 39.6, isVisible: false };
  const result = decideNotification({ ...base, isPlus: true, clouds: [far, hidden, near] });
  assert.equal(result.notify.cloud.id, 'near');
});

test('1つの雲には1回だけ', () => {
  const result = decideNotification({ ...base, history: { notifiedCloudIds: ['near'] } });
  assert.equal(result.skip, 'no_cloud_in_range');
});

test('前の通知から30分たっていなければ送らない', () => {
  const history = { lastNotifiedAt: new Date(now.getTime() - 29 * 60 * 1000) };
  assert.equal(decideNotification({ ...base, history }).skip, 'interval');
  const later = { lastNotifiedAt: new Date(now.getTime() - 31 * 60 * 1000) };
  assert.ok(decideNotification({ ...base, history: later }).notify);
});

test('1日3回まで（日本時間の日付が変われば数え直す）', () => {
  const history = { dailyDate: '2026-08-12', dailyCount: 3 };
  assert.equal(decideNotification({ ...base, history }).skip, 'daily_limit');
  const yesterday = { dailyDate: '2026-08-11', dailyCount: 3 };
  assert.ok(decideNotification({ ...base, history: yesterday }).notify);
});

test('日没から日の出までは送らない', () => {
  assert.equal(decideNotification({ ...base, now: jst('2026-08-12T20:00:00') }).skip, 'night');
});

test('通知しない時間（日をまたぐ指定も）', () => {
  assert.equal(isInQuietHours(jst('2026-08-12T10:30:00'), { startMinutes: 600, endMinutes: 660 }), true);
  assert.equal(isInQuietHours(jst('2026-08-12T11:00:00'), { startMinutes: 600, endMinutes: 660 }), false);
  assert.equal(isInQuietHours(jst('2026-08-12T23:00:00'), { startMinutes: 22 * 60, endMinutes: 6 * 60 }), true);
  assert.equal(isInQuietHours(jst('2026-08-12T05:00:00'), { startMinutes: 22 * 60, endMinutes: 6 * 60 }), true);
  assert.equal(isInQuietHours(now, null), false);
  assert.equal(decideNotification({ ...base, quietHours: { startMinutes: 900, endMinutes: 960 } }).skip, 'quiet_hours');
});

test('アプリを開いて10分以内の人には送らない', () => {
  const lastOpenedAt = new Date(now.getTime() - 5 * 60 * 1000);
  assert.equal(decideNotification({ ...base, lastOpenedAt }).skip, 'recently_opened');
});

test('場所が分からない人には送らない', () => {
  assert.equal(decideNotification({ ...base, watchPoints: [] }).skip, 'no_location');
});

test('知らせたあとの記録を作る', () => {
  const after = nextHistory({ notifiedCloudIds: ['a'], dailyDate: '2026-08-12', dailyCount: 1 }, 'near', now);
  assert.deepEqual(after.notifiedCloudIds, ['a', 'near']);
  assert.equal(after.dailyCount, 2);
  assert.equal(after.dailyDate, jstDateKey(now));
  assert.equal(nextHistory({ dailyDate: '2026-08-11', dailyCount: 3 }, 'x', now).dailyCount, 1);
});

test('通知の文面（Notify.html の文言、60kmより遠いときは控えめに）', () => {
  const nearView = decideNotification({ ...base, isPlus: true, clouds: [mid] }).notify.view;
  assert.deepEqual(appearedMessage(nearView), {
    title: '南東の空に、入道雲が現れました',
    body: '約42km先。こぶし1つ半の高さを見上げてみて。',
  });
  const farView = decideNotification({ ...base, isPlus: true, clouds: [far] }).notify.view;
  assert.match(appearedMessage(farView).body, /^約\d+km先なので、見えるかもしれません。/);
});

test('登録した場所の雲は、通知の題に場所の名前を付ける', () => {
  const view = { distanceKm: 55, directionName: '北', fistsLabel: 'こぶし1つ' };
  assert.equal(appearedMessage(view, '家').title, '家の北の空に、入道雲が現れました');
  assert.equal(appearedMessage(view, 'いまいる場所').title, '北の空に、入道雲が現れました');
  assert.equal(appearedMessage(view).title, '北の空に、入道雲が現れました');
});

test('見張る場所で雨が降っていたら知らせない（雨のない登録した場所では知らせる）', () => {
  assert.equal(decideNotification({ ...base, watchPoints: [{ ...home, raining: true }] }).skip, 'raining_here');
  const place = { label: '家', latitude: 39.70, longitude: 141.10 };
  const result = decideNotification({ ...base, watchPoints: [{ ...home, raining: true }, place] });
  assert.equal(result.notify.point.label, '家');
});

test('雲のふちが10kmより近い雲は知らせず、ほかの雲があればそちらを知らせる', () => {
  // 中心は約25km先だが、ふちが home から約5km
  const wide = { ...near, id: 'wide', edgePoints: [{ latitude: 39.70, longitude: 141.11 }, near] };
  assert.equal(decideNotification({ ...base, clouds: [wide] }).skip, 'too_close');
  const other = { id: 'other', latitude: 39.90, longitude: 141.10, isVisible: true };
  assert.equal(decideNotification({ ...base, clouds: [wide, other] }).notify.cloud.id, 'other');
  // ふちの点がない古い雲は中心までの距離で決める
  const close = { id: 'close', latitude: 39.75, longitude: 141.10, isVisible: true };
  assert.equal(decideNotification({ ...base, clouds: [close] }).skip, 'too_close');
});

test('一面の曇りの場所では知らせない', () => {
  assert.equal(decideNotification({ ...base, watchPoints: [{ ...home, overcast: true }] }).skip, 'overcast_here');
});

test('視程より遠い雲は知らせない', () => {
  // near は約25km 先
  assert.equal(decideNotification({ ...base, watchPoints: [{ ...home, visibilityKm: 15 }] }).skip, 'beyond_visibility');
  assert.equal(decideNotification({ ...base, watchPoints: [{ ...home, visibilityKm: 30 }] }).notify.cloud.id, 'near');
});

test('見上げる高さは、ひまわりで見積もったてっぺんの高さを使う', () => {
  const low = decideNotification({ ...base, clouds: [{ ...near, topHeightKm: 6 }] }).notify.view;
  const high = decideNotification({ ...base, clouds: [{ ...near, topHeightKm: 15 }] }).notify.view;
  assert.ok(low.elevationDeg < high.elevationDeg);
  // 高さが分からない雲は 12km として計算する
  const unknown = decideNotification(base).notify.view;
  const twelve = decideNotification({ ...base, clouds: [{ ...near, topHeightKm: 12 }] }).notify.view;
  assert.equal(unknown.elevationDeg, twelve.elevationDeg);
});
