const { test } = require('node:test');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');
const { CloudWatchService, isPlusActive, watchPointsOf } = require('../modules/watch/cloud_watch_service');
const FakeFirestore = require('./helpers/fake_firestore');

const ts = (date) => admin.firestore.Timestamp.fromDate(date);
const now = new Date('2026-08-12T15:24:00+09:00');
const home = { latitude: 39.735, longitude: 141.077 };
// home から南東へ約25km と約42km
const nearCloud = { center: { latitude: 39.576, longitude: 141.285 } };
const midCloud = { center: { latitude: 39.468, longitude: 141.426 } };

function setup({ clouds = { c1: nearCloud }, members = {}, servers = {} } = {}) {
  const firestore = new FakeFirestore();
  for (const [id, cloud] of Object.entries(clouds)) {
    firestore.docs.set(`clouds/${id}`, { status: 'active', isVisible: true, ...cloud });
  }
  for (const [id, member] of Object.entries(members)) firestore.docs.set(`members/${id}`, member);
  for (const [id, server] of Object.entries(servers)) firestore.docs.set(`member_server/${id}`, server);

  const sent = [];
  const notifications = {
    async sendCloudNotification(token, message, data, cloudId) {
      sent.push({ token, message, data, cloudId });
      return token === 'dead-token' ? { ok: false, invalidToken: true } : { ok: true };
    },
  };
  const service = new CloudWatchService(notifications);
  Object.defineProperty(service, 'firestore', { get: () => firestore });
  return { firestore, service, sent };
}

const member = (extra = {}) => ({ fcmToken: 'token-a', location: home, settings: {}, ...extra });

test('範囲内の雲を通知し、通知の記録と最初の通知の時刻を残す', async () => {
  const { firestore, service, sent } = setup({ members: { u1: member() } });
  const summary = await service.run(now);

  assert.equal(summary.sent, 1);
  assert.equal(sent[0].token, 'token-a');
  assert.equal(sent[0].cloudId, 'c1');
  assert.equal(sent[0].message.title, '南東の空に、入道雲が現れました');
  assert.equal(sent[0].data.type, 'cloud_appeared');
  assert.equal(sent[0].data.cloudId, 'c1');

  const server = firestore.docs.get('member_server/u1');
  assert.deepEqual(server.notification.notifiedCloudIds, ['c1']);
  assert.equal(server.notification.dailyCount, 1);
  assert.equal(server.firstNotifiedAt.toDate().getTime(), now.getTime());
});

test('同じ雲は2回知らせず、2回目以降も最初の通知の時刻は変えない', async () => {
  const first = new Date(now.getTime() - 60 * 60 * 1000);
  const { firestore, service, sent } = setup({
    clouds: { c1: nearCloud, c2: { center: { latitude: 39.6, longitude: 141.0 } } },
    members: { u1: member() },
    servers: { u1: {
      firstNotifiedAt: ts(first),
      notification: { notifiedCloudIds: ['c1'], lastNotifiedAt: ts(first), dailyDate: '2026-08-12', dailyCount: 1 },
    } },
  });
  await service.run(now);
  assert.deepEqual(sent.map((s) => s.cloudId), ['c2']);
  const server = firestore.docs.get('member_server/u1');
  assert.equal(server.firstNotifiedAt.toDate().getTime(), first.getTime());
  assert.equal(server.notification.dailyCount, 2);
});

test('Plus は90kmまで、無料は30kmまで', async () => {
  const { service, sent } = setup({
    clouds: { mid: midCloud },
    members: { free: member({ fcmToken: 'free' }), plus: member({ fcmToken: 'plus', settings: { rangeKm: 90 } }) },
    servers: { plus: { isPlus: true } },
  });
  const summary = await service.run(now);
  assert.deepEqual(sent.map((s) => s.token), ['plus']);
  assert.equal(summary.skipped.no_cloud_in_range, 1);
});

test('期限の切れた Plus は無料として扱う', () => {
  assert.equal(isPlusActive({ isPlus: true, plusExpiresAt: ts(new Date(now.getTime() - 1000)) }, now), false);
  assert.equal(isPlusActive({ isPlus: true, plusExpiresAt: ts(new Date(now.getTime() + 1000)) }, now), true);
  assert.equal(isPlusActive({ isPlus: true }, now), true);
  assert.equal(isPlusActive(undefined, now), false);
});

test('見張る場所: 無料はいまいる場所＋1か所、Plus はいまいる場所＋3か所まで', () => {
  const places = [1, 2, 3, 4].map((i) => ({ label: `場所${i}`, latitude: 35 + i, longitude: 135 }));
  assert.deepEqual(watchPointsOf({ location: home, places }, false).map((p) => p.label), ['いまいる場所', '場所1']);
  assert.equal(watchPointsOf({ places }, false)[0].label, '場所1');
  assert.equal(watchPointsOf({ location: home, places }, true).length, 4);
  assert.equal(watchPointsOf({}, true).length, 0);
});

test('トークンがない人と通知をオフにした人には送らない', async () => {
  const { service, sent } = setup({
    members: {
      noToken: member({ fcmToken: null }),
      off: member({ fcmToken: 'off', settings: { notifyAppeared: false } }),
    },
  });
  const summary = await service.run(now);
  assert.equal(sent.length, 0);
  assert.equal(summary.checked, 0);
});

test('使えなくなったトークンは消し、通知の記録は残さない', async () => {
  const { firestore, service } = setup({ members: { u1: member({ fcmToken: 'dead-token' }) } });
  const summary = await service.run(now);
  assert.equal(summary.sent, 0);
  assert.equal(firestore.docs.get('members/u1').fcmToken, null);
  // 通知の記録（知らせた雲、回数、最初の通知）は残さない。判断の記録（send_failed）だけが入る
  const server = firestore.docs.get('member_server/u1') || {};
  assert.equal(server.firstNotifiedAt, undefined);
  assert.equal((server.notification || {}).notifiedCloudIds, undefined);
  assert.equal((server.notification || {}).dailyCount, undefined);
});

test('見えている雲がなければ誰も調べない', async () => {
  const { service, sent } = setup({
    clouds: { c1: { ...nearCloud, isVisible: false } },
    members: { u1: member() },
  });
  const summary = await service.run(now);
  assert.equal(summary.checked, 0);
  assert.equal(sent.length, 0);
});

test('いまいる場所で雨が降っていれば送らない', async () => {
  const { service, sent } = setup({ members: { u1: member() } });
  const rainLookup = { isRaining: async () => true };
  const summary = await service.run(now, { rainLookup });
  assert.equal(sent.length, 0);
  assert.equal(summary.skipped.raining_here, 1);
});

test('雨を調べられなかったときは雨なしとして送る', async () => {
  const { service, sent } = setup({ members: { u1: member() } });
  const rainLookup = { isRaining: async () => { throw new Error('テスト用の失敗'); } };
  const originalWarn = console.warn;
  console.warn = () => {};
  try {
    await service.run(now, { rainLookup });
  } finally {
    console.warn = originalWarn;
  }
  assert.equal(sent.length, 1);
});

test('近くのアメダスがどこも1時間日が差していなければ送らない', async () => {
  const { service, sent } = setup({ members: { u1: member() } });
  const amedasStations = [{ latitude: 39.74, longitude: 141.08, sun1h: 0 }];
  const summary = await service.run(now, { amedasStations });
  assert.equal(sent.length, 0);
  assert.equal(summary.skipped.overcast_here, 1);
});

test('ひまわりで見積もった高さで、通知の見上げる高さを出す', async () => {
  const { service, sent } = setup({ clouds: { c1: { ...nearCloud, topHeightKm: 6 } }, members: { u1: member() } });
  await service.run(now);
  // 約25km 先で高さ6km なら約13.4°
  assert.equal(sent[0].data.elevationDeg, '13.4');
});

test('読み取りを減らす: 通知の宛先がない人と通知をオフの人の member_server は読まない', async () => {
  const { firestore, service } = setup({
    members: {
      u1: member(),
      u2: member({ fcmToken: null }),
      u3: { location: home, settings: {} },
      u4: member({ settings: { notifyAppeared: false } }),
    },
    servers: { u1: {}, u2: {}, u3: {}, u4: {} },
  });
  const read = [];
  const getAll = firestore.getAll.bind(firestore);
  firestore.getAll = async (...refs) => {
    refs.forEach((ref) => read.push(ref.path));
    return getAll(...refs);
  };
  const summary = await service.run(now);

  assert.equal(summary.checked, 1);
  assert.deepEqual(read, ['member_server/u1']);
});

// ===== 一面の曇りの判断（ひまわりの雲の量）と、判断の記録（2026-11-02 の検知の見直し） =====

const { GRAY_CLEAR, GRAY_CLOUD, infraredAround, fakeInfrared } = require('./helpers/infrared');

// 日の入りの直前（太陽が低く、日照を使えない）。市民薄明のあいだなので、通知してよい時間
const evening = new Date('2026-08-12T18:30:00+09:00');
const stationNearHome = (sun1h = 0) => [{ latitude: 39.72, longitude: 141.08, sun1h, tempC: 8 }];

test('太陽が低くて日照を使えなくても、ひまわりの雲の量が多ければ一面の曇りとして知らせない', async () => {
  const cloudy = fakeInfrared(infraredAround(home, () => GRAY_CLOUD));
  const clear = fakeInfrared(infraredAround(home, () => GRAY_CLEAR));

  const a = setup({ members: { u1: member() } });
  const blocked = await a.service.run(evening, { amedasStations: stationNearHome(0), infrared: cloudy });
  assert.equal(blocked.sent, 0);
  assert.equal(blocked.skipped.overcast_here, 1);

  // 雲が少なければ、日照0（太陽が低くて当てにならない）でも知らせる
  const b = setup({ members: { u1: member() } });
  const sent = await b.service.run(evening, { amedasStations: stationNearHome(0), infrared: clear });
  assert.equal(sent.sent, 1);

  // ひまわりがなければ、太陽が低い時間は曇りを判断できないので、今までどおり知らせる
  const c = setup({ members: { u1: member() } });
  assert.equal((await c.service.run(evening, { amedasStations: stationNearHome(0), infrared: null })).sent, 1);
});

test('昼に近くで日差しがあれば、雲の量が多くても（薄い雲、切れ間）曇りとしない', async () => {
  const cloudy = fakeInfrared(infraredAround(home, () => GRAY_CLOUD));
  const { service } = setup({ members: { u1: member() } });
  const summary = await service.run(now, { amedasStations: stationNearHome(0.7), infrared: cloudy });
  assert.equal(summary.sent, 1);
});

test('背の低い遠い雲（見上げる角度が8°未満）は知らせず、判断を記録する', async () => {
  const lowFar = { center: { latitude: 39.26, longitude: 141.70 }, topHeightKm: 7.2, topTempC: -37.1, areaKm2: 7.1,
    pixelCount: 2, maxRainMmPerHour: 30, maxThunderLevel: 0 };
  const { firestore, service, sent } = setup({
    clouds: { far: lowFar },
    members: { u1: member({ settings: { rangeKm: 90 } }) },
    servers: { u1: { isPlus: true } },
  });
  const summary = await service.run(now, {
    amedasStations: stationNearHome(0.9),
    infrared: fakeInfrared(infraredAround(home, () => GRAY_CLEAR)),
    times: { rain: '20260812062000', thunder: '20260812062000' },
    amedasTime: '2026-08-12T06:20:00.000Z',
  });
  assert.equal(summary.sent, 0);
  assert.equal(summary.skipped.low_elevation, 1);
  assert.equal(sent.length, 0);

  const logs = [...firestore.docs.entries()].filter(([path]) => path.startsWith('notification_log/')).map(([, v]) => v);
  assert.equal(logs.length, 1);
  const log = logs[0];
  assert.equal(log.uid, 'u1');
  assert.equal(log.cloudId, 'far');
  assert.equal(log.decision, 'low_elevation');
  assert.equal(log.rulesVersion, 'detect-2026-11-02');
  assert.equal(log.cloud.topTempC, -37.1);
  assert.equal(log.cloud.topHeightKm, 7.2);
  assert.equal(log.cloud.areaKm2, 7.1);
  assert.equal(log.cloud.pixelCount, 2);
  assert.ok(log.cloud.elevationDeg < 8);
  assert.ok(log.cloud.distanceKm > 60);
  // 位置は約1kmに丸めた値だけ
  assert.equal(log.viewer.latitude, 39.74);
  assert.equal(log.viewer.longitude, 141.08);
  assert.equal(log.viewer.isCurrentLocation, true);
  assert.equal(log.sky.overcast, false);
  assert.equal(log.sky.coverFraction, 0);
  assert.equal(log.sky.sunshineUsable, true);
  assert.equal(log.sky.sunshineAnyPositive, true);
  assert.equal(log.sky.surfaceTempC, 8);
  assert.deepEqual(log.dataTimes, { nowcast: '20260812062000', himawari: '20260812062000', amedas: '2026-08-12T06:20:00.000Z' });
  assert.ok(log.expiresAt && log.loggedAt);

  // 同じ雲で同じ判断は、2回目から書かない
  await service.run(new Date(now.getTime() + 5 * 60 * 1000), { amedasStations: stationNearHome(0.9) });
  assert.equal([...firestore.docs.keys()].filter((path) => path.startsWith('notification_log/')).length, 1);
});

test('通知した雲は notified と記録し、ほかの雲は理由つきで記録する', async () => {
  const lowFar = { center: { latitude: 39.26, longitude: 141.70 }, topHeightKm: 7.2 };
  const { firestore, service } = setup({
    clouds: { c1: { ...nearCloud, topHeightKm: 10 }, far: lowFar },
    members: { u1: member({ settings: { rangeKm: 90 } }) },
    servers: { u1: { isPlus: true } },
  });
  const summary = await service.run(now);
  assert.equal(summary.sent, 1);
  const logs = [...firestore.docs.entries()].filter(([path]) => path.startsWith('notification_log/')).map(([, v]) => v);
  const byCloud = Object.fromEntries(logs.map((l) => [l.cloudId, l.decision]));
  assert.deepEqual(byCloud, { c1: 'notified', far: 'low_elevation' });
  // 通知の記録（回数など）は、判断の記録を足しても消えない
  const server = firestore.docs.get('member_server/u1');
  assert.equal(server.notification.dailyCount, 1);
  assert.deepEqual(server.notification.notifiedCloudIds, ['c1']);
  assert.ok(server.notification.loggedDecisions.includes('c1:notified'));
  assert.equal(server.isPlus, true);
});

test('一面の曇りで止めたときも、範囲内の雲が曇りの数字つきで記録される', async () => {
  const { firestore, service } = setup({ members: { u1: member() } });
  await service.run(evening, {
    amedasStations: stationNearHome(0),
    infrared: fakeInfrared(infraredAround(home, () => GRAY_CLOUD)),
  });
  const logs = [...firestore.docs.entries()].filter(([path]) => path.startsWith('notification_log/')).map(([, v]) => v);
  assert.equal(logs.length, 1);
  assert.equal(logs[0].decision, 'overcast_here');
  assert.equal(logs[0].sky.overcast, true);
  assert.equal(logs[0].sky.coverFraction, 1);
  assert.equal(logs[0].sky.sunshineUsable, false);
});

// ===== ホームに渡す空のようす（member_server.skyNow） =====

test('見張る場所ごとの空のようすを member_server.skyNow に書く（位置は小数第2位に丸めたキー）', async () => {
  const { firestore, service } = setup({ members: { u1: member() } });
  await service.run(evening, {
    amedasStations: stationNearHome(0),
    infrared: fakeInfrared(infraredAround(home, () => GRAY_CLOUD)),
  });
  const skyNow = firestore.docs.get('member_server/u1').skyNow;
  assert.equal(skyNow.updatedAt.toDate().getTime(), evening.getTime());
  assert.deepEqual(skyNow.points, [{ key: '39.74,141.08', overcast: true, raining: false, visibilityKm: null }]);
});

test('空のようすは、変わったときと30分たったときだけ書き直す', async () => {
  const { firestore, service } = setup({ members: { u1: member() } });
  const clear = fakeInfrared(infraredAround(home, () => GRAY_CLEAR));
  const cloudy = fakeInfrared(infraredAround(home, () => GRAY_CLOUD));
  const run = (at, infrared) => service.run(at, { amedasStations: stationNearHome(0), infrared });
  const writtenAt = () => firestore.docs.get('member_server/u1').skyNow.updatedAt.toDate().getTime();

  await run(evening, clear);
  assert.equal(writtenAt(), evening.getTime());
  // 5分後、同じ結果なら書き直さない
  await run(new Date(evening.getTime() + 5 * 60 * 1000), clear);
  assert.equal(writtenAt(), evening.getTime());
  // 10分後、結果が変われば書き直す（曇りになった）
  const changed = new Date(evening.getTime() + 10 * 60 * 1000);
  await run(changed, cloudy);
  assert.equal(writtenAt(), changed.getTime());
  assert.equal(firestore.docs.get('member_server/u1').skyNow.points[0].overcast, true);
  // 同じ結果のまま30分以上たてば、書き直す（アプリが古い結果を使わないため）
  const later = new Date(changed.getTime() + 31 * 60 * 1000);
  await run(later, cloudy);
  assert.equal(writtenAt(), later.getTime());
});

test('空のようすを書いても、通知の記録や Plus は消えない', async () => {
  const { firestore, service } = setup({
    members: { u1: member() },
    servers: { u1: { isPlus: true, notification: { dailyCount: 1, dailyDate: '2026-08-12', notifiedCloudIds: ['x'] } } },
  });
  await service.run(now, { amedasStations: stationNearHome(0.9) });
  const server = firestore.docs.get('member_server/u1');
  assert.equal(server.isPlus, true);
  assert.ok(server.skyNow);
  assert.equal(server.notification.dailyCount, 2);
});
