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

test('見張る場所: 無料は1か所、Plus はいまいる場所＋3か所まで', () => {
  const places = [1, 2, 3, 4].map((i) => ({ label: `場所${i}`, latitude: 35 + i, longitude: 135 }));
  assert.equal(watchPointsOf({ location: home, places }, false).length, 1);
  assert.equal(watchPointsOf({ location: home, places }, false)[0].label, 'いまいる場所');
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
  assert.equal(firestore.docs.has('member_server/u1'), false);
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
  const summary = await service.run(now, rainLookup);
  assert.equal(sent.length, 0);
  assert.equal(summary.skipped.raining_here, 1);
});

test('雨を調べられなかったときは雨なしとして送る', async () => {
  const { service, sent } = setup({ members: { u1: member() } });
  const rainLookup = { isRaining: async () => { throw new Error('テスト用の失敗'); } };
  const originalWarn = console.warn;
  console.warn = () => {};
  try {
    await service.run(now, rainLookup);
  } finally {
    console.warn = originalWarn;
  }
  assert.equal(sent.length, 1);
});
