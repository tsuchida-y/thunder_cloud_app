"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkThunderClouds = void 0;
// functions/src/index.ts
const axios_1 = __importDefault(require("axios"));
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const messaging_1 = require("firebase-admin/messaging");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const coordinate_utils_1 = require("./coordinate_utils");
const thunder_cloud_analyzer_1 = require("./thunder_cloud_analyzer");
// Firebase Admin 初期化
(0, app_1.initializeApp)();
const firestore = (0, firestore_1.getFirestore)();
const messaging = (0, messaging_1.getMessaging)();
const CHECK_DIRECTIONS = ["north", "south", "east", "west"];
const CHECK_DISTANCES = [50.0, 160.0, 250.0];
// 5分間隔で入道雲チェック (Firebase Functions v5)
exports.checkThunderClouds = (0, scheduler_1.onSchedule)("every 5 minutes", async (event) => {
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
    }
    catch (error) {
        console.error("❌ エラー:", error);
    }
});
async function checkUserLocation(user) {
    const thunderCloudDirections = [];
    for (const direction of CHECK_DIRECTIONS) {
        let thunderCloudExists = false;
        for (const distance of CHECK_DISTANCES) {
            const coordinates = (0, coordinate_utils_1.calculateDirectionCoordinates)(direction, user.latitude, user.longitude, distance);
            const isThunderCloud = await checkThunderCloudCondition(coordinates.latitude, coordinates.longitude);
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
        const response = await axios_1.default.get(`https://api.open-meteo.com/v1/forecast?` +
            `latitude=${lat.toFixed(6)}&longitude=${lon.toFixed(6)}&` +
            `hourly=cape,lifted_index,convective_inhibition&` +
            `current=temperature_2m&timezone=auto&forecast_days=1`);
        const weatherData = {
            cape: response.data.hourly.cape[0] || 0,
            lifted_index: response.data.hourly.lifted_index[0] || 0,
            convective_inhibition: response.data.hourly.convective_inhibition[0] || 0,
            temperature: response.data.current.temperature_2m || 20
        };
        const result = thunder_cloud_analyzer_1.ThunderCloudAnalyzer.analyzeWithMeteoDataOnly(weatherData);
        return result.isThunderCloudLikely;
    }
    catch (error) {
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
    }
    catch (error) {
        console.error("❌ 通知送信失敗:", error);
    }
}
//# sourceMappingURL=index.js.map