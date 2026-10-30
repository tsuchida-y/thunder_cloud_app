/**
 * 利用者が自分でデータを消す（設定の「データを削除」）
 *
 * 消すのは、位置・見張る場所・設定・通知の宛先（members）、通知の記録（member_server）、
 * 「見えた」「見えなかった」の答え（reports）。cleanupInactiveMembers（1年開いていない人の削除）と同じ範囲。
 *
 * 残すのは、Plus の状態だけ（isPlus、期限、プラン）。消すと、削除のあとも Plus を使い続けられなくなる
 * （購入はストアに残るが、サーバーの通知の範囲は member_server の Plus を見るため）。
 * 匿名ログインのアカウント（uid）も消さない。iPhone は入れ直しても同じ uid が続くので、
 * uid を消すと購入の復元（TRANSFER）で Plus を移せなくなる。
 */

const admin = require('firebase-admin');
const { COLLECTIONS } = require('../../constants');

const BATCH_SIZE = 450;

/** member_server のうち、削除のあとも残す Plus の状態のフィールド */
const PLUS_FIELDS = [
  'isPlus', 'plusExpiresAt', 'plusProductId', 'plusStore', 'plusEnvironment', 'plusLastEvent', 'plusUpdatedAt',
];

/** Plus の状態だけを取り出す。Plus でなければ null（member_server ごと消してよい） */
function plusOnly(server) {
  if (!server || server.isPlus !== true) return null;
  const kept = {};
  PLUS_FIELDS.forEach((key) => {
    if (server[key] !== undefined) kept[key] = server[key];
  });
  return kept;
}

/**
 * @param {string} uid - 消す人の uid（呼び出した本人。認証で確かめたものだけを渡す）
 * @param {Object} [deps]
 * @param {FirebaseFirestore.Firestore} [deps.firestore]
 * @returns {Promise<{reports:number, keptPlus:boolean}>}
 */
async function deleteMemberData(uid, { firestore = admin.firestore() } = {}) {
  if (typeof uid !== 'string' || uid === '') throw new Error('uid がありません');

  const serverRef = firestore.collection(COLLECTIONS.MEMBER_SERVER).doc(uid);
  const kept = plusOnly((await serverRef.get()).data());
  const reports = await firestore.collection(COLLECTIONS.REPORTS).where('uid', '==', uid).get();

  const refs = [firestore.collection(COLLECTIONS.MEMBERS).doc(uid), ...reports.docs.map((doc) => doc.ref)];
  if (!kept) refs.push(serverRef);
  for (let i = 0; i < refs.length; i += BATCH_SIZE) {
    const batch = firestore.batch();
    refs.slice(i, i + BATCH_SIZE).forEach((ref) => batch.delete(ref));
    await batch.commit();
  }
  // Plus の人は、通知の記録などを落として、Plus の状態だけにする（merge しない）
  if (kept) await serverRef.set(kept);
  return { reports: reports.docs.length, keptPlus: Boolean(kept) };
}

module.exports = { deleteMemberData, plusOnly };
