// functions/modules/cleanup/cleanup_service.js
const admin = require('firebase-admin');
const WeatherCache = require('../weather/weather_cache');
const { WEATHER_CONSTANTS } = require('../../constants');

class CleanupService {
  constructor() {
    this.firestore = admin.firestore();
    this.weatherCache = new WeatherCache();
  }

  /**
   * 気象データキャッシュクリーンアップ
   */
  async cleanupWeatherCache() {
    console.log('🧹 気象データキャッシュクリーンアップ開始');

    try {
      const deletedCount = await this.weatherCache.cleanup(
        WEATHER_CONSTANTS.CACHE_CLEANUP_RETENTION_HOURS,
        WEATHER_CONSTANTS.CACHE_CLEANUP_BATCH_SIZE
      );

      console.log(`✅ 気象データキャッシュクリーンアップ完了: ${deletedCount}件削除`);
      return deletedCount;
    } catch (error) {
      console.error('❌ 気象データキャッシュクリーンアップエラー:', error);
      return 0;
    }
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

      // 各写真を個別に削除（Storage + Firestore + 関連データ）
      for (const doc of snapshot.docs) {
        try {
          const data = doc.data();
          const photoId = doc.id;
          const imageUrl = data.imageUrl;

          // Firebase Storageから画像を削除
          if (imageUrl) {
            try {
              const bucket = admin.storage().bucket();
              const fileName = imageUrl.split('/').pop().split('?')[0]; // URLからファイル名を抽出
              const file = bucket.file(`photos/${data.userId}/${fileName}`);
              await file.delete();
              console.log(`🗑️ Storage画像削除: ${photoId}`);
            } catch (storageError) {
              console.warn(`⚠️ Storage削除エラー（継続）: ${photoId} - ${storageError.message}`);
            }
          }

          // 関連するいいねを削除
          const likesSnapshot = await this.firestore
            .collection('likes')
            .where('photoId', '==', photoId)
            .get();

          const likeBatch = this.firestore.batch();
          likesSnapshot.docs.forEach((likeDoc) => {
            likeBatch.delete(likeDoc.ref);
          });

          if (likesSnapshot.docs.length > 0) {
            await likeBatch.commit();
            console.log(`🗑️ 関連いいね削除: ${photoId} (${likesSnapshot.docs.length}件)`);
          }

          // Firestoreから写真データを削除
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

  /**
   * 期限切れいいねの自動削除
   */
  async cleanupExpiredLikes() {
    console.log('🧹 期限切れいいねクリーンアップ開始');

    try {
      const now = new Date();
      const batchSize = 500; // いいねは軽量なので多めに処理
      let totalDeleted = 0;

      console.log(`📅 ${now.toISOString()} 時点で期限切れのいいねを削除`);

      // 期限切れのいいねを検索
      const snapshot = await this.firestore
        .collection('likes')
        .where('expiresAt', '<=', now)
        .limit(batchSize)
        .get();

      if (snapshot.empty) {
        console.log('✅ 削除対象の期限切れいいねなし');
        return 0;
      }

      console.log(`🗑️ ${snapshot.docs.length}件の期限切れいいねを削除中...`);

      // バッチ削除で効率化
      const batch = this.firestore.batch();
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      totalDeleted = snapshot.docs.length;

      console.log(`✅ 期限切れいいねクリーンアップ完了: ${totalDeleted}件削除`);

      // 大量のデータがある場合の通知
      if (snapshot.docs.length === batchSize) {
        console.log('🔄 さらに期限切れいいねが存在する可能性があります');
      }

      return totalDeleted;

    } catch (error) {
      console.error('❌ 期限切れいいねクリーンアップエラー:', error);
      return 0;
    }
  }
}

module.exports = CleanupService;
