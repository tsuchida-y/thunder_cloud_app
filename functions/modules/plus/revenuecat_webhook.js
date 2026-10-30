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
 * - 買った人が入れ直して購入を復元すると、RevenueCat は権利を新しい uid に移し、TRANSFER を送る（期限は付かない）。
 *   移す元の member_server が持つ Plus の状態（期限、プラン）を、移す先にコピーして、元は外す
 * - RevenueCat の管理画面で決めた合言葉を Authorization ヘッダーで受け取り、違えば断る
 */

const crypto = require('crypto');
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

const PLUS_FIELDS = ['plusProductId', 'plusStore', 'plusEnvironment', 'plusExpiresAt'];

const isRealUid = (id) => typeof id === 'string' && id !== '' && !id.startsWith('$RCAnonymousID');

/**
 * TRANSFER（購入の復元で、権利が別の uid に移った）で書く内容を決める（Firestore に触れない部分）
 *
 * @param {Object} event - transferred_from, transferred_to を持つ
 * @param {Object<string, Object>} serverDocs - 移す元の uid ごとの member_server の中身
 * @returns {{skip:string}|{copy:Object, to:string[], from:string[]}} copy は移す先に書く Plus の状態
 */
function planTransfer(event, serverDocs) {
  const from = (event.transferred_from || []).filter(isRealUid);
  const to = (event.transferred_to || []).filter(isRealUid);
  if (to.length === 0) return { skip: 'no_destination' };
  const source = from.map((id) => serverDocs[id]).find((doc) => doc && doc.isPlus === true);
  if (!source) return { skip: 'source_not_plus' };
  const copy = { isPlus: true, plusLastEvent: 'TRANSFER' };
  PLUS_FIELDS.forEach((key) => {
    copy[key] = source[key] === undefined ? null : source[key];
  });
  return { copy, to, from };
}

/** 合言葉を、一定の時間で比べる（比べる時間から中身を推測されないように） */
function sameSecret(given, expected) {
  if (typeof given !== 'string' || typeof expected !== 'string') return false;
  const a = crypto.createHash('sha256').update(given).digest();
  const b = crypto.createHash('sha256').update(expected).digest();
  return crypto.timingSafeEqual(a, b);
}

async function handleTransfer(event, firestore) {
  const collection = firestore.collection(COLLECTIONS.MEMBER_SERVER);
  const serverDocs = {};
  for (const id of (event.transferred_from || []).filter(isRealUid)) {
    const snap = await collection.doc(id).get();
    if (snap.exists) serverDocs[id] = snap.data();
  }
  const plan = planTransfer(event, serverDocs);
  if (plan.skip) {
    console.log(`💳 [REVENUECAT] TRANSFER は何もしない（${plan.skip}）`);
    return;
  }
  for (const id of plan.to) {
    await collection.doc(id).set(
      { ...plan.copy, plusUpdatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true },
    );
  }
  for (const id of plan.from) {
    if (plan.to.includes(id)) continue;
    await collection.doc(id).set({
      isPlus: false,
      plusExpiresAt: null,
      plusLastEvent: 'TRANSFER',
      plusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  console.log(`💳 [REVENUECAT] TRANSFER: Plus を ${plan.to.length} 件に移しました`);
}

/**
 * webhook の本体（firebase-functions の onRequest から呼ぶ）
 */
async function handleWebhook(req, res, { authToken, firestore = admin.firestore() }) {
  if (req.method !== 'POST') {
    res.status(405).send('POST only');
    return;
  }
  if (!authToken || !sameSecret(req.get('Authorization'), authToken)) {
    console.warn('⚠️ [REVENUECAT] 合言葉が違う webhook を断りました');
    res.status(401).send('unauthorized');
    return;
  }

  const event = req.body && req.body.event;
  if (event && event.type === 'TRANSFER') {
    await handleTransfer(event, firestore);
    res.status(200).send('ok');
    return;
  }
  const plan = planUpdate(event);
  if (plan.skip) {
    // 権利の ID が違うと読み飛ばすので、何が付いていたかも残す（2026-10-29 に RevenueCat の権利の ID の違いで起きた）
    const entitlements = event && Array.isArray(event.entitlement_ids) ? event.entitlement_ids.join(',') : '';
    console.log(`💳 [REVENUECAT] ${event && event.type} は何もしない（${plan.skip}）` +
      (entitlements ? ` 権利: ${entitlements}` : ''));
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

module.exports = { planUpdate, planTransfer, sameSecret, handleWebhook };
