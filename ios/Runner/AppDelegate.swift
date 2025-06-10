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

    // APNS登録
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // APNS token受信時の処理
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("📱 APNS Token registered successfully")
    Messaging.messaging().apnsToken = deviceToken
  }

  // APNS token取得失敗時の処理
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ APNS Token registration failed: \(error)")
  }

  // FCM token更新時の処理
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("📝 FCM token updated: \(fcmToken ?? "nil")")
  }
}
