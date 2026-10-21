const { test } = require('node:test');
const assert = require('node:assert/strict');
const { planUpdate, handleWebhook } = require('../modules/plus/revenuecat_webhook');
const FakeFirestore = require('./helpers/fake_firestore');

const expires = Date.parse('2027-08-12T00:00:00Z');
const event = (type, extra = {}) => ({
  type, app_user_id: 'uid1', entitlement_ids: ['plus'], expiration_at_ms: expires,
  product_id: 'plus_yearly', store: 'APP_STORE', environment: 'SANDBOX', ...extra,
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
