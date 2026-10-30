const { test } = require('node:test');
const assert = require('node:assert/strict');
const { deleteMemberData } = require('../modules/account/account_service');
const FakeFirestore = require('./helpers/fake_firestore');

function setup() {
  const firestore = new FakeFirestore();
  firestore.docs.set('members/me', { platform: 'ios' });
  firestore.docs.set('member_server/me', { isPlus: true });
  firestore.docs.set('reports/r1', { uid: 'me', seen: true });
  firestore.docs.set('reports/r2', { uid: 'me', seen: false });
  firestore.docs.set('members/other', { platform: 'android' });
  firestore.docs.set('member_server/other', { isPlus: false });
  firestore.docs.set('reports/r3', { uid: 'other', seen: true });
  const deleted = [];
  const auth = { async deleteUser(uid) { deleted.push(uid); } };
  return { firestore, auth, deleted };
}

test('自分の members・member_server・reports を消して、アカウントも消す。他人のものは残す', async () => {
  const { firestore, auth, deleted } = setup();
  const result = await deleteMemberData('me', { firestore, auth });

  assert.equal(result.reports, 2);
  assert.equal(firestore.docs.has('members/me'), false);
  assert.equal(firestore.docs.has('member_server/me'), false);
  assert.equal(firestore.docs.has('reports/r1'), false);
  assert.equal(firestore.docs.has('reports/r2'), false);
  assert.equal(firestore.docs.has('members/other'), true);
  assert.equal(firestore.docs.has('member_server/other'), true);
  assert.equal(firestore.docs.has('reports/r3'), true);
  assert.deepEqual(deleted, ['me']);
});

test('アカウントがもうないときは、消せたことにする。ほかの失敗はそのまま投げる', async () => {
  const { firestore } = setup();
  const gone = { async deleteUser() { const e = new Error('no user'); e.code = 'auth/user-not-found'; throw e; } };
  await deleteMemberData('me', { firestore, auth: gone });

  const broken = { async deleteUser() { const e = new Error('boom'); e.code = 'auth/internal-error'; throw e; } };
  await assert.rejects(() => deleteMemberData('me', { firestore: setup().firestore, auth: broken }), /boom/);
});

test('uid が空なら何も消さない', async () => {
  const { firestore, auth } = setup();
  await assert.rejects(() => deleteMemberData('', { firestore, auth }));
  await assert.rejects(() => deleteMemberData(undefined, { firestore, auth }));
  assert.equal(firestore.docs.has('members/me'), true);
});
