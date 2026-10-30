/**
 * 利用者が自分でデータを消す（設定の「データを削除」）
 *
 * members、member_server、自分の reports を消して、匿名ログインのアカウントも消す。
 * cleanupInactiveMembers（1年開いていない人の削除）と同じ範囲。
 * Plus の購入そのものは RevenueCat とストアに残る（消えない）ので、削除のあとに「購入を復元」で戻せる。
 */

const admin = require('firebase-admin');
const { COLLECTIONS } = require('../../constants');

const BATCH_SIZE = 450;

/**
 * @param {string} uid - 消す人の uid（呼び出した本人。認証で確かめたものだけを渡す）
 * @param {Object} [deps]
 * @param {FirebaseFirestore.Firestore} [deps.firestore]
 * @param {{deleteUser: function(string): Promise<void>}} [deps.auth]
 * @returns {Promise<{reports:number}>} 消した reports の数
 */
async function deleteMemberData(uid, { firestore = admin.firestore(), auth = admin.auth() } = {}) {
  if (typeof uid !== 'string' || uid === '') throw new Error('uid がありません');

  const reports = await firestore.collection(COLLECTIONS.REPORTS).where('uid', '==', uid).get();
  const refs = [
    firestore.collection(COLLECTIONS.MEMBERS).doc(uid),
    firestore.collection(COLLECTIONS.MEMBER_SERVER).doc(uid),
    ...reports.docs.map((doc) => doc.ref),
  ];
  for (let i = 0; i < refs.length; i += BATCH_SIZE) {
    const batch = firestore.batch();
    refs.slice(i, i + BATCH_SIZE).forEach((ref) => batch.delete(ref));
    await batch.commit();
  }

  try {
    await auth.deleteUser(uid);
  } catch (error) {
    // すでにアカウントがないときは、消せたことにする
    if (!error || error.code !== 'auth/user-not-found') throw error;
  }
  return { reports: reports.docs.length };
}

module.exports = { deleteMemberData };
