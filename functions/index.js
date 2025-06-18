const axios = require("axios");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { calculateDirectionCoordinates } = require("./coordinate_utils");
const { ThunderCloudAnalyzer } = require("./thunder_cloud_analyzer");

// Firebase Admin 初期化
initializeApp();
const firestore = getFirestore();
const messaging = getMessaging();

const CHECK_DIRECTIONS = ["north", "south", "east", "west"];
const CHECK_DISTANCES = [50.0, 160.0, 250.0];

// 5分間隔で入道雲チェック (Firebase Functions v5)
exports.checkThunderClouds = onSchedule("every 5 minutes", async (event) => {
  console.log("🌩️ 入道雲チェック開始");

  try {
    const usersSnapshot = await firestore
      .collection("users")
      .where("isActive", "==", true)
      .orderBy("lastUpdated", "desc")
      .get();

    console.log(`👥 アクティブユーザー数: ${usersSnapshot.size}`);

    for (const userDoc of usersSnapshot.docs) {
      const user = userDoc.data();
      const lastUpdated = user.lastUpdated?.toDate();
      const now = new Date();

      // 24時間以内に位置更新があったユーザーのみ監視
      if (lastUpdated && (now.getTime() - lastUpdated.getTime()) < 24 * 60 * 60 * 1000) {
        await checkUserLocation(user);
      } else {
        console.log(`⏰ ユーザー位置情報が古いためスキップ: ${user.fcmToken?.substring(0, 10)}...`);
      }
    }
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
      `hourly=cape,lifted_index,convective_inhibition&` +
      `current=temperature_2m&timezone=auto&forecast_days=1`
    );

    const weatherData = {
      cape: response.data.hourly.cape[0] || 0,
      lifted_index: response.data.hourly.lifted_index[0] || 0,
      convective_inhibition: response.data.hourly.convective_inhibition[0] || 0,
      temperature: response.data.current.temperature_2m || 20
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
  };

  try {
    await messaging.send(message);
    console.log(`✅ 通知送信成功: ${directions.join('、')}`);
  } catch (error) {
    console.error("❌ 通知送信失敗:", error);
  }
}