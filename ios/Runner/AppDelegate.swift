import Flutter
import UIKit
import GoogleMaps
import Firebase
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase初期化
    FirebaseApp.configure()

    GMSServices.provideAPIKey("AIzaSyC8q8kr1HYOMNpDPZQ-Mp4UQ6zIzbmGjUw")

    GeneratedPluginRegistrant.register(with: self)

    // 通知権限設定（iOS）
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    // Firebase Messaging delegate設定
    Messaging.messaging().delegate = self

    // APNS登録（確実に実行）
    print("📱 Registering for remote notifications...")
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // APNS token受信時の処理
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("📱 APNS Token registered successfully: \(tokenString)")

    // APNSトークンを設定
    Messaging.messaging().apnsToken = deviceToken
    print("📱 APNS Token set in Firebase Messaging")

    // 少し待ってからFCMトークンを取得
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      Messaging.messaging().token { token, error in
        if let error = error {
          print("❌ FCM token error after APNS success: \(error)")
        } else if let token = token {
          print("✅ FCM token obtained after APNS success: \(token.prefix(20))...")
        }
      }
    }
  }

  // APNS token取得失敗時の処理
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ APNS Token registration failed: \(error.localizedDescription)")

    // エラーの詳細を出力
    if let nsError = error as NSError? {
      print("❌ APNS Error Code: \(nsError.code)")
      print("❌ APNS Error Domain: \(nsError.domain)")
      print("❌ APNS Error UserInfo: \(nsError.userInfo)")
    }

    // 失敗時もFCMトークン取得を試行（開発環境での回避策）
    print("🔄 Attempting FCM token retrieval despite APNS failure...")
    Messaging.messaging().token { token, error in
      if let error = error {
        print("❌ FCM token error after APNS failure: \(error)")
      } else if let token = token {
        print("✅ FCM token obtained despite APNS failure: \(token.prefix(20))...")
      }
    }
  }

  // FCM token更新時の処理
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("📝 FCM token updated: \(fcmToken ?? "nil")")
  }
}
