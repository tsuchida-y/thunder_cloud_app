// functions/modules/cleanup/cleanup_service.js
const admin = require('firebase-admin');
const { JMA_NOWCAST, CLOUD_RETENTION_DAYS } = require('../../constants');

class CleanupService {
  get firestore() {
    return admin.firestore();
  }

  /**
   * 終わってから日数がたった雲を消す
   *
   * 「見えた」記録は reports に雲の場所と時刻を写して残すので、雲そのものは数日で消してよい。
   */
  async cleanupOldClouds(now = new Date()) {
    const threshold = new Date(now.getTime() - CLOUD_RETENTION_DAYS * 24 * 60 * 60 * 1000);
    let totalDeleted = 0;
    try {
      // status と lastSeenAt の組み合わせの索引を作らずに済むよう、終わった雲を取ってから日付で絞る
      const snapshot = await this.firestore.collection(JMA_NOWCAST.CLOUDS_COLLECTION)
        .where('status', '==', 'ended').get();
      const oldDocs = snapshot.docs.filter((doc) => doc.data().lastSeenAt.toDate() < threshold);
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
