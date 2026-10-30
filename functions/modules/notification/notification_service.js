// functions/modules/notification/notification_service.js
const admin = require('firebase-admin');

// アプリ側（Android の通知、iOS の通知カテゴリ）と名前を揃える
const IOS_CATEGORY = 'CLOUD_REPORT'; // 「見えた」「見えなかった」のボタン付き
const ANDROID_TTL_MS = 30 * 60 * 1000; // 30分たって届かなかった通知は捨てる（もう見えていないかもしれないため）

// FCM のトークンがもう使えないことを表すエラー
const INVALID_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

class NotificationService {
  constructor(messaging = null) {
    this._messaging = messaging;
  }

  get messaging() {
    return this._messaging || admin.messaging();
  }

  /**
   * 「現れました」の通知を送る
   *
   * Android は FCM の通知のままではボタンを付けられないので、データだけを送り、
   * アプリが「見えた」「見えなかった」のボタン付きの通知を出す（チャンネル cloud_appeared）。
   * iOS は通知をそのまま出し、カテゴリ CLOUD_REPORT でボタンを付ける（アプリがカテゴリを登録しておく）。
   * どちらも雲の ID で通知をまとめるので、あとで同じ雲の通知を書き換えられる（予告→現れました）。
   *
   * @param {string} fcmToken
   * @param {{title:string, body:string}} message
   * @param {Object<string,string|number>} data - アプリに渡す値（方角、距離など）
   * @param {string} cloudId
   * @returns {Promise<{ok:boolean, invalidToken?:boolean}>}
   */
  async sendCloudNotification(fcmToken, message, data, cloudId) {
    const stringData = Object.fromEntries(
      Object.entries({ ...data, title: message.title, body: message.body, cloudId })
        .map(([key, value]) => [key, String(value)])
    );
    try {
      await this.messaging.send({
        token: fcmToken,
        data: stringData,
        android: {
          priority: 'high',
          collapseKey: cloudId,
          ttl: ANDROID_TTL_MS,
        },
        apns: {
          headers: {
            'apns-collapse-id': cloudId,
            'apns-priority': '10',
            'apns-push-type': 'alert',
          },
          payload: {
            aps: {
              alert: { title: message.title, body: message.body },
              sound: 'default',
              category: IOS_CATEGORY,
              'thread-id': 'clouds',
            },
          },
        },
      });
      return { ok: true };
    } catch (error) {
      const code = error && error.code;
      if (INVALID_TOKEN_CODES.has(code)) {
        return { ok: false, invalidToken: true };
      }
      console.error('❌ 通知の送信に失敗しました:', code || error);
      return { ok: false };
    }
  }
}

module.exports = NotificationService;
