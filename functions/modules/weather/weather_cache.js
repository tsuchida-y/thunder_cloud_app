/**
 * 気象データキャッシュ管理クラス
 *
 * Firestoreを使用した気象データの効率的なキャッシュシステム
 * API呼び出し回数を削減し、レスポンス速度向上とコスト削減を実現
 *
 * 主な機能:
 * - 気象データの保存・取得
 * - キャッシュ有効期限管理
 * - 方向別・距離別データの構造化保存
 * - 期限切れデータの自動クリーンアップ
 * - キャッシュ統計情報の提供
 *
 * キャッシュ戦略:
 * - 有効期限: 設定可能（デフォルト: 30分）
 * - キーパターン: "lat_lon" (例: "35.6762_139.6503")
 * - データ構造: 方向別・距離別のネストされたオブジェクト
 */

const admin = require('firebase-admin');
const { WEATHER_CONSTANTS, HelperFunctions } = require('../../constants');

class WeatherCache {
  constructor() {
    this.firestore = admin.firestore();
    this.CACHE_DURATION = WEATHER_CONSTANTS.CACHE_DURATION_MS;
  }

  /**
   * キャッシュからデータを取得
   *
   * @param {number} lat - 緯度
   * @param {number} lon - 経度
   * @returns {Object|null} キャッシュされた気象データ（期限切れ・存在しない場合はnull）
   *
   * 処理フロー:
   * 1. 座標からキャッシュキーを生成
   * 2. Firestoreからドキュメント取得
   * 3. 有効期限チェック（現在時刻 - 保存時刻 < 有効期限）
   * 4. 有効な場合はデータを返却、無効な場合はnull
   *
   * パフォーマンス:
   * - キャッシュヒット時: API呼び出し0回
   * - 応答時間: ~50ms (vs API直接: ~500ms)
   */
  async get(lat, lon) {
    const cacheKey = HelperFunctions.generateCacheKey(lat, lon);
    const now = new Date();

    try {
      const cacheDoc = await this.firestore.collection('weather_cache').doc(cacheKey).get();

      if (cacheDoc.exists) {
        const cachedData = cacheDoc.data();
        const cacheTime = cachedData.timestamp.toDate();

        // キャッシュが有効期限内の場合
        if (now.getTime() - cacheTime.getTime() < this.CACHE_DURATION) {
          console.log(`✅ キャッシュからデータを取得: ${cacheKey}`);
          return cachedData.data;
        }
      }

      return null;
    } catch (error) {
      console.error(`❌ キャッシュ取得エラー (${cacheKey}):`, error);
      return null;
    }
  }

  /**
   * データをキャッシュに保存
   *
   * @param {number} lat - 緯度
   * @param {number} lon - 経度
   * @param {Object} data - 保存する気象データ
   * @param {string} cacheType - キャッシュタイプ ('standard', 'multi_distance_directional')
   *
   * 保存データ構造:
   * - data: 気象データ本体
   * - timestamp: 保存時刻（有効期限計算用）
   * - location: 座標情報（デバッグ・管理用）
   * - cacheType: データ形式識別子
   *
   * 保存先: Firestore collection 'weather_cache'
   * 上書き方式: 同一キーの場合は新しいデータで上書き
   */
  async set(lat, lon, data, cacheType = 'standard') {
    const cacheKey = HelperFunctions.generateCacheKey(lat, lon);
    const now = new Date();

    try {
      await this.firestore.collection('weather_cache').doc(cacheKey).set({
        data: data,
        timestamp: now,
        location: { lat, lon },
        cacheType: cacheType
      });

      console.log(`✅ キャッシュ保存完了: ${cacheKey}`);
    } catch (error) {
      console.error(`❌ キャッシュ保存エラー (${cacheKey}):`, error);
    }
  }

  /**
   * 方向別・距離別の複合気象データをキャッシュに保存
   *
   * @param {number} lat - 中心座標の緯度
   * @param {number} lon - 中心座標の経度
   * @param {Object} directionalData - 方向別データオブジェクト
   *
   * データ構造例:
   * {
   *   "north": {
   *     "5km": { coordinates: {}, analysis: {}, cape: 100, ... },
   *     "10km": { coordinates: {}, analysis: {}, cape: 150, ... }
   *   },
   *   "south": { ... }
   * }
   *
   * 用途:
   * - 入道雲監視システムの効率化
   * - 方向別リスクアセスメント
   * - ユーザー位置周辺の包括的気象状況把握
   */
  async setDirectionalData(lat, lon, directionalData) {
    const cacheKey = HelperFunctions.generateCacheKey(lat, lon);

    try {
      await this.firestore.collection('weather_cache').doc(cacheKey).set({
        data: directionalData,
        timestamp: new Date(),
        location: {
          latitude: lat,
          longitude: lon
        },
        cacheType: 'multi_distance_directional'
      });

      console.log(`✅ 気象データキャッシュ保存完了: ${cacheKey}`);
    } catch (error) {
      console.error(`❌ キャッシュ保存エラー (${cacheKey}):`, error);
    }
  }

  /**
   * 期限切れキャッシュの一括削除処理
   *
   * @param {number} retentionHours - データ保持時間（時間）
   * @param {number} batchSize - 一度に削除する最大件数
   * @returns {number} 削除されたドキュメント数
   *
   * 処理方式:
   * 1. 指定時間より古いドキュメントを検索
   * 2. バッチサイズ分をFirestore batched writeで一括削除
   * 3. 削除件数をログ出力・返却
   *
   * パフォーマンス配慮:
   * - バッチサイズ制限でFirestore負荷制御
   * - インデックスを活用した効率的クエリ
   * - 大量データ削除時のタイムアウト回避
   *
   * 実行タイミング: 毎日午前3時（低負荷時間帯）
   */
  async cleanup(retentionHours = 24, batchSize = 100) {
    const now = new Date();
    const cutoffTime = new Date(now.getTime() - (retentionHours * 60 * 60 * 1000));

    console.log(`📅 ${cutoffTime.toISOString()} より古いキャッシュを削除`);

    try {
      const snapshot = await this.firestore
        .collection('weather_cache')
        .where('timestamp', '<', cutoffTime)
        .limit(batchSize)
        .get();

      if (snapshot.empty) {
        console.log('✅ 削除対象のキャッシュなし');
        return 0;
      }

      const batch = this.firestore.batch();
      let deleteCount = 0;

      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
        deleteCount++;
      });

      await batch.commit();
      console.log(`✅ キャッシュクリーンアップ完了: ${deleteCount}件削除`);

      return deleteCount;
    } catch (error) {
      console.error('❌ キャッシュクリーンアップエラー:', error);
      return 0;
    }
  }

  /**
   * キャッシュ利用統計情報を取得
   *
   * @returns {Object} キャッシュ統計データ
   *
   * 統計項目:
   * - totalCaches: 総キャッシュ数
   * - recentCaches: 1時間以内の新しいキャッシュ数
   * - oldCaches: 2時間以上古いキャッシュ数（削除対象）
   * - retentionHours: 設定された保持時間
   * - cleanupBatchSize: クリーンアップ時のバッチサイズ
   * - timestamp: 統計取得時刻
   *
   * 活用用途:
   * - キャッシュ効率の監視
   * - ストレージ使用量の把握
   * - クリーンアップ設定の最適化
   * - システム健康状態の確認
   */
  async getStats() {
    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - (60 * 60 * 1000));
    const twoHoursAgo = new Date(now.getTime() - (2 * 60 * 60 * 1000));

    try {
      // 全キャッシュ数
      const totalCacheSnapshot = await this.firestore.collection('weather_cache').get();

      // 1時間以内のキャッシュ数
      const recentCacheSnapshot = await this.firestore
        .collection('weather_cache')
        .where('timestamp', '>', oneHourAgo)
        .get();

      // 2時間より古いキャッシュ数（削除対象）
      const oldCacheSnapshot = await this.firestore
        .collection('weather_cache')
        .where('timestamp', '<', twoHoursAgo)
        .get();

      return {
        totalCaches: totalCacheSnapshot.size,
        recentCaches: recentCacheSnapshot.size,
        oldCaches: oldCacheSnapshot.size,
        retentionHours: WEATHER_CONSTANTS.CACHE_CLEANUP_RETENTION_HOURS,
        cleanupBatchSize: WEATHER_CONSTANTS.CACHE_CLEANUP_BATCH_SIZE,
        timestamp: now.toISOString()
      };
    } catch (error) {
      console.error('❌ キャッシュ統計取得エラー:', error);
      throw error;
    }
  }
}

module.exports = WeatherCache;
