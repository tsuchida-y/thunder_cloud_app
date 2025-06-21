const axios = require("axios");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const { calculateDirectionCoordinates } = require("./coordinate_utils");
const { ThunderCloudAnalyzer } = require("./thunder_cloud_analyzer");

// Firebase Admin 初期化
initializeApp();
const firestore = getFirestore();
const messaging = getMessaging();

const CHECK_DIRECTIONS = ["north", "south", "east", "west"];
const CHECK_DISTANCES = [50.0, 160.0, 250.0];

// 気象データキャッシュの有効期限（5分）
const WEATHER_CACHE_DURATION = 5 * 60 * 1000;

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

// キャッシュ機能付き気象データ取得
async function getWeatherDataWithCache(lat, lon) {
  const cacheKey = `weather_${lat.toFixed(4)}_${lon.toFixed(4)}`;
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
    const weatherData = await fetchWeatherDataFromAPI(lat, lon);

    if (weatherData) {
      const result = {
        north: await getDirectionWeatherData('north', lat, lon),
        south: await getDirectionWeatherData('south', lat, lon),
        east: await getDirectionWeatherData('east', lat, lon),
        west: await getDirectionWeatherData('west', lat, lon),
      };

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

// 指定方向の気象データを取得・分析
async function getDirectionWeatherData(direction, baseLat, baseLon) {
  const coordinates = calculateDirectionCoordinates(direction, baseLat, baseLon, 50.0);
  const weatherData = await fetchWeatherDataFromAPI(coordinates.latitude, coordinates.longitude);

  if (weatherData) {
    const analysis = ThunderCloudAnalyzer.analyzeWithMeteoDataOnly(weatherData);

    return {
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

  return null;
}

// Open-Meteo APIから気象データを取得
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

// 5分間隔で入道雲チェック (Firebase Functions v5)
exports.checkThunderClouds = onSchedule("every 5 minutes", async (event) => {
  console.log("🌩️ 入道雲チェック開始");

  try {
    // インデックス不要なシンプルなクエリに変更
    const usersSnapshot = await firestore
      .collection("users")
      .where("isActive", "==", true)
      .get();

    console.log(`👥 アクティブユーザー数: ${usersSnapshot.size}`);

    // 取得したユーザーを日付でソート（メモリ内）
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

    for (const user of users) {
      const lastUpdated = user.lastUpdated?.toDate?.() || new Date(0);
      const now = new Date();

      // 24時間以内に位置更新があったユーザーのみ監視
      if (lastUpdated && (now.getTime() - lastUpdated.getTime()) < 24 * 60 * 60 * 1000) {
        console.log(`🔍 ユーザー処理中: ${user.fcmToken?.substring(0, 10)}...`);
        await checkUserLocation(user);
      } else {
        console.log(`⏰ ユーザー位置情報が古いためスキップ: ${user.fcmToken?.substring(0, 10)}...`);
      }
    }

    console.log("✅ 入道雲チェック完了");
  } catch (error) {
    console.error("❌ エラー:", error);
  }
});

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
        icon: "ic_launcher", // Androidのアプリアイコンを使用
        color: "#FF6B35", // 通知の色（オレンジ系）
        channelId: "thunder_cloud_alerts",
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