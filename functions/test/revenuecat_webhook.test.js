const { test } = require('node:test');
const assert = require('node:assert/strict');
const { planUpdate, planTransfer, sameSecret, handleWebhook } = require('../modules/plus/revenuecat_webhook');
const FakeFirestore = require('./helpers/fake_firestore');

const expires = Date.parse('2027-08-12T00:00:00Z');
const event = (type, extra = {}) => ({
  type, app_user_id: 'uid1', entitlement_ids: ['plus'], expiration_at_ms: expires,
  product_id: 'plus_monthly', store: 'APP_STORE', environment: 'SANDBOX', ...extra,
});

test('購入・更新は Plus にして期限を書く', () => {
  const plan = planUpdate(event('INITIAL_PURCHASE'));
  assert.equal(plan.uid, 'uid1');
  assert.equal(plan.update.isPlus, true);
  assert.equal(plan.update.plusExpiresAt.getTime(), expires);
  assert.equal(planUpdate(event('RENEWAL')).update.isPlus, true);
});

test('解約しても期限までは Plus、期限切れで Plus をやめる', () => {
  assert.equal(planUpdate(event('CANCELLATION')).update.isPlus, true);
  assert.equal(planUpdate(event('EXPIRATION')).update.isPlus, false);
});

test('買い切りは期限なしの Plus にし、返金されたら Plus をやめる', () => {
  const lifetime = { expiration_at_ms: null, product_id: 'plus_lifetime' };
  const bought = planUpdate(event('NON_RENEWING_PURCHASE', lifetime));
  assert.equal(bought.update.isPlus, true);
  assert.equal(bought.update.plusExpiresAt, null);
  assert.equal(planUpdate(event('CANCELLATION', lifetime)).update.isPlus, false);
});

test('匿名の購入、ほかの権利、テストのイベントは何もしない', () => {
  assert.ok(planUpdate(event('INITIAL_PURCHASE', { app_user_id: '$RCAnonymousID:abc' })).skip);
  assert.ok(planUpdate(event('INITIAL_PURCHASE', { entitlement_ids: ['other'] })).skip);
  assert.ok(planUpdate({ type: 'TEST', app_user_id: 'uid1' }).skip);
});

function fakeRes() {
  return { code: 0, status(c) { this.code = c; return this; }, send() { return this; } };
}

test('合言葉が違う webhook は断り、正しければ member_server に書く', async () => {
  const firestore = new FakeFirestore();
  const req = (auth) => ({ method: 'POST', get: () => auth, body: { event: event('INITIAL_PURCHASE') } });

  const bad = fakeRes();
  await handleWebhook(req('wrong'), bad, { authToken: 'secret', firestore });
  assert.equal(bad.code, 401);
  assert.equal(firestore.docs.has('member_server/uid1'), false);

  const ok = fakeRes();
  await handleWebhook(req('secret'), ok, { authToken: 'secret', firestore });
  assert.equal(ok.code, 200);
  const doc = firestore.docs.get('member_server/uid1');
  assert.equal(doc.isPlus, true);
  assert.equal(doc.plusExpiresAt.toDate().getTime(), expires);
});

test('合言葉の比べ方: 同じなら true、違う・空・文字列でなければ false', () => {
  assert.equal(sameSecret('secret', 'secret'), true);
  assert.equal(sameSecret('secreT', 'secret'), false);
  assert.equal(sameSecret('', 'secret'), false);
  assert.equal(sameSecret(undefined, 'secret'), false);
});

test('TRANSFER: 移す元の Plus の状態を、移す先にコピーする', () => {
  const plan = planTransfer(
    { type: 'TRANSFER', transferred_from: ['old'], transferred_to: ['new'] },
    { old: { isPlus: true, plusProductId: 'plus_monthly', plusStore: 'APP_STORE', plusEnvironment: 'PRODUCTION', plusExpiresAt: 'T' } },
  );
  assert.deepEqual(plan.to, ['new']);
  assert.equal(plan.copy.isPlus, true);
  assert.equal(plan.copy.plusProductId, 'plus_monthly');
  assert.equal(plan.copy.plusExpiresAt, 'T');
});

test('TRANSFER: 元が Plus でない、移す先がない、匿名だけのときは何もしない', () => {
  const evt = (from, to) => ({ type: 'TRANSFER', transferred_from: from, transferred_to: to });
  assert.ok(planTransfer(evt(['old'], ['new']), { old: { isPlus: false } }).skip);
  assert.ok(planTransfer(evt(['old'], ['new']), {}).skip);
  assert.ok(planTransfer(evt(['old'], []), { old: { isPlus: true } }).skip);
  assert.ok(planTransfer(evt(['$RCAnonymousID:x'], ['$RCAnonymousID:y']), {}).skip);
});

test('TRANSFER の webhook: 新しい uid に Plus が付き、古い uid は外れる', async () => {
  const firestore = new FakeFirestore();
  await firestore.collection('member_server').doc('old').set({
    isPlus: true, plusProductId: 'plus_lifetime', plusExpiresAt: null, plusStore: 'APP_STORE', plusEnvironment: 'PRODUCTION',
  });
  const req = {
    method: 'POST', get: () => 'secret',
    body: { event: { type: 'TRANSFER', transferred_from: ['old'], transferred_to: ['new'] } },
  };
  const res = fakeRes();
  await handleWebhook(req, res, { authToken: 'secret', firestore });
  assert.equal(res.code, 200);
  assert.equal(firestore.docs.get('member_server/new').isPlus, true);
  assert.equal(firestore.docs.get('member_server/new').plusProductId, 'plus_lifetime');
  assert.equal(firestore.docs.get('member_server/old').isPlus, false);
});
