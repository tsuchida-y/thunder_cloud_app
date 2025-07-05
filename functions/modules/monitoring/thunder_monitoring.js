// functions/modules/monitoring/thunder_monitoring.js
const admin = require('firebase-admin');
const NotificationService = require('../notification/notification_service');
const { calculateDirectionCoordinates } = require('../../coordinate_utils');
const { WEATHER_CONSTANTS, HelperFunctions } = require('../../constants');
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
        users.push(userData);
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
   * 入道雲監視（5分間隔）
   */
  async monitorThunderClouds() {
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
        users.push(userData);
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
    const thunderCloudDirections = [];
    const now = new Date();

    for (const direction of this.CHECK_DIRECTIONS) {
      let thunderCloudExists = false;

      for (const distance of this.CHECK_DISTANCES) {
        // キャッシュから気象データを取得
        const coordinates = calculateDirectionCoordinates(
          direction, user.latitude, user.longitude, distance
        );

        const cacheKey = HelperFunctions.generateCacheKey(coordinates.latitude, coordinates.longitude);

        try {
          const cacheDoc = await this.firestore.collection('weather_cache').doc(cacheKey).get();

          if (cacheDoc.exists) {
            const cachedData = cacheDoc.data();
            const cacheTime = cachedData.timestamp.toDate();

            // キャッシュが5分以内の場合は使用
            if (now.getTime() - cacheTime.getTime() < 5 * 60 * 1000) {
              const weatherData = cachedData.data;

              if (weatherData) {
                const result = ThunderCloudAnalyzer.analyzeWithMeteoDataOnly(weatherData);
                if (result.isThunderCloudLikely) {
                  thunderCloudExists = true;
                  break;
                }
              }
            }
          }

          // キャッシュがない場合は個別API呼び出し（フォールバック）
          if (!thunderCloudExists) {
            const isThunderCloud = await this._checkThunderCloudCondition(
              coordinates.latitude, coordinates.longitude
            );
            if (isThunderCloud) {
              thunderCloudExists = true;
              break;
            }
          }
        } catch (error) {
          console.error(`❌ キャッシュチェックエラー (${cacheKey}):`, error);

          // エラー時は個別API呼び出し（フォールバック）
          const isThunderCloud = await this._checkThunderCloudCondition(
            coordinates.latitude, coordinates.longitude
          );
          if (isThunderCloud) {
            thunderCloudExists = true;
            break;
          }
        }
      }

      if (thunderCloudExists) {
        thunderCloudDirections.push(direction);
      }
    }

    if (thunderCloudDirections.length > 0) {
      await this.notificationService.sendThunderCloudAlert(user.fcmToken, thunderCloudDirections);
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
