// functions/modules/utils/batch_processor.js
const WeatherAPI = require('../weather/weather_api');
const { calculateDirectionCoordinates } = require('../../coordinate_utils');
const { WEATHER_CONSTANTS, HelperFunctions } = require('../../constants');

class BatchProcessor {
  /**
   * 配列を指定サイズで分割
   */
  static chunkArray(array, size) {
    const chunks = [];
    for (let i = 0; i < array.length; i += size) {
      chunks.push(array.slice(i, i + size));
    }
    return chunks;
  }

  /**
   * ユーザーから重複のない座標リストを生成
   */
  static collectUniqueCoordinates(activeUsers) {
    const coordinateMap = new Map();
    const coordinateUserMap = new Map();

    activeUsers.forEach((user, userIndex) => {
      WEATHER_CONSTANTS.CHECK_DIRECTIONS.forEach(direction => {
        WEATHER_CONSTANTS.CHECK_DISTANCES.forEach(distance => {
          const coord = calculateDirectionCoordinates(direction, user.latitude, user.longitude, distance);
          const coordKey = HelperFunctions.generateCacheKey(coord.latitude, coord.longitude);

          // 重複座標を除去
          if (!coordinateMap.has(coordKey)) {
            coordinateMap.set(coordKey, {
              latitude: coord.latitude,
              longitude: coord.longitude
            });
          }

          // 座標とユーザーの関連付け
          if (!coordinateUserMap.has(coordKey)) {
            coordinateUserMap.set(coordKey, []);
          }
          coordinateUserMap.get(coordKey).push({
            userIndex: userIndex,
            direction: direction,
            distance: distance
          });
        });
      });
    });

    const uniqueCoordinates = Array.from(coordinateMap.values());
    return { uniqueCoordinates, coordinateUserMap };
  }

  /**
   * 段階的バッチ処理で気象データを取得
   */
  static async processBatchWithStages(coordinates, batchSize = 100) {
    const batches = this.chunkArray(coordinates, batchSize);
    const allResults = [];

    console.log(`🔄 段階的バッチ処理: ${coordinates.length}地点を${batches.length}回に分けて処理（${batchSize}地点ずつ）`);

    for (let i = 0; i < batches.length; i++) {
      const batch = batches[i];
      console.log(`🌐 バッチ ${i + 1}/${batches.length}: ${batch.length}地点を処理中...`);

      try {
        const batchResults = await WeatherAPI.fetchBatchLocations(batch);
        allResults.push(...batchResults);

        console.log(`✅ バッチ ${i + 1}/${batches.length} 完了: ${batchResults.length}地点のデータを取得`);

        // バッチ間で待機（API負荷軽減）
        if (i < batches.length - 1) {
          console.log('⏳ バッチ間待機: 2秒...');
          await new Promise(resolve => setTimeout(resolve, 2000));
        }

      } catch (batchError) {
        console.error(`❌ バッチ ${i + 1}/${batches.length} 処理エラー:`, batchError);

        // 失敗したバッチは個別処理にフォールバック
        console.log(`🔄 バッチ ${i + 1} を個別処理でフォールバック`);
        const fallbackResults = await this._processBatchFallback(batch);
        allResults.push(...fallbackResults);
      }
    }

    console.log(`✅ 全段階的バッチ処理完了: ${allResults.length}地点のデータを取得`);
    return allResults;
  }

  /**
   * バッチ失敗時のフォールバック処理
   */
  static async _processBatchFallback(coordinates) {
    console.log(`🔄 個別バッチフォールバック: ${coordinates.length}地点を個別処理`);

    const results = [];

    for (const coord of coordinates) {
      try {
        const weatherData = await WeatherAPI.fetchSingleLocation(coord.latitude, coord.longitude);
        results.push(weatherData || this._getDefaultWeatherData());

        // 個別処理間で少し待機
        await new Promise(resolve => setTimeout(resolve, 100));

      } catch (error) {
        console.error(`❌ 個別処理エラー (${coord.latitude}, ${coord.longitude}):`, error);
        // エラーの場合はデフォルト値を追加
        results.push(this._getDefaultWeatherData());
      }
    }

    console.log(`✅ 個別バッチフォールバック完了: ${results.length}地点`);
    return results;
  }

  /**
   * デフォルト気象データ
   */
  static _getDefaultWeatherData() {
    return {
      cape: 0,
      lifted_index: 0,
      convective_inhibition: 0,
      temperature: 20,
      cloud_cover: 0,
      cloud_cover_mid: 0,
      cloud_cover_high: 0
    };
  }
}

module.exports = BatchProcessor;
