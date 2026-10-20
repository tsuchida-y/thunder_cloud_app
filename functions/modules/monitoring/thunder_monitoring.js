// functions/modules/monitoring/thunder_monitoring.js
const admin = require('firebase-admin');
const NotificationService = require('../notification/notification_service');
const { calculateDirectionCoordinates } = require('../../coordinate_utils');
const { WEATHER_CONSTANTS, USER_MONITORING, HelperFunctions } = require('../../constants');
const ThunderCloudAnalyzer = require('../../thunder_cloud_analyzer');
const WeatherAPI = require('../weather/weather_api');

class ThunderMonitoring {
  constructor() {
    this.firestore = admin.firestore();
    this.notificationService = new NotificationService();
    this.CHECK_DIRECTIONS = WEATHER_CONSTANTS.CHECK_DIRECTIONS;
    this.CHECK_DISTANCES = WEATHER_CONSTANTS.CHECK_DISTANCES;
  }

  /**
   * 入道雲チェック（キャッシュデータ活用版）
   */
  async checkThunderClouds() {
    // アクティブユーザーを取得
    const usersSnapshot = await this.firestore
      .collection('users')
      .where('isActive', '==', true)
      .get();

    console.log(`👥 アクティブユーザー数: ${usersSnapshot.size}`);

    // ユーザーデータを収集
    const users = [];
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      if (userData.lastUpdated) {
        // 通知の重複防止でユーザードキュメントを更新するため参照も保持
        users.push({ ...userData, ref: userDoc.ref });
      }
    }

    // lastUpdatedで降順ソート
    users.sort((a, b) => {
      const aTime = a.lastUpdated?.toDate?.() || new Date(0);
      const bTime = b.lastUpdated?.toDate?.() || new Date(0);
      return bTime.getTime() - aTime.getTime();
    });

    console.log(`📊 処理対象ユーザー数: ${users.length}`);

    // キャッシュされた気象データを活用して入道雲チェック
    await this._checkThunderCloudsWithCache(users);
  }

  /**
   * 入道雲監視（5分間隔・冗長バックアップ）
   * メイン処理と同一ロジック。重複通知は _claimNotificationSlot で抑止する
   */
  async monitorThunderClouds() {
    await this.checkThunderClouds();
  }

  /**
   * キャッシュされた気象データを活用した入道雲チェック
   */
  async _checkThunderCloudsWithCache(users) {
    const activeUsers = [];
    const now = new Date();

    // アクティブユーザーをフィルタリング
    for (const user of users) {
      const lastUpdated = user.lastUpdated?.toDate?.() || new Date(0);

      // 24時間以内に位置更新があったユーザーのみ監視
      if (lastUpdated && (now.getTime() - lastUpdated.getTime()) < 24 * 60 * 60 * 1000) {
        activeUsers.push(user);
      }
    }

    if (activeUsers.length === 0) {
      console.log('👥 処理対象のアクティブユーザーがいません');
      return;
    }

    console.log(`📊 入道雲チェック対象ユーザー数: ${activeUsers.length}`);

    // 各ユーザーの入道雲状況をチェック
    for (const user of activeUsers) {
      try {
        await this._checkUserThunderCloudWithCache(user);
      } catch (userError) {
        console.error(`❌ ユーザー処理エラー: ${user.fcmToken?.substring(0, 10)}...`, userError);
      }
    }
  }

  /**
   * キャッシュを活用した個別ユーザーの入道雲チェック
   */
  async _checkUserThunderCloudWithCache(user) {
    if (typeof user.latitude !== 'number' || typeof user.longitude !== 'number') {
      return;
    }

    // キャッシュはユーザー位置をキーに「方向 → 距離」の構造で保存されている
    const cachedDirectionalData = await this._getCachedDirectionalData(user);
    const thunderCloudDirections = [];

    for (const direction of this.CHECK_DIRECTIONS) {
      let thunderCloudExists = this._isThunderCloudLikelyInCache(
        cachedDirectionalData && cachedDirectionalData[direction]
      );

      // キャッシュで判定できない場合のみ個別API呼び出し（フォールバック）
      if (thunderCloudExists === null) {
        thunderCloudExists = false;

        for (const distance of this.CHECK_DISTANCES) {
          const coordinates = calculateDirectionCoordinates(
            direction, user.latitude, user.longitude, distance
          );

          if (await this._checkThunderCloudCondition(coordinates.latitude, coordinates.longitude)) {
            thunderCloudExists = true;
            break;
          }
        }
      }

      if (thunderCloudExists) {
        thunderCloudDirections.push(direction);
      }
    }

    if (thunderCloudDirections.length > 0 && await this._claimNotificationSlot(user)) {
      await this.notificationService.sendThunderCloudAlert(user.fcmToken, thunderCloudDirections);
    }
  }

  /**
   * ユーザー位置の方向別キャッシュを取得（期限切れ・形式違いの場合はnull）
   */
  async _getCachedDirectionalData(user) {
    const cacheKey = HelperFunctions.generateCacheKey(user.latitude, user.longitude);

    try {
      const cacheDoc = await this.firestore.collection('weather_cache').doc(cacheKey).get();
      if (!cacheDoc.exists) {
        return null;
      }

      const cachedData = cacheDoc.data();
      const cacheTime = cachedData.timestamp && cachedData.timestamp.toDate && cachedData.timestamp.toDate();
      const isFresh = cacheTime &&
        (Date.now() - cacheTime.getTime()) < USER_MONITORING.CACHE_CHECK_DURATION_MS;

      if (!isFresh || cachedData.cacheType !== 'multi_distance_directional' || !cachedData.data) {
        return null;
      }

      return cachedData.data;
    } catch (error) {
      console.error(`❌ キャッシュチェックエラー (${cacheKey}):`, error);
      return null;
    }
  }

  /**
   * 方向別キャッシュから入道雲の有無を判定
   *
   * @returns {boolean|null} 判定結果（全距離のデータが揃っておらず判定できない場合はnull）
   */
  _isThunderCloudLikelyInCache(directionData) {
    if (!directionData) {
      return null;
    }

    let hasAllDistances = true;

    for (const distance of this.CHECK_DISTANCES) {
      const distanceData = directionData[`${distance}km`];

      if (!distanceData || !distanceData.analysis) {
        hasAllDistances = false;
      } else if (distanceData.analysis.isLikely === true) {
        return true;
      }
    }

    return hasAllDistances ? false : null;
  }

  /**
   * 通知送信権を確保（メイン処理と冗長処理による同一周期の重複通知を防止）
   *
   * @returns {boolean} 通知を送信してよい場合はtrue
   */
  async _claimNotificationSlot(user) {
    if (!user.ref) {
      return true;
    }

    try {
      return await this.firestore.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(user.ref);
        if (!userDoc.exists) {
          return false;
        }

        const lastNotifiedAt = userDoc.get('lastThunderNotificationAt');
        const lastNotifiedMs = lastNotifiedAt && lastNotifiedAt.toMillis ? lastNotifiedAt.toMillis() : 0;

        if (Date.now() - lastNotifiedMs < USER_MONITORING.NOTIFICATION_DEDUP_WINDOW_MS) {
          console.log('🔁 直近に通知済みのため重複通知をスキップ');
          return false;
        }

        transaction.update(user.ref, {
          lastThunderNotificationAt: admin.firestore.FieldValue.serverTimestamp()
        });
        return true;
      });
    } catch (error) {
      // 重複防止に失敗しても警報自体は届ける
      console.error('❌ 通知重複チェックエラー:', error);
      return true;
    }
  }

  /**
   * 個別の入道雲状態チェック（フォールバック用）
   */
  async _checkThunderCloudCondition(lat, lon) {
    try {
      const weatherData = await WeatherAPI.fetchSingleLocation(lat, lon);
      if (!weatherData) {
        return false;
      }

      const result = ThunderCloudAnalyzer.analyzeWithMeteoDataOnly(weatherData);
      return result.isThunderCloudLikely;
    } catch (error) {
      console.error('❌ 気象データ取得エラー:', error);
      return false;
    }
  }
}

module.exports = ThunderMonitoring;
