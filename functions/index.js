const {onRequest} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const axios = require("axios");

// 定数ファイルをインポート
const {
  WEATHER_CONSTANTS,
  ANALYSIS_THRESHOLDS,
  SCORE_WEIGHTS,
  SCORE_VALUES,
  TIMEOUT_SETTINGS,
  BATCH_SETTINGS,
  USER_MONITORING,
  HTTP_STATUS,
  MEMORY_SETTINGS,
  REGIONS,
  LOG_CONSTANTS,
  API_SETTINGS,
  HelperFunctions
} = require('./constants');

// Firebase初期化
admin.initializeApp();
const firestore = admin.firestore();
const messaging = admin.messaging();

// 座標計算ユーティリティ
const { calculateDirectionCoordinates } = require('./coordinate_utils');

// 入道雲分析器
const ThunderCloudAnalyzer = require('./thunder_cloud_analyzer');

// 監視設定（定数ファイルから参照）
const CHECK_DIRECTIONS = WEATHER_CONSTANTS.CHECK_DIRECTIONS;
const CHECK_DISTANCES = WEATHER_CONSTANTS.CHECK_DISTANCES;

// 気象データキャッシュの有効期限
const WEATHER_CACHE_DURATION = WEATHER_CONSTANTS.CACHE_DURATION_MS;

// キャッシュクリーンアップの設定
const CACHE_CLEANUP_RETENTION_HOURS = WEATHER_CONSTANTS.CACHE_CLEANUP_RETENTION_HOURS;
const CACHE_CLEANUP_BATCH_SIZE = WEATHER_CONSTANTS.CACHE_CLEANUP_BATCH_SIZE;

// 夜間モード設定
const NIGHT_MODE_START_HOUR = WEATHER_CONSTANTS.NIGHT_MODE_START_HOUR;
const NIGHT_MODE_END_HOUR = WEATHER_CONSTANTS.NIGHT_MODE_END_HOUR;

// 気象データ取得用HTTPS関数
exports.getWeatherData = onRequest(async (req, res) => {
  // CORS設定
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  try {
    const { latitude, longitude } = req.query;

    if (!latitude || !longitude) {
      res.status(400).json({ error: 'latitude and longitude are required' });
      return;
    }

    const lat = parseFloat(latitude);
    const lon = parseFloat(longitude);

    console.log(`🌦️ 気象データ取得要求: ${lat}, ${lon}`);

    // 夜間モードチェック
    if (isNightMode()) {
      console.log("🌙 夜間モード: 入道雲なしの状態を返却");
      const nightModeData = createNightModeResponse();
      res.status(200).json({
        success: true,
        data: nightModeData,
        timestamp: new Date().toISOString(),
        nightMode: true
      });
      return;
    }

    const weatherData = await getWeatherDataWithCache(lat, lon);

    res.status(200).json({
      success: true,
      data: weatherData,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error("❌ 気象データ取得エラー:", error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

// 各方向の気象データ取得用HTTPS関数
exports.getDirectionalWeatherData = onRequest(async (req, res) => {
  // CORS設定
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  try {
    const { latitude, longitude, directions } = req.query;

    if (!latitude || !longitude) {
      res.status(400).json({ error: 'latitude and longitude are required' });
      return;
    }

    const lat = parseFloat(latitude);
    const lon = parseFloat(longitude);

    console.log(`🌦️ 各方向気象データ取得要求: ${lat}, ${lon}`);

    // 夜間モードチェック
    if (isNightMode()) {
      console.log("🌙 夜間モード: 入道雲なしの状態を返却");
      const nightModeData = createNightModeResponse();
      res.status(200).json({
        success: true,
        data: nightModeData,
        timestamp: new Date().toISOString(),
        nightMode: true
      });
      return;
    }

    // 各方向の気象データを取得
    const weatherData = await getDirectionalWeatherDataBatch(lat, lon);

    if (weatherData) {
      res.status(200).json({
        success: true,
        data: weatherData,
        timestamp: new Date().toISOString()
      });
    } else {
      res.status(500).json({
        error: 'Failed to fetch weather data',
        message: 'No weather data available'
      });
    }

  } catch (error) {
    console.error("❌ 各方向気象データ取得エラー:", error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

// 夜間モードかどうかをチェック（日本時間基準）
function isNightMode() {
  return HelperFunctions.isNightMode();
}

// 夜間モード用のレスポンスを作成
function createNightModeResponse() {
  return HelperFunctions.createNightModeResponse();
}

// キャッシュ機能付き気象データ取得
async function getWeatherDataWithCache(lat, lon) {
  const cacheKey = HelperFunctions.generateCacheKey(lat, lon);
  const now = new Date();

  try {
    // キャッシュをチェック
    const cacheDoc = await firestore.collection('weather_cache').doc(cacheKey).get();

    if (cacheDoc.exists) {
      const cachedData = cacheDoc.data();
      const cacheTime = cachedData.timestamp.toDate();

      // キャッシュが有効期限内の場合
      if (now.getTime() - cacheTime.getTime() < WEATHER_CACHE_DURATION) {
        console.log(`✅ キャッシュからデータを取得: ${cacheKey}`);
        return cachedData.data;
      }
    }

    // キャッシュが無効または存在しない場合、APIから取得
    console.log(`🌐 APIから新しいデータを取得: ${cacheKey}`);

    // バッチ処理で各方向のデータを取得
    const result = await getDirectionalWeatherDataBatch(lat, lon);

    if (result) {
      // キャッシュに保存
      await firestore.collection('weather_cache').doc(cacheKey).set({
        data: result,
        timestamp: now,
        location: { lat, lon }
      });

      return result;
    }

    throw new Error('Failed to fetch weather data');

  } catch (error) {
    console.error(`❌ 気象データ取得エラー (${cacheKey}):`, error);
    throw error;
  }
}

// バッチ処理で各方向の気象データを取得（最適化版）
async function getDirectionalWeatherDataBatch(baseLat, baseLon) {
  console.log("🌐 最適化バッチ処理で気象データ取得開始（全距離対応）");

  // 各方向の全距離の座標を計算
  const coordinates = [];

  CHECK_DIRECTIONS.forEach(direction => {
    CHECK_DISTANCES.forEach(distance => {
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
    const batchResults = await fetchBatchWeatherDataOptimized(coordinates);

    if (!batchResults || batchResults.length === 0) {
      console.log("❌ 最適化バッチ処理結果が空です");
      return null;
    }

    // 各方向で最適な距離を選択
    const result = {};

    // 方向別にデータを整理
    const directionData = {};
    CHECK_DIRECTIONS.forEach(direction => {
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
    CHECK_DIRECTIONS.forEach(direction => {
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
    console.error("❌ 最適化バッチ処理エラー:", error);

    // フォールバック: 個別取得
    console.log("🔄 フォールバックで個別取得開始");
    return await getDirectionalWeatherDataFallback(baseLat, baseLon);
  }
}

// フォールバック用の個別取得
async function getDirectionalWeatherDataFallback(baseLat, baseLon) {
  console.log("🔄 フォールバック処理開始（全距離対応）");

  const result = {};

  // 方向別にデータを整理
  const directionData = {};
  CHECK_DIRECTIONS.forEach(direction => {
    directionData[direction] = [];
  });

  for (const direction of CHECK_DIRECTIONS) {
    for (const distance of CHECK_DISTANCES) {
      try {
        const coordinates = calculateDirectionCoordinates(direction, baseLat, baseLon, distance);
        const weatherData = await fetchWeatherDataFromAPI(coordinates.latitude, coordinates.longitude);

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
  CHECK_DIRECTIONS.forEach(direction => {
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

// Open-Meteo APIから気象データを取得（単一地点用）
async function fetchWeatherDataFromAPI(lat, lon) {
  try {
    const response = await axios.get(
      `https://api.open-meteo.com/v1/forecast?` +
      `latitude=${lat.toFixed(6)}&longitude=${lon.toFixed(6)}&` +
      `hourly=cape,lifted_index,convective_inhibition,cloud_cover,cloud_cover_mid,cloud_cover_high&` +
      `current=temperature_2m&timezone=auto&forecast_days=1`
    );

    return {
      cape: response.data.hourly.cape[0] || 0,
      lifted_index: response.data.hourly.lifted_index[0] || 0,
      convective_inhibition: response.data.hourly.convective_inhibition[0] || 0,
      temperature: response.data.current.temperature_2m || 20,
      cloud_cover: response.data.hourly.cloud_cover[0] || 0,
      cloud_cover_mid: response.data.hourly.cloud_cover_mid[0] || 0,
      cloud_cover_high: response.data.hourly.cloud_cover_high[0] || 0
    };
  } catch (error) {
    console.error("❌ Open-Meteo API エラー:", error);
    return null;
  }
}

// 5分間隔で気象データを自動キャッシュ（複数距離対応・効率化版）
exports.cacheWeatherData = onSchedule({
  schedule: "every 5 minutes",
  timeoutSeconds: 540,    // 9分タイムアウト
  memory: "1GiB",         // メモリ増量
  region: "asia-northeast1"
}, async (event) => {
  console.log("🌦️ 気象データ自動キャッシュ開始（複数距離対応）");

  // 夜間モードチェック
  if (isNightMode()) {
    console.log("🌙 夜間モード: 気象データキャッシュをスキップ");
    return;
  }

  try {
    // アクティブユーザーを取得
    const usersSnapshot = await firestore
      .collection("users")
      .where("isActive", "==", true)
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
      console.log("⚠️ 処理対象のユーザーがいません。usersコレクションの内容を確認してください。");

      // 全usersコレクションの内容を確認
      const allUsersSnapshot = await firestore.collection("users").get();
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

    // 全ユーザーの全座標を収集（重複除去付き）
    const { uniqueCoordinates, coordinateUserMap } = collectUniqueCoordinates(users);

    console.log(`📍 座標最適化: 全${users.length * CHECK_DIRECTIONS.length * CHECK_DISTANCES.length}地点 → ${uniqueCoordinates.length}地点（重複除去）`);

    // 段階的バッチ処理でキャッシュ用データを取得
    const BATCH_SIZE = 100;
    const batches = chunkArray(uniqueCoordinates, BATCH_SIZE);

    console.log(`🔄 段階的バッチ処理: ${uniqueCoordinates.length}地点を${batches.length}回に分けて処理（${BATCH_SIZE}地点ずつ）`);

    const allBatchResults = [];

    for (let i = 0; i < batches.length; i++) {
      const batch = batches[i];
      console.log(`🌐 バッチ ${i + 1}/${batches.length}: ${batch.length}地点を処理中...`);

      try {
        const batchResults = await fetchBatchWeatherDataOptimized(batch);
        allBatchResults.push(...batchResults);

        console.log(`✅ バッチ ${i + 1}/${batches.length} 完了: ${batchResults.length}地点のデータを取得`);

        // バッチ間で待機（API負荷軽減）
        if (i < batches.length - 1) {
          console.log(`⏳ バッチ間待機: 2秒...`);
          await new Promise(resolve => setTimeout(resolve, 2000));
        }

      } catch (batchError) {
        console.error(`❌ バッチ ${i + 1}/${batches.length} 処理エラー:`, batchError);

        // 失敗したバッチは個別処理にフォールバック
        console.log(`🔄 バッチ ${i + 1} を個別処理でフォールバック`);
        const fallbackResults = await processBatchFallback(batch);
        allBatchResults.push(...fallbackResults);
      }
    }

    console.log(`✅ 全段階的バッチ処理完了: ${allBatchResults.length}地点のデータを取得`);

    // 結果をユーザー別・方向別・距離別に整理してキャッシュ保存
    await cacheWeatherDataByUsers(users, uniqueCoordinates, allBatchResults);

    console.log("✅ 気象データ自動キャッシュ完了");
  } catch (error) {
    console.error("❌ 気象データ自動キャッシュエラー:", error);
  }
});

// 5分間隔で入道雲チェック（キャッシュデータ活用版）
exports.checkThunderClouds = onSchedule({
  schedule: "every 5 minutes",
  timeoutSeconds: 300,    // 5分タイムアウト（キャッシュ活用で高速化）
  memory: "512MiB",
  region: "asia-northeast1"
}, async (event) => {
  console.log("🌩️ 入道雲チェック開始（キャッシュ活用版）");

  // 夜間モードチェック（20時〜8時）
  if (isNightMode()) {
    console.log("🌙 夜間モード（20時〜8時）: 入道雲チェックを完全にスキップ");
    return;
  }

  try {
    // アクティブユーザーを取得
    const usersSnapshot = await firestore
      .collection("users")
      .where("isActive", "==", true)
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
    await checkThunderCloudsWithCache(users);

    console.log("✅ 入道雲チェック完了");
  } catch (error) {
    console.error("❌ エラー:", error);
  }
});

// キャッシュされた気象データを活用した入道雲チェック
async function checkThunderCloudsWithCache(users) {
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
    console.log("👥 処理対象のアクティブユーザーがいません");
    return;
  }

  console.log(`📊 入道雲チェック対象ユーザー数: ${activeUsers.length}`);

  // 各ユーザーの入道雲状況をチェック
  for (const user of activeUsers) {
    try {
      await checkUserThunderCloudWithCache(user);
    } catch (userError) {
      console.error(`❌ ユーザー処理エラー: ${user.fcmToken?.substring(0, 10)}...`, userError);
    }
  }
}

// キャッシュを活用した個別ユーザーの入道雲チェック
async function checkUserThunderCloudWithCache(user) {
  const thunderCloudDirections = [];
  const now = new Date();

  for (const direction of CHECK_DIRECTIONS) {
    let thunderCloudExists = false;

    for (const distance of CHECK_DISTANCES) {
      // キャッシュから気象データを取得
      const coordinates = calculateDirectionCoordinates(
        direction, user.latitude, user.longitude, distance
      );

      const cacheKey = HelperFunctions.generateCacheKey(coordinates.latitude, coordinates.longitude);

      try {
        const cacheDoc = await firestore.collection('weather_cache').doc(cacheKey).get();

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
          const isThunderCloud = await checkThunderCloudCondition(
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
        const isThunderCloud = await checkThunderCloudCondition(
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
    await sendNotification(user.fcmToken, thunderCloudDirections);
  }
}

// ユーザー別に気象データをキャッシュ保存
async function cacheWeatherDataByUsers(users, uniqueCoordinates, allBatchResults) {
  console.log("💾 ユーザー別気象データキャッシュ保存開始");

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

        for (const direction of CHECK_DIRECTIONS) {
          directionalData[direction] = {};

          for (const distance of CHECK_DISTANCES) {
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

        // Firestoreにキャッシュ保存
        const cacheKey = HelperFunctions.generateCacheKey(user.latitude, user.longitude);
        await firestore.collection('weather_cache').doc(cacheKey).set({
          data: directionalData,
          timestamp: new Date(),
          location: {
            latitude: user.latitude,
            longitude: user.longitude
          },
          cacheType: 'multi_distance_directional'
        });

        console.log(`✅ 気象データキャッシュ保存完了: ${cacheKey}`);

      } catch (error) {
        console.error(`❌ キャッシュ保存エラー (${locationKey}):`, error);
      }
    }
  }

  console.log("💾 ユーザー別気象データキャッシュ保存完了");
}

// 定期的なキャッシュクリーンアップ（毎日午前3時に実行）
exports.cleanupWeatherCache = onSchedule("0 3 * * *", async (event) => {
  console.log("🧹 気象データキャッシュクリーンアップ開始");

  try {
    const now = new Date();
    const cutoffTime = new Date(now.getTime() - (CACHE_CLEANUP_RETENTION_HOURS * 60 * 60 * 1000));

    console.log(`📅 ${cutoffTime.toISOString()} より古いキャッシュを削除`);

    const snapshot = await firestore
      .collection('weather_cache')
      .where('timestamp', '<', cutoffTime)
      .limit(CACHE_CLEANUP_BATCH_SIZE)
      .get();

    if (snapshot.empty) {
      console.log("✅ 削除対象のキャッシュなし");
      return;
    }

    const batch = firestore.batch();
    let deleteCount = 0;

    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
      deleteCount++;
    });

    await batch.commit();
    console.log(`✅ キャッシュクリーンアップ完了: ${deleteCount}件削除`);

  } catch (error) {
    console.error("❌ キャッシュクリーンアップエラー:", error);
  }
});

// 期限切れ写真の自動削除（毎日午前1時に実行）
exports.cleanupExpiredPhotos = onSchedule("0 1 * * *", async (event) => {
  console.log("🧹 期限切れ写真クリーンアップ開始");

  try {
    const now = new Date();
    const batchSize = 100; // 一度に処理する写真数
    let totalDeleted = 0;

    console.log(`📅 ${now.toISOString()} 時点で期限切れの写真を削除`);

    // 期限切れの写真を検索
    const snapshot = await firestore
      .collection('photos')
      .where('expiresAt', '<=', now)
      .limit(batchSize)
      .get();

    if (snapshot.empty) {
      console.log("✅ 削除対象の期限切れ写真なし");
      return;
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
        const likesSnapshot = await firestore
          .collection('likes')
          .where('photoId', '==', photoId)
          .get();

        const likeBatch = firestore.batch();
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
      console.log("🔄 さらに期限切れ写真が存在する可能性があります");
    }

  } catch (error) {
    console.error("❌ 期限切れ写真クリーンアップエラー:", error);
  }
});

// 期限切れいいねの自動削除（毎日午前2時に実行）
exports.cleanupExpiredLikes = onSchedule("0 2 * * *", async (event) => {
  console.log("🧹 期限切れいいねクリーンアップ開始");

  try {
    const now = new Date();
    const batchSize = 500; // いいねは軽量なので多めに処理
    let totalDeleted = 0;

    console.log(`📅 ${now.toISOString()} 時点で期限切れのいいねを削除`);

    // 期限切れのいいねを検索
    const snapshot = await firestore
      .collection('likes')
      .where('expiresAt', '<=', now)
      .limit(batchSize)
      .get();

    if (snapshot.empty) {
      console.log("✅ 削除対象の期限切れいいねなし");
      return;
    }

    console.log(`🗑️ ${snapshot.docs.length}件の期限切れいいねを削除中...`);

    // バッチ削除で効率化
    const batch = firestore.batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    totalDeleted = snapshot.docs.length;

    console.log(`✅ 期限切れいいねクリーンアップ完了: ${totalDeleted}件削除`);

    // 大量のデータがある場合の通知
    if (snapshot.docs.length === batchSize) {
      console.log("🔄 さらに期限切れいいねが存在する可能性があります");
    }

  } catch (error) {
    console.error("❌ 期限切れいいねクリーンアップエラー:", error);
  }
});

// 定期的な入道雲監視（5分間隔）
exports.monitorThunderClouds = onSchedule("*/5 * * * *", async (event) => {
  console.log("🌩️ 入道雲監視開始（5分間隔）");

  try {
    // アクティブユーザーを取得
    const usersSnapshot = await firestore
      .collection("users")
      .where("isActive", "==", true)
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
    await checkThunderCloudsWithCache(users);

    console.log("✅ 入道雲監視完了");
  } catch (error) {
    console.error("❌ エラー:", error);
  }
});

// キャッシュ統計情報を取得する関数（デバッグ用）
exports.getCacheStats = onRequest(async (req, res) => {
  // CORS設定
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  try {
    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - (60 * 60 * 1000));
    const twoHoursAgo = new Date(now.getTime() - (2 * 60 * 60 * 1000));

    // 全キャッシュ数
    const totalCacheSnapshot = await firestore.collection('weather_cache').get();

    // 1時間以内のキャッシュ数
    const recentCacheSnapshot = await firestore
      .collection('weather_cache')
      .where('timestamp', '>', oneHourAgo)
      .get();

    // 2時間より古いキャッシュ数（削除対象）
    const oldCacheSnapshot = await firestore
      .collection('weather_cache')
      .where('timestamp', '<', twoHoursAgo)
      .get();

    const stats = {
      totalCaches: totalCacheSnapshot.size,
      recentCaches: recentCacheSnapshot.size,
      oldCaches: oldCacheSnapshot.size,
      retentionHours: CACHE_CLEANUP_RETENTION_HOURS,
      cleanupBatchSize: CACHE_CLEANUP_BATCH_SIZE,
      timestamp: now.toISOString()
    };

    console.log("📊 キャッシュ統計:", stats);

    res.status(200).json({
      success: true,
      stats: stats
    });

  } catch (error) {
    console.error("❌ キャッシュ統計取得エラー:", error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

// 最適化されたバッチ処理
async function processUsersOptimizedBatch(users) {
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
    console.log("👥 処理対象のアクティブユーザーがいません");
    return;
  }

  console.log(`📊 段階的バッチ処理対象ユーザー数: ${activeUsers.length}`);

  // 全ユーザーの全座標を一度に収集（重複除去付き）
  const { uniqueCoordinates, coordinateUserMap } = collectUniqueCoordinates(activeUsers);

  console.log(`📍 座標最適化: 全${activeUsers.length * CHECK_DIRECTIONS.length * CHECK_DISTANCES.length}地点 → ${uniqueCoordinates.length}地点（重複除去）`);

  try {
    // 段階的バッチ処理（100地点ずつ）
    const BATCH_SIZE = 100;
    const batches = chunkArray(uniqueCoordinates, BATCH_SIZE);

    console.log(`🔄 段階的バッチ処理: ${uniqueCoordinates.length}地点を${batches.length}回に分けて処理（${BATCH_SIZE}地点ずつ）`);

    const allBatchResults = [];

    for (let i = 0; i < batches.length; i++) {
      const batch = batches[i];
      console.log(`🌐 バッチ ${i + 1}/${batches.length}: ${batch.length}地点を処理中...`);

      try {
        const batchResults = await fetchBatchWeatherDataOptimized(batch);
        allBatchResults.push(...batchResults);

        console.log(`✅ バッチ ${i + 1}/${batches.length} 完了: ${batchResults.length}地点のデータを取得`);

        // バッチ間で待機（API負荷軽減）
        if (i < batches.length - 1) {
          console.log(`⏳ バッチ間待機: 2秒...`);
          await new Promise(resolve => setTimeout(resolve, 2000));
        }

      } catch (batchError) {
        console.error(`❌ バッチ ${i + 1}/${batches.length} 処理エラー:`, batchError);

        // 失敗したバッチは個別処理にフォールバック
        console.log(`🔄 バッチ ${i + 1} を個別処理でフォールバック`);
        const fallbackResults = await processBatchFallback(batch);
        allBatchResults.push(...fallbackResults);
      }
    }

    console.log(`✅ 全段階的バッチ処理完了: ${allBatchResults.length}地点のデータを取得`);

    // 結果を各ユーザーに振り分けて通知判定
    const userNotifications = new Map();

    allBatchResults.forEach((weatherData, index) => {
      if (weatherData && index < uniqueCoordinates.length) {
        const coord = uniqueCoordinates[index];
        const coordKey = HelperFunctions.generateCacheKey(coord.latitude, coord.longitude);
        const analysis = ThunderCloudAnalyzer.analyzeWithMeteoDataOnly(weatherData);

        if (analysis.isThunderCloudLikely) {
          // この座標に関連するユーザーに通知
          const relatedUsers = coordinateUserMap.get(coordKey) || [];

          relatedUsers.forEach(({ userIndex, direction }) => {
            if (!userNotifications.has(userIndex)) {
              userNotifications.set(userIndex, new Set());
            }
            userNotifications.get(userIndex).add(direction);
          });
        }
      }
    });

    // 通知送信
    for (const [userIndex, directions] of userNotifications) {
      const user = activeUsers[userIndex];
      const directionArray = Array.from(directions);

      console.log(`📢 通知送信: ${user.fcmToken?.substring(0, 10)}... - ${directionArray.join('、')}`);
      await sendNotification(user.fcmToken, directionArray);
    }

    console.log(`✅ 段階的バッチ処理完了: ${userNotifications.size}人に通知送信（API呼び出し: ${batches.length}回）`);

  } catch (error) {
    console.error("❌ 段階的バッチ処理エラー:", error);

    // フォールバック: 従来の個別処理
    console.log("🔄 フォールバックで個別処理開始");
    await processUsersBatchFallback(activeUsers);
  }
}

// 配列を指定サイズで分割
function chunkArray(array, size) {
  const chunks = [];
  for (let i = 0; i < array.length; i += size) {
    chunks.push(array.slice(i, i + size));
  }
  return chunks;
}

// 個別バッチのフォールバック処理
async function processBatchFallback(coordinates) {
  console.log(`🔄 個別バッチフォールバック: ${coordinates.length}地点を個別処理`);

  const results = [];

  for (const coord of coordinates) {
    try {
      const weatherData = await fetchWeatherDataFromAPI(coord.latitude, coord.longitude);
      results.push(weatherData);

      // 個別処理間で少し待機
      await new Promise(resolve => setTimeout(resolve, 100));

    } catch (error) {
      console.error(`❌ 個別処理エラー (${coord.latitude}, ${coord.longitude}):`, error);
      // エラーの場合はデフォルト値を追加
      results.push({
        cape: 0,
        lifted_index: 0,
        convective_inhibition: 0,
        temperature: 20,
        cloud_cover: 0,
        cloud_cover_mid: 0,
        cloud_cover_high: 0
      });
    }
  }

  console.log(`✅ 個別バッチフォールバック完了: ${results.length}地点`);
  return results;
}

// 重複座標を除去して効率的に収集
function collectUniqueCoordinates(activeUsers) {
  const coordinateMap = new Map();
  const coordinateUserMap = new Map();

  activeUsers.forEach((user, userIndex) => {
    CHECK_DIRECTIONS.forEach(direction => {
      CHECK_DISTANCES.forEach(distance => {
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

// 最適化されたバッチAPI呼び出し（段階的処理対応）
async function fetchBatchWeatherDataOptimized(coordinates) {
  if (!coordinates || coordinates.length === 0) {
    return [];
  }

  console.log(`📊 段階的バッチAPI呼び出し: ${coordinates.length}地点の気象データを取得`);

  try {
    // Open-Meteoの複数地点同時取得機能を使用
    const latitudes = coordinates.map(coord => coord.latitude.toFixed(6)).join(',');
    const longitudes = coordinates.map(coord => coord.longitude.toFixed(6)).join(',');

    console.log(`🌐 API呼び出し: ${coordinates.length}地点を同時取得`);

    const response = await axios.get(
      `https://api.open-meteo.com/v1/forecast?` +
      `latitude=${latitudes}&longitude=${longitudes}&` +
      `hourly=cape,lifted_index,convective_inhibition,cloud_cover,cloud_cover_mid,cloud_cover_high&` +
      `current=temperature_2m&timezone=auto&forecast_days=1`,
      {
        timeout: 60000, // 60秒タイムアウト（段階的処理用）
        headers: {
          'User-Agent': 'ThunderCloudApp/1.0'
        },
        maxRedirects: 3,
        validateStatus: function (status) {
          return status >= 200 && status < 300;
        }
      }
    );

    console.log(`✅ 段階的バッチAPI呼び出し成功: ${coordinates.length}地点`);

    // レスポンスを各地点に分割
    const results = [];
    const dataCount = Array.isArray(response.data.latitude) ? response.data.latitude.length : 1;

    if (dataCount !== coordinates.length) {
      console.warn(`⚠️ データ数不一致: 期待値${coordinates.length}、実際${dataCount}`);
    }

    for (let i = 0; i < Math.min(dataCount, coordinates.length); i++) {
      const weatherData = extractWeatherDataFromResponse(response.data, i);
      results.push(weatherData);
    }

    // データが不足している場合はデフォルト値で補完
    while (results.length < coordinates.length) {
      results.push({
        cape: 0,
        lifted_index: 0,
        convective_inhibition: 0,
        temperature: 20,
        cloud_cover: 0,
        cloud_cover_mid: 0,
        cloud_cover_high: 0
      });
    }

    console.log(`✅ 段階的バッチ処理完了: ${results.length}地点のデータを処理`);
    return results;

  } catch (error) {
    if (error.code === 'ECONNABORTED') {
      console.error(`❌ 段階的バッチAPI タイムアウト: ${coordinates.length}地点`);
    } else if (error.response) {
      console.error(`❌ 段階的バッチAPI HTTPエラー: ${error.response.status} - ${coordinates.length}地点`);
    } else if (error.request) {
      console.error(`❌ 段階的バッチAPI ネットワークエラー: ${coordinates.length}地点`);
    } else {
      console.error(`❌ 段階的バッチAPI 不明なエラー: ${coordinates.length}地点`, error.message);
    }
    throw error;
  }
}

// レスポンスから気象データを抽出
function extractWeatherDataFromResponse(responseData, index) {
  return {
    cape: Array.isArray(responseData.hourly.cape) ?
      (responseData.hourly.cape[index] ? responseData.hourly.cape[index][0] || 0 : 0) :
      (responseData.hourly.cape[0] || 0),
    lifted_index: Array.isArray(responseData.hourly.lifted_index) ?
      (responseData.hourly.lifted_index[index] ? responseData.hourly.lifted_index[index][0] || 0 : 0) :
      (responseData.hourly.lifted_index[0] || 0),
    convective_inhibition: Array.isArray(responseData.hourly.convective_inhibition) ?
      (responseData.hourly.convective_inhibition[index] ? responseData.hourly.convective_inhibition[index][0] || 0 : 0) :
      (responseData.hourly.convective_inhibition[0] || 0),
    temperature: Array.isArray(responseData.current.temperature_2m) ?
      (responseData.current.temperature_2m[index] || 20) :
      (responseData.current.temperature_2m || 20),
    cloud_cover: Array.isArray(responseData.hourly.cloud_cover) ?
      (responseData.hourly.cloud_cover[index] ? responseData.hourly.cloud_cover[index][0] || 0 : 0) :
      (responseData.hourly.cloud_cover[0] || 0),
    cloud_cover_mid: Array.isArray(responseData.hourly.cloud_cover_mid) ?
      (responseData.hourly.cloud_cover_mid[index] ? responseData.hourly.cloud_cover_mid[index][0] || 0 : 0) :
      (responseData.hourly.cloud_cover_mid[0] || 0),
    cloud_cover_high: Array.isArray(responseData.hourly.cloud_cover_high) ?
      (responseData.hourly.cloud_cover_high[index] ? responseData.hourly.cloud_cover_high[index][0] || 0 : 0) :
      (responseData.hourly.cloud_cover_high[0] || 0)
  };
}

// フォールバック用の従来処理
async function processUsersBatchFallback(activeUsers) {
  console.log("🔄 フォールバック処理: 従来の個別処理");

  for (const user of activeUsers) {
    try {
      await checkUserLocation(user);
    } catch (userError) {
      console.error(`❌ ユーザー個別処理エラー: ${user.fcmToken?.substring(0, 10)}...`, userError);
    }
  }
}

// 従来の個別ユーザー処理（フォールバック用）
async function checkUserLocation(user) {
  const thunderCloudDirections = [];

  for (const direction of CHECK_DIRECTIONS) {
    let thunderCloudExists = false;

    for (const distance of CHECK_DISTANCES) {
      const coordinates = calculateDirectionCoordinates(
        direction, user.latitude, user.longitude, distance
      );

      const isThunderCloud = await checkThunderCloudCondition(
        coordinates.latitude, coordinates.longitude
      );

      if (isThunderCloud) {
        thunderCloudExists = true;
        break;
      }
    }

    if (thunderCloudExists) {
      thunderCloudDirections.push(direction);
    }
  }

  if (thunderCloudDirections.length > 0) {
    await sendNotification(user.fcmToken, thunderCloudDirections);
  }
}

// 個別の入道雲状態チェック（フォールバック用）
async function checkThunderCloudCondition(lat, lon) {
  try {
    const response = await axios.get(
      `https://api.open-meteo.com/v1/forecast?` +
      `latitude=${lat.toFixed(6)}&longitude=${lon.toFixed(6)}&` +
      `hourly=cape,lifted_index,convective_inhibition,cloud_cover,cloud_cover_mid,cloud_cover_high&` +
      `current=temperature_2m&timezone=auto&forecast_days=1`
    );

    const weatherData = {
      cape: response.data.hourly.cape[0] || 0,
      lifted_index: response.data.hourly.lifted_index[0] || 0,
      convective_inhibition: response.data.hourly.convective_inhibition[0] || 0,
      temperature: response.data.current.temperature_2m || 20,
      cloud_cover: response.data.hourly.cloud_cover[0] || 0,
      cloud_cover_mid: response.data.hourly.cloud_cover_mid[0] || 0,
      cloud_cover_high: response.data.hourly.cloud_cover_high[0] || 0
    };

    const result = ThunderCloudAnalyzer.analyzeWithMeteoDataOnly(weatherData);
    return result.isThunderCloudLikely;
  } catch (error) {
    console.error("❌ 気象データ取得エラー:", error);
    return false;
  }
}

async function sendNotification(fcmToken, directions) {
  const message = {
    token: fcmToken,
    notification: {
      title: "⛈️ 入道雲警報",
      body: `${directions.join('、')}方向に入道雲が発生しています！`,
    },
    data: {
      type: "thunder_cloud",
      directions: directions.join(','),
      timestamp: new Date().toISOString(),
    },
    android: {
      notification: {
        color: "#FF6B35", // 通知の色（オレンジ系）
        channelId: "thunder_cloud_channel",
        priority: "high",
        defaultSound: true,
        defaultVibrateTimings: true,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
          alert: {
            title: "⛈️ 入道雲警報",
            body: `${directions.join('、')}方向に入道雲が発生しています！`,
          },
        },
      },
    },
  };

  try {
    await messaging.send(message);
    console.log(`✅ 通知送信成功: ${directions.join('、')}`);
  } catch (error) {
    console.error("❌ 通知送信失敗:", error);
  }
}