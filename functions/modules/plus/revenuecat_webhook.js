/**
 * RevenueCat の webhook で、Plus かどうかを member_server に書く
 *
 * - アプリは RevenueCat に Firebase の匿名ログインの uid を「アプリのユーザー ID」として渡す（Purchases.logIn）。
 *   なので、イベントの app_user_id がそのまま member_server/{uid} の uid になる
 * - member_server はサーバーだけが書く（firestore.rules）。通知の見張り（cloud_watch_service.js）は
 *   isPlus と plusExpiresAt を見て、範囲 90km と見張る場所3か所を使う
 * - 月額: 解約（CANCELLATION）しても期限までは Plus のまま。期限切れ（EXPIRATION）で Plus をやめる
 * - 買い切り（2026-10-27 から）: NON_RENEWING_PURCHASE で期限なしの Plus にする。
 *   返金されたとき（期限のない CANCELLATION）は Plus をやめる
 * - RevenueCat の管理画面で決めた合言葉を Authorization ヘッダーで受け取り、違えば断る
 */

const admin = require('firebase-admin');
const { COLLECTIONS } = require('../../constants');

/** Plus を有効にする（期限を延ばす）イベント */
const ACTIVATE_EVENTS = new Set([
  'INITIAL_PURCHASE',
  'RENEWAL',
  'PRODUCT_CHANGE',
  'UNCANCELLATION',
  'NON_RENEWING_PURCHASE',
  'SUBSCRIPTION_EXTENDED',
  'TEMPORARY_ENTITLEMENT_GRANT',
]);

/** Plus のまま、期限だけを書き直すイベント（解約しても期限までは使える。支払いの問題は猶予期間がある） */
const KEEP_EVENTS = new Set(['CANCELLATION', 'BILLING_ISSUE', 'SUBSCRIPTION_PAUSED']);

/** Plus をやめるイベント */
const DEACTIVATE_EVENTS = new Set(['EXPIRATION']);

/**
 * イベントから member_server に書く内容を決める（Firestore に触れない部分）
 *
 * @returns {{uid:string, update:Object}|{skip:string}}
 */
function planUpdate(event, entitlementId = 'plus') {
  if (!event || !event.type) return { skip: 'no_event' };
  if (event.type === 'TEST') return { skip: 'test_event' };

  const uid = event.app_user_id;
  if (!uid || uid.startsWith('$RCAnonymousID')) return { skip: 'anonymous_user' };

  const entitlements = event.entitlement_ids || [];
  if (entitlements.length > 0 && !entitlements.includes(entitlementId)) return { skip: 'other_entitlement' };

  const expiresAt = typeof event.expiration_at_ms === 'number' ? new Date(event.expiration_at_ms) : null;
  const common = {
    plusProductId: event.product_id || null,
    plusStore: event.store || null,
    plusEnvironment: event.environment || null,
    plusLastEvent: event.type,
  };

  // 買い切りの返金。期限のない購入の CANCELLATION は、解約ではなく返金を表す
  if (event.type === 'CANCELLATION' && expiresAt === null) {
    return { uid, update: { ...common, isPlus: false, plusExpiresAt: null } };
  }
  if (ACTIVATE_EVENTS.has(event.type) || KEEP_EVENTS.has(event.type)) {
    return { uid, update: { ...common, isPlus: true, plusExpiresAt: expiresAt } };
  }
  if (DEACTIVATE_EVENTS.has(event.type)) {
    return { uid, update: { ...common, isPlus: false, plusExpiresAt: expiresAt } };
  }
  return { skip: `ignored_${event.type}` };
}

/**
 * webhook の本体（firebase-functions の onRequest から呼ぶ）
 */
async function handleWebhook(req, res, { authToken, firestore = admin.firestore() }) {
  if (req.method !== 'POST') {
    res.status(405).send('POST only');
    return;
  }
  if (!authToken || req.get('Authorization') !== authToken) {
    console.warn('⚠️ [REVENUECAT] 合言葉が違う webhook を断りました');
    res.status(401).send('unauthorized');
    return;
  }

  const event = req.body && req.body.event;
  const plan = planUpdate(event);
  if (plan.skip) {
    console.log(`💳 [REVENUECAT] ${event && event.type} は何もしない（${plan.skip}）`);
    res.status(200).send('ok');
    return;
  }

  const update = {
    ...plan.update,
    plusExpiresAt: plan.update.plusExpiresAt ? admin.firestore.Timestamp.fromDate(plan.update.plusExpiresAt) : null,
    plusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await firestore.collection(COLLECTIONS.MEMBER_SERVER).doc(plan.uid).set(update, { merge: true });
  console.log(`💳 [REVENUECAT] ${event.type}: isPlus=${update.isPlus}（${event.environment}）`);
  res.status(200).send('ok');
}

module.exports = { planUpdate, handleWebhook };
