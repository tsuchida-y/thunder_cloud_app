// functions/src/index.ts
import axios from "axios";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { calculateDirectionCoordinates } from "./coordinate_utils";
import { ThunderCloudAnalyzer } from "./thunder_cloud_analyzer";

// Firebase Admin 初期化
initializeApp();
const firestore = getFirestore();
const messaging = getMessaging();

const CHECK_DIRECTIONS = ["north", "south", "east", "west"];
const CHECK_DISTANCES = [50.0, 160.0, 250.0];

// 5分間隔で入道雲チェック (Firebase Functions v5)
export const checkThunderClouds = onSchedule("every 5 minutes", async (event) => {
  console.log("🌩️ 入道雲チェック開始");

  try {
    const usersSnapshot = await firestore
      .collection("users")
      .where("isActive", "==", true)
      .get();

    console.log(`👥 アクティブユーザー数: ${usersSnapshot.size}`);

    for (const userDoc of usersSnapshot.docs) {
      const user = userDoc.data();
      await checkUserLocation(user);
    }
  } catch (error) {
    console.error("❌ エラー:", error);
  }
});

async function checkUserLocation(user: any): Promise<void> {
  const thunderCloudDirections: string[] = [];

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

async function checkThunderCloudCondition(lat: number, lon: number): Promise<boolean> {
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

async function sendNotification(fcmToken: string, directions: string[]): Promise<void> {
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