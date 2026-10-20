// functions/modules/notification/notification_service.js
const admin = require('firebase-admin');

// 通知本文に表示する方向名（data.directions はアプリが解析するため英語のまま送る）
const DIRECTION_LABELS = {
  north: '北',
  south: '南',
  east: '東',
  west: '西',
};

class NotificationService {
  constructor() {
    this.messaging = admin.messaging();
  }

  /**
   * 入道雲警報を送信
   */
  async sendThunderCloudAlert(fcmToken, directions) {
    const body = `${directions.map((d) => DIRECTION_LABELS[d] || d).join('、')}の方向に入道雲が発生しています！`;
    const message = {
      token: fcmToken,
      notification: {
        title: '⛈️ 入道雲警報',
        body,
      },
      data: {
        type: 'thunder_cloud',
        directions: directions.join(','),
        timestamp: new Date().toISOString(),
      },
      android: {
        notification: {
          color: '#FF6B35', // 通知の色（オレンジ系）
          channelId: 'thunder_cloud_channel',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            alert: {
              title: '⛈️ 入道雲警報',
              body,
            },
          },
        },
      },
    };

    try {
      await this.messaging.send(message);
      console.log(`✅ 通知送信成功: ${directions.join('、')}`);
      return true;
    } catch (error) {
      console.error('❌ 通知送信失敗:', error);
      return false;
    }
  }
}

module.exports = NotificationService;
