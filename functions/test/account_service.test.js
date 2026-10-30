const { test } = require('node:test');
const assert = require('node:assert/strict');
const { deleteMemberData, plusOnly } = require('../modules/account/account_service');
const FakeFirestore = require('./helpers/fake_firestore');

function setup({ server = { notification: { dailyCount: 1 } } } = {}) {
  const firestore = new FakeFirestore();
  firestore.docs.set('members/me', { platform: 'ios', location: { latitude: 39.7, longitude: 141.1 } });
  firestore.docs.set('member_server/me', server);
  firestore.docs.set('reports/r1', { uid: 'me', seen: true });
  firestore.docs.set('reports/r2', { uid: 'me', seen: false });
  firestore.docs.set('members/other', { platform: 'android' });
  firestore.docs.set('member_server/other', { isPlus: false });
  firestore.docs.set('reports/r3', { uid: 'other', seen: true });
  return firestore;
}

test('自分の members・reports・member_server を消す。他人のものは残す', async () => {
  const firestore = setup();
  const result = await deleteMemberData('me', { firestore });

  assert.deepEqual(result, { reports: 2, keptPlus: false });
  assert.equal(firestore.docs.has('members/me'), false);
  assert.equal(firestore.docs.has('member_server/me'), false);
  assert.equal(firestore.docs.has('reports/r1'), false);
  assert.equal(firestore.docs.has('reports/r2'), false);
  assert.equal(firestore.docs.has('members/other'), true);
  assert.equal(firestore.docs.has('member_server/other'), true);
  assert.equal(firestore.docs.has('reports/r3'), true);
});

test('Plus の人は、member_server に Plus の状態だけを残す（通知の記録は消す）', async () => {
  const firestore = setup({
    server: {
      isPlus: true, plusProductId: 'plus_monthly', plusStore: 'APP_STORE', plusEnvironment: 'PRODUCTION',
      plusExpiresAt: 'T', plusLastEvent: 'RENEWAL', plusUpdatedAt: 'U',
      notification: { dailyCount: 2, notifiedCloudIds: ['c1'] }, firstNotifiedAt: 'F',
    },
  });
  const result = await deleteMemberData('me', { firestore });

  assert.equal(result.keptPlus, true);
  assert.deepEqual(firestore.docs.get('member_server/me'), {
    isPlus: true, plusProductId: 'plus_monthly', plusStore: 'APP_STORE', plusEnvironment: 'PRODUCTION',
    plusExpiresAt: 'T', plusLastEvent: 'RENEWAL', plusUpdatedAt: 'U',
  });
  assert.equal(firestore.docs.has('members/me'), false);
  assert.equal(firestore.docs.has('reports/r1'), false);
});

test('plusOnly: Plus でなければ null、Plus なら決まったフィールドだけ', () => {
  assert.equal(plusOnly(undefined), null);
  assert.equal(plusOnly({ isPlus: false }), null);
  assert.deepEqual(plusOnly({ isPlus: true, notification: {}, plusProductId: 'x' }), { isPlus: true, plusProductId: 'x' });
});

test('uid が空なら何も消さない', async () => {
  const firestore = setup();
  await assert.rejects(() => deleteMemberData('', { firestore }));
  await assert.rejects(() => deleteMemberData(undefined, { firestore }));
  assert.equal(firestore.docs.has('members/me'), true);
});
