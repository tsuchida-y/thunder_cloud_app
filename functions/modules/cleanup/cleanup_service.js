// functions/modules/cleanup/cleanup_service.js
const admin = require('firebase-admin');
const { COLLECTIONS, JMA_NOWCAST, CLOUD_RETENTION_DAYS, INACTIVE_MEMBER_DAYS } = require('../../constants');

class CleanupService {
  get firestore() {
    return admin.firestore();
  }

  /**
   * 終わってから日数がたった雲を消す
   *
   * 「見えた」記録（reports）には、消す前に雲が見えていた時間（cloudFirstSeenAt, cloudLastSeenAt）を写す。
   * アプリの記録の画面は「14:20〜15:40」をそこから出すので、雲そのものは数日で消してよい。
   */
  async cleanupOldClouds(now = new Date()) {
    const threshold = new Date(now.getTime() - CLOUD_RETENTION_DAYS * 24 * 60 * 60 * 1000);
    let totalDeleted = 0;
    try {
      // status と lastSeenAt の組み合わせの索引を作らずに済むよう、終わった雲を取ってから日付で絞る
      const snapshot = await this.firestore.collection(JMA_NOWCAST.CLOUDS_COLLECTION)
        .where('status', '==', 'ended').get();
      const oldDocs = snapshot.docs.filter((doc) => doc.data().lastSeenAt.toDate() < threshold);
      await this._copyCloudTimesToReports(oldDocs);
      for (let i = 0; i < oldDocs.length; i += 450) {
        const batch = this.firestore.batch();
        oldDocs.slice(i, i + 450).forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
      }
      totalDeleted = oldDocs.length;
      console.log(`🧹 終わった雲を${totalDeleted}件削除しました（${CLOUD_RETENTION_DAYS}日より前）`);
    } catch (error) {
      console.error('❌ 古い雲の削除に失敗しました:', error);
    }
    return totalDeleted;
  }

  /**
   * 最後にアプリを開いてから1年たった利用者の情報を消す（プライバシーポリシーの「保存する期間」）
   *
   * members、member_server、その人の reports を消す。Plus の期間が残っている人は消さない。
   * 「常に」の人のバックグラウンドの位置の更新は lastOpenedAt を変えないので、開いていなければ消える。
   */
  async cleanupInactiveMembers(now = new Date()) {
    const threshold = new Date(now.getTime() - INACTIVE_MEMBER_DAYS * 24 * 60 * 60 * 1000);
    let deleted = 0;
    try {
      const members = await this.firestore.collection(COLLECTIONS.MEMBERS).get();
      for (const doc of members.docs) {
        const data = doc.data();
        const lastOpenedAt = data.lastOpenedAt && data.lastOpenedAt.toDate ? data.lastOpenedAt.toDate() : null;
        const createdAt = data.createdAt && data.createdAt.toDate ? data.createdAt.toDate() : null;
        const lastSeen = lastOpenedAt || createdAt;
        if (!lastSeen || lastSeen >= threshold) continue;

        const serverRef = this.firestore.collection(COLLECTIONS.MEMBER_SERVER).doc(doc.id);
        const server = (await serverRef.get()).data();
        const plusUntil = server && server.plusExpiresAt && server.plusExpiresAt.toDate ? server.plusExpiresAt.toDate() : null;
        if (server && server.isPlus && (!plusUntil || plusUntil > now)) continue;

        const reports = await this.firestore.collection(COLLECTIONS.REPORTS).where('uid', '==', doc.id).get();
        const refs = [doc.ref || this.firestore.collection(COLLECTIONS.MEMBERS).doc(doc.id), serverRef, ...reports.docs.map((r) => r.ref)];
        for (let i = 0; i < refs.length; i += 450) {
          const batch = this.firestore.batch();
          refs.slice(i, i + 450).forEach((ref) => batch.delete(ref));
          await batch.commit();
        }
        deleted++;
      }
      console.log(`🧹 ${INACTIVE_MEMBER_DAYS}日開いていない利用者${deleted}人の情報を削除しました`);
    } catch (error) {
      console.error('❌ 開いていない利用者の削除に失敗しました:', error);
    }
    return deleted;
  }

  /**
   * 消す雲に答えた reports に、雲が見えていた時間を写す
   */
  async _copyCloudTimesToReports(cloudDocs) {
    const times = new Map(cloudDocs.map((doc) => [doc.id, doc.data()]));
    const ids = [...times.keys()];
    let copied = 0;
    // in の問い合わせは30件まで
    for (let i = 0; i < ids.length; i += 30) {
      const reports = await this.firestore.collection(COLLECTIONS.REPORTS)
        .where('cloudId', 'in', ids.slice(i, i + 30)).get();
      const updates = reports.docs.filter((doc) => !doc.data().cloudFirstSeenAt);
      for (let j = 0; j < updates.length; j += 450) {
        const batch = this.firestore.batch();
        updates.slice(j, j + 450).forEach((doc) => {
          const cloud = times.get(doc.data().cloudId);
          batch.update(doc.ref, { cloudFirstSeenAt: cloud.firstSeenAt, cloudLastSeenAt: cloud.lastSeenAt });
        });
        await batch.commit();
      }
      copied += updates.length;
    }
    if (copied > 0) console.log(`🧹 見えた記録${copied}件に、雲が見えていた時間を写しました`);
  }

  /**
   * 期限切れ写真の自動削除
   */
  async cleanupExpiredPhotos() {
    console.log('🧹 期限切れ写真クリーンアップ開始');

    try {
      const now = new Date();
      const batchSize = 100; // 一度に処理する写真数
      let totalDeleted = 0;

      console.log(`📅 ${now.toISOString()} 時点で期限切れの写真を削除`);

      // 期限切れの写真を検索
      const snapshot = await this.firestore
        .collection('photos')
        .where('expiresAt', '<=', now)
        .limit(batchSize)
        .get();

      if (snapshot.empty) {
        console.log('✅ 削除対象の期限切れ写真なし');
        return 0;
      }

      console.log(`🗑️ ${snapshot.docs.length}件の期限切れ写真を削除中...`);

      // 各写真を個別に削除（Storage + Firestore）
      for (const doc of snapshot.docs) {
        try {
          const data = doc.data();
          const photoId = doc.id;
          const imageUrl = data.imageUrl;

          // Firebase Storageから画像を削除
          if (imageUrl) {
            try {
              const bucket = admin.storage().bucket();
              // ダウンロードURLの /o/ 以降はURLエンコードされたオブジェクトパス（photos%2F{userId}%2F{file}）
              const encodedPath = imageUrl.split('?')[0].split('/o/')[1];
              const filePath = encodedPath ?
                decodeURIComponent(encodedPath) :
                `photos/${data.userId}/${imageUrl.split('/').pop().split('?')[0]}`;
              const file = bucket.file(filePath);
              await file.delete();
              console.log(`🗑️ Storage画像削除: ${photoId}`);
            } catch (storageError) {
              console.warn(`⚠️ Storage削除エラー（継続）: ${photoId} - ${storageError.message}`);
            }
          }

          // Firestoreから写真データを削除（いいね情報も一緒に削除される）
          await doc.ref.delete();
          totalDeleted++;

          console.log(`✅ 期限切れ写真削除完了: ${photoId}`);

        } catch (photoError) {
          console.error(`❌ 写真削除エラー: ${doc.id} - ${photoError.message}`);
        }
      }

      console.log(`✅ 期限切れ写真クリーンアップ完了: ${totalDeleted}件削除`);

      // 大量のデータがある場合の通知
      if (snapshot.docs.length === batchSize) {
        console.log('🔄 さらに期限切れ写真が存在する可能性があります');
      }

      return totalDeleted;

    } catch (error) {
      console.error('❌ 期限切れ写真クリーンアップエラー:', error);
      return 0;
    }
  }
}

module.exports = CleanupService;
