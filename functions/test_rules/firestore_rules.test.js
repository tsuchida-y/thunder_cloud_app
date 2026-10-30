/**
 * Firestore のセキュリティルール（firestore.rules）のテスト
 *
 * 実行: functions フォルダで `npm run test:rules`（Firestore エミュレータを使うので Java が要る）
 * アプリが実際に書く内容が通ること、他人のデータや決まっていないフィールドは通らないことを確かめる。
 */
const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment, assertSucceeds, assertFails,
} = require('@firebase/rules-unit-testing');
const firebase = require('firebase/compat/app');
require('firebase/compat/firestore');

const { Timestamp } = firebase.firestore;
const serverTimestamp = () => firebase.firestore.FieldValue.serverTimestamp();

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-rules',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8') },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

const me = () => env.authenticatedContext('me').firestore();
const other = () => env.authenticatedContext('other').firestore();
const anon = () => env.unauthenticatedContext().firestore();

// ===== members =====

test('members: 本人は、アプリが書く内容を作れて、更新でき、読めて、消せる', async () => {
  const db = me();
  const ref = db.doc('members/me');
  await assertSucceeds(ref.set({
    createdAt: serverTimestamp(),
    platform: 'ios',
    settings: { quietHours: { startMinutes: 1320, endMinutes: 360 } },
    legacyUserId: 'abc-123',
  }, { merge: true }));
  await assertSucceeds(ref.set({
    lastOpenedAt: serverTimestamp(),
    location: { latitude: 39.73, longitude: 141.08 },
    locationUpdatedAt: serverTimestamp(),
  }, { merge: true }));
  await assertSucceeds(ref.set({
    places: [{ label: '家', latitude: 39.7, longitude: 141.1 }],
  }, { merge: true }));
  await assertSucceeds(ref.set({ settings: { notifyAppeared: false, rangeKm: 90 } }, { merge: true }));
  await assertSucceeds(ref.set({ fcmToken: 'token', fcmTokenUpdatedAt: serverTimestamp() }, { merge: true }));
  await assertSucceeds(ref.get());
  await assertSucceeds(ref.delete());
});

test('members: 「常に」の位置の更新（iOS の AppDelegate.swift と Android の BackgroundLocation.kt）が書く内容が通る', async () => {
  // 本番のドキュメントには、この書き込みで locationSource が入っている。許可リストに入れ忘れると、
  // その人のアプリからの更新（開いた時刻、設定、見張る場所など）がすべて断られる（2026-10-31 に起きた）
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('members/me').set({
      platform: 'ios', location: { latitude: 39.7, longitude: 141.1 }, locationSource: 'background', places: [],
      fcmToken: 'token', settings: { rangeKm: 90 },
    });
  });
  const ref = me().doc('members/me');
  await assertSucceeds(ref.set({
    location: { latitude: 39.78, longitude: 141.13 },
    locationSource: 'background',
    locationUpdatedAt: serverTimestamp(),
  }, { merge: true }));
  await assertSucceeds(ref.set({ lastOpenedAt: serverTimestamp() }, { merge: true }));
  await assertFails(ref.set({ locationSource: 'x'.repeat(21) }, { merge: true }));
});

test('members: サーバーが fcmToken を null にして残す fcmTokenInvalidAt があっても、本人は書き続けられる', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('members/me').set({
      platform: 'ios', fcmToken: null, fcmTokenInvalidAt: Timestamp.now(),
    });
  });
  await assertSucceeds(me().doc('members/me').set({ lastOpenedAt: serverTimestamp() }, { merge: true }));
});

test('members: 他人のデータは読めず、書けず、消せない。ログインなしも同じ', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('members/me').set({ platform: 'ios' });
  });
  await assertFails(other().doc('members/me').get());
  await assertFails(other().doc('members/me').set({ platform: 'android' }, { merge: true }));
  await assertFails(other().doc('members/me').delete());
  await assertFails(anon().doc('members/me').get());
});

test('members: 決まっていないフィールド、大きすぎる配列や文字列は書けない', async () => {
  const ref = me().doc('members/me');
  await assertFails(ref.set({ isPlus: true }, { merge: true }));
  await assertFails(ref.set({ places: Array.from({ length: 11 }, () => ({ latitude: 1, longitude: 1 })) }, { merge: true }));
  await assertFails(ref.set({ fcmToken: 'x'.repeat(501) }, { merge: true }));
  await assertFails(ref.set({ legacyUserId: 'x'.repeat(101) }, { merge: true }));
  await assertFails(ref.set({ places: 'not-a-list' }, { merge: true }));
  await assertFails(ref.set({ settings: 'not-a-map' }, { merge: true }));
});

// ===== member_server =====

test('member_server: 本人は読むだけ。書くことも、他人が読むこともできない', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('member_server/me').set({ isPlus: true });
  });
  await assertSucceeds(me().doc('member_server/me').get());
  await assertFails(other().doc('member_server/me').get());
  await assertFails(me().doc('member_server/me').set({ isPlus: true }));
  await assertFails(me().doc('member_server/me').update({ isPlus: false }));
});

// ===== reports =====

const report = (extra = {}) => ({
  uid: 'me',
  seen: true,
  cloudId: 'cloud-1',
  source: 'notification',
  bearingDeg: 135.5,
  distanceKm: 42.3,
  answeredAt: Timestamp.now(),
  reportedAt: serverTimestamp(),
  ...extra,
});

test('reports: アプリが書く内容は作れて、自分のものだけ読める', async () => {
  await assertSucceeds(me().collection('reports').add(report()));
  await assertSucceeds(me().collection('reports').add({ uid: 'me', seen: false, cloudId: null, source: 'finder', reportedAt: serverTimestamp() }));
  const mine = await assertSucceeds(me().collection('reports').where('uid', '==', 'me').get());
  if (mine.size !== 2) throw new Error(`自分の答えは2件のはずが ${mine.size} 件`);
  await assertFails(other().collection('reports').where('uid', '==', 'me').get());
});

test('reports: 他人の uid、型の違い、決まっていないフィールド、大きすぎる文字列は作れない', async () => {
  const col = me().collection('reports');
  await assertFails(col.add(report({ uid: 'other' })));
  await assertFails(col.add(report({ seen: 'yes' })));
  await assertFails(col.add(report({ extra: 'x' })));
  await assertFails(col.add(report({ cloudId: 'x'.repeat(101) })));
  await assertFails(col.add(report({ source: 'x'.repeat(31) })));
  await assertFails(col.add(report({ bearingDeg: 'east' })));
  await assertFails(col.add(report({ reportedAt: Timestamp.fromMillis(0) })));
  await assertFails(anon().collection('reports').add(report()));
});

test('reports: 作ったあとは書き換えも削除もできない', async () => {
  const ref = await assertSucceeds(me().collection('reports').add(report()));
  await assertFails(ref.update({ seen: false }));
  await assertFails(ref.delete());
});

// ===== サーバーだけが書くもの =====

test('clouds と system: ログインした人は読めるが、誰も書けない', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('clouds/c1').set({ status: 'active' });
    await ctx.firestore().doc('system/jma_nowcast').set({ observedAt: Timestamp.now() });
    await ctx.firestore().doc('system/amedas_latest').set({ stations: [] });
  });
  await assertSucceeds(me().doc('clouds/c1').get());
  await assertSucceeds(me().doc('system/jma_nowcast').get());
  await assertSucceeds(me().doc('system/amedas_latest').get());
  await assertFails(anon().doc('clouds/c1').get());
  await assertFails(me().doc('clouds/c1').set({ status: 'ended' }));
  await assertFails(me().doc('system/amedas_latest').set({ stations: [1] }));
});
