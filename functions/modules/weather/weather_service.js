/**
 * 気象データ統合サービスクラス
 *
 * 気象データの取得・キャッシュ・処理を統合管理する中核サービス
 * API呼び出し、キャッシュ戦略、バッチ処理を組み合わせて効率的なデータ提供を実現
 *
 * 主要責務:
 * - 気象データの取得・キャッシュ管理
 * - 方向別・距離別データの処理
 * - アクティブユーザー向けバッチ処理
 * - キャッシュ統計・管理機能
 *
 * 設計パターン:
 * - Service Layer Pattern: ビジネスロジックの集約
 * - Cache-Aside Pattern: キャッシュ戦略
 * - Batch Processing: 大量データの効率処理
 *
 * パフォーマンス最適化:
 * - API呼び出し回数の最小化
 * - 重複座標の除去・統合
 * - 段階的バッチ処理
 * - 夜間モード対応
 */
const WeatherAPI = require('./weather_api');
const WeatherCache = require('./weather_cache');
const BatchProcessor = require('../utils/batch_processor');
const { calculateDirectionCoordinates } = require('../../coordinate_utils');
const { WEATHER_CONSTANTS, HelperFunctions } = require('../../constants');
const ThunderCloudAnalyzer = require('../../thunder_cloud_analyzer');

class WeatherService {
  constructor() {
    this.weatherCache = new WeatherCache();
    this.CHECK_DIRECTIONS = WEATHER_CONSTANTS.CHECK_DIRECTIONS;
    this.CHECK_DISTANCES = WEATHER_CONSTANTS.CHECK_DISTANCES;
  }

  /**
   * キャッシュ機能付き気象データ取得
   */
  async getWeatherDataWithCache(lat, lon) {
    try {
      // キャッシュをチェック
      const cachedData = await this.weatherCache.get(lat, lon);
      if (cachedData) {
        return cachedData;
      }

      // キャッシュが無効または存在しない場合、APIから取得
      console.log(`🌐 APIから新しいデータを取得: ${HelperFunctions.generateCacheKey(lat, lon)}`);

      // バッチ処理で各方向のデータを取得
      const result = await this.getDirectionalWeatherData(lat, lon);

      if (result) {
        // キャッシュに保存
        await this.weatherCache.set(lat, lon, result);
        return result;
      }

      throw new Error('Failed to fetch weather data');

    } catch (error) {
      console.error(`❌ 気象データ取得エラー (${HelperFunctions.generateCacheKey(lat, lon)}):`, error);
      throw error;
    }
  }

  /**
   * 各方向の気象データを取得（バッチ処理版）
   */
  async getDirectionalWeatherData(baseLat, baseLon) {
    console.log('🌐 最適化バッチ処理で気象データ取得開始（全距離対応）');

    // 各方向の全距離の座標を計算
    const coordinates = [];

    this.CHECK_DIRECTIONS.forEach(direction => {
      this.CHECK_DISTANCES.forEach(distance => {
        const coord = calculateDirectionCoordinates(direction, baseLat, baseLon, distance);
        coordinates.push({
          latitude: coord.latitude,
          longitude: coord.longitude,
          direction: direction,
          distance: distance
        });
      });
    });

    try {
      // 最適化されたバッチでAPI呼び出し
      const batchResults = await WeatherAPI.fetchBatchLocations(coordinates);

      if (!batchResults || batchResults.length === 0) {
        console.log('❌ 最適化バッチ処理結果が空です');
        return null;
      }

      // 各方向で最適な距離を選択
      const result = {};

      // 方向別にデータを整理
      const directionData = {};
      this.CHECK_DIRECTIONS.forEach(direction => {
        directionData[direction] = [];
      });

      batchResults.forEach((weatherData, index) => {
        if (weatherData && index < coordinates.length) {
          const coord = coordinates[index];
          const direction = coord.direction;
          const distance = coord.distance;

          const analysis = ThunderCloudAnalyzer.analyzeWithMeteoDataOnly(weatherData);

          directionData[direction].push({
            distance: distance,
            coordinates: {
              lat: coord.latitude,
              lon: coord.longitude
            },
            analysis: {
              isLikely: analysis.isThunderCloudLikely,
              totalScore: analysis.totalScore,
              riskLevel: analysis.riskLevel,
              capeScore: analysis.capeScore || 0,
              liScore: analysis.liScore || 0,
              cinScore: analysis.cinScore || 0,
              tempScore: analysis.tempScore || 0,
              cloudScore: analysis.cloudScore || 0,
            },
            cape: weatherData.cape,
            lifted_index: weatherData.lifted_index,
            convective_inhibition: weatherData.convective_inhibition,
            temperature: weatherData.temperature,
            cloud_cover: weatherData.cloud_cover,
            cloud_cover_mid: weatherData.cloud_cover_mid,
            cloud_cover_high: weatherData.cloud_cover_high,
          });
        }
      });

      // 各方向で最高スコアのデータを選択
      this.CHECK_DIRECTIONS.forEach(direction => {
        const distanceDataList = directionData[direction];

        if (distanceDataList.length > 0) {
          // totalScoreが最高のものを選択
          const bestData = distanceDataList.reduce((best, current) => {
            return current.analysis.totalScore > best.analysis.totalScore ? current : best;
          });

          console.log(`📊 ${direction}方向: ${bestData.distance}km地点を選択（スコア: ${bestData.analysis.totalScore}）`);

          result[direction] = {
            coordinates: bestData.coordinates,
            analysis: bestData.analysis,
            cape: bestData.cape,
            lifted_index: bestData.lifted_index,
            convective_inhibition: bestData.convective_inhibition,
            temperature: bestData.temperature,
            cloud_cover: bestData.cloud_cover,
            cloud_cover_mid: bestData.cloud_cover_mid,
            cloud_cover_high: bestData.cloud_cover_high,
            selectedDistance: bestData.distance
          };
        }
      });

      console.log(`✅ 最適化バッチ処理完了: ${Object.keys(result).length}方向のデータを取得（各方向で最適距離を選択）`);
      return result;

    } catch (error) {
      console.error('❌ 最適化バッチ処理エラー:', error);

      // フォールバック: 個別取得
      console.log('🔄 フォールバックで個別取得開始');
      return await this._getDirectionalWeatherDataFallback(baseLat, baseLon);
    }
  }

  /**
   * フォールバック用の個別取得
   */
  async _getDirectionalWeatherDataFallback(baseLat, baseLon) {
    console.log('🔄 フォールバック処理開始（全距離対応）');

    const result = {};

    // 方向別にデータを整理
    const directionData = {};
    this.CHECK_DIRECTIONS.forEach(direction => {
      directionData[direction] = [];
    });

    for (const direction of this.CHECK_DIRECTIONS) {
      for (const distance of this.CHECK_DISTANCES) {
        try {
          const coordinates = calculateDirectionCoordinates(direction, baseLat, baseLon, distance);
          const weatherData = await WeatherAPI.fetchSingleLocation(coordinates.latitude, coordinates.longitude);

          if (weatherData) {
            const analysis = ThunderCloudAnalyzer.analyzeWithMeteoDataOnly(weatherData);

            directionData[direction].push({
              distance: distance,
              coordinates: {
                lat: coordinates.latitude,
                lon: coordinates.longitude
              },
              analysis: {
                isLikely: analysis.isThunderCloudLikely,
                totalScore: analysis.totalScore,
                riskLevel: analysis.riskLevel,
                capeScore: analysis.capeScore || 0,
                liScore: analysis.liScore || 0,
                cinScore: analysis.cinScore || 0,
                tempScore: analysis.tempScore || 0,
                cloudScore: analysis.cloudScore || 0,
              },
              cape: weatherData.cape,
              lifted_index: weatherData.lifted_index,
              convective_inhibition: weatherData.convective_inhibition,
              temperature: weatherData.temperature,
              cloud_cover: weatherData.cloud_cover,
              cloud_cover_mid: weatherData.cloud_cover_mid,
              cloud_cover_high: weatherData.cloud_cover_high,
            });
          }
        } catch (error) {
          console.error(`❌ フォールバック処理エラー [${direction} ${distance}km]:`, error);
        }
      }
    }

    // 各方向で最高スコアのデータを選択
    this.CHECK_DIRECTIONS.forEach(direction => {
      const distanceDataList = directionData[direction];

      if (distanceDataList.length > 0) {
        // totalScoreが最高のものを選択
        const bestData = distanceDataList.reduce((best, current) => {
          return current.analysis.totalScore > best.analysis.totalScore ? current : best;
        });

        console.log(`📊 フォールバック ${direction}方向: ${bestData.distance}km地点を選択（スコア: ${bestData.analysis.totalScore}）`);

        result[direction] = {
          coordinates: bestData.coordinates,
          analysis: bestData.analysis,
          cape: bestData.cape,
          lifted_index: bestData.lifted_index,
          convective_inhibition: bestData.convective_inhibition,
          temperature: bestData.temperature,
          cloud_cover: bestData.cloud_cover,
          cloud_cover_mid: bestData.cloud_cover_mid,
          cloud_cover_high: bestData.cloud_cover_high,
          selectedDistance: bestData.distance
        };
      }
    });

    console.log(`✅ フォールバック処理完了: ${Object.keys(result).length}方向（各方向で最適距離を選択）`);
    return result;
  }

  /**
   * アクティブユーザー用の気象データキャッシュ
   */
  async cacheWeatherDataForActiveUsers() {
    const admin = require('firebase-admin');
    const firestore = admin.firestore();

    // アクティブユーザーを取得
    const usersSnapshot = await firestore
      .collection('users')
      .where('isActive', '==', true)
      .get();

    console.log(`👥 アクティブユーザー数: ${usersSnapshot.size}`);

    // ユーザーデータを収集
    const users = [];
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      console.log(`📋 ユーザーデータ確認: ドキュメントID=${userDoc.id}`);
      console.log(`📍 位置情報: 緯度=${userData.latitude}, 経度=${userData.longitude}`);
      console.log(`⏰ 最終更新: ${userData.lastUpdated?.toDate?.()}`);
      console.log(`🔄 アクティブ状態: ${userData.isActive}`);

      if (userData.lastUpdated && userData.latitude && userData.longitude) {
        users.push(userData);
        console.log(`✅ ユーザー追加: ${userDoc.id} (緯度=${userData.latitude}, 経度=${userData.longitude})`);
      } else {
        console.log(`⚠️ ユーザーをスキップ: ${userDoc.id} (位置情報または更新時刻が不完全)`);
      }
    }

    // lastUpdatedで降順ソート
    users.sort((a, b) => {
      const aTime = a.lastUpdated?.toDate?.() || new Date(0);
      const bTime = b.lastUpdated?.toDate?.() || new Date(0);
      return bTime.getTime() - aTime.getTime();
    });

    console.log(`📊 処理対象ユーザー数: ${users.length}`);

    if (users.length === 0) {
      console.log('⚠️ 処理対象のユーザーがいません。usersコレクションの内容を確認してください。');

      // 全usersコレクションの内容を確認
      const allUsersSnapshot = await firestore.collection('users').get();
      console.log(`📊 全ユーザー数: ${allUsersSnapshot.size}`);

      allUsersSnapshot.docs.forEach((doc) => {
        const data = doc.data();
        console.log(`📄 ドキュメント: ${doc.id}`);
        console.log(`   - isActive: ${data.isActive}`);
        console.log(`   - latitude: ${data.latitude}`);
        console.log(`   - longitude: ${data.longitude}`);
        console.log(`   - lastUpdated: ${data.lastUpdated?.toDate?.()}`);
      });

      return;
    }

    console.log(`📊 キャッシュ対象ユーザー数: ${users.length}`);

    // 取得間隔内の地点はAPIを呼ばず、キャッシュの鮮度だけ更新する
    const usersToFetch = [];
    const checkedLocations = new Set();

    for (const user of users) {
      const locationKey = HelperFunctions.generateCacheKey(user.latitude, user.longitude);
      if (checkedLocations.has(locationKey)) {
        continue;
      }
      checkedLocations.add(locationKey);

      if (!(await this.weatherCache.refreshIfRecentlyFetched(user.latitude, user.longitude))) {
        usersToFetch.push(user);
      }
    }

    console.log(`📍 再取得対象: ${usersToFetch.length}/${checkedLocations.size}地点`);

    if (usersToFetch.length === 0) {
      return;
    }

    // 全ユーザーの全座標を収集（重複除去付き）
    const { uniqueCoordinates } = BatchProcessor.collectUniqueCoordinates(usersToFetch);

    const totalPoints = usersToFetch.length * this.CHECK_DIRECTIONS.length * this.CHECK_DISTANCES.length;
    console.log(`📍 座標最適化: 全${totalPoints}地点 → ${uniqueCoordinates.length}地点（重複除去）`);

    // 段階的バッチ処理でキャッシュ用データを取得
    const allBatchResults = await BatchProcessor.processBatchWithStages(uniqueCoordinates, 100);

    // 結果をユーザー別・方向別・距離別に整理してキャッシュ保存
    await this._cacheWeatherDataByUsers(usersToFetch, uniqueCoordinates, allBatchResults);
  }

  /**
   * ユーザー別に気象データをキャッシュ保存
   */
  async _cacheWeatherDataByUsers(users, uniqueCoordinates, allBatchResults) {
    console.log('💾 ユーザー別気象データキャッシュ保存開始');

    // 座標とデータのマッピングを作成
    const coordinateDataMap = new Map();

    uniqueCoordinates.forEach((coord, index) => {
      if (index < allBatchResults.length && allBatchResults[index]) {
        const coordKey = HelperFunctions.generateCacheKey(coord.latitude, coord.longitude);
        coordinateDataMap.set(coordKey, allBatchResults[index]);
      }
    });

    // ユーザーごとの位置データをキャッシュ
    const locationSet = new Set();

    for (const user of users) {
      const locationKey = HelperFunctions.generateCacheKey(user.latitude, user.longitude);

      if (!locationSet.has(locationKey)) {
        locationSet.add(locationKey);

        try {
          // この位置の各方向・各距離のデータを整理
          const directionalData = {};

          for (const direction of this.CHECK_DIRECTIONS) {
            directionalData[direction] = {};

            for (const distance of this.CHECK_DISTANCES) {
              const coordinates = calculateDirectionCoordinates(
                direction, user.latitude, user.longitude, distance
              );

              const coordKey = HelperFunctions.generateCacheKey(coordinates.latitude, coordinates.longitude);
              const weatherData = coordinateDataMap.get(coordKey);

              if (weatherData) {
                const analysis = ThunderCloudAnalyzer.analyzeWithMeteoDataOnly(weatherData);

                directionalData[direction][`${distance}km`] = {
                  coordinates: {
                    lat: coordinates.latitude,
                    lon: coordinates.longitude
                  },
                  analysis: {
                    isLikely: analysis.isThunderCloudLikely,
                    totalScore: analysis.totalScore,
                    riskLevel: analysis.riskLevel,
                    capeScore: analysis.capeScore,
                    liScore: analysis.liScore,
                    cinScore: analysis.cinScore,
                    tempScore: analysis.tempScore,
                    cloudScore: analysis.cloudScore || 0,
                  },
                  cape: weatherData.cape,
                  lifted_index: weatherData.lifted_index,
                  convective_inhibition: weatherData.convective_inhibition,
                  temperature: weatherData.temperature,
                  cloud_cover: weatherData.cloud_cover,
                  cloud_cover_mid: weatherData.cloud_cover_mid,
                  cloud_cover_high: weatherData.cloud_cover_high,
                };
              }
            }
          }

          // 1地点も取得できなかった場合は既存キャッシュを空データで上書きしない
          const hasAnyData = Object.values(directionalData)
            .some(directionData => Object.keys(directionData).length > 0);

          if (!hasAnyData) {
            console.warn(`⚠️ 気象データ未取得のためキャッシュ保存をスキップ: ${locationKey}`);
            continue;
          }

          // Firestoreにキャッシュ保存
          await this.weatherCache.setDirectionalData(user.latitude, user.longitude, directionalData);

        } catch (error) {
          console.error(`❌ キャッシュ保存エラー (${locationKey}):`, error);
        }
      }
    }

    console.log('💾 ユーザー別気象データキャッシュ保存完了');
  }

  /**
   * キャッシュ統計情報を取得
   */
  async getCacheStats() {
    return await this.weatherCache.getStats();
  }
}

module.exports = WeatherService;
