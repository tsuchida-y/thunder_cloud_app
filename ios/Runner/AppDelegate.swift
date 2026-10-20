import CoreLocation
import Flutter
import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate, CLLocationManagerDelegate {
  /// 通知のカテゴリとボタン（サーバーの functions/modules/notification/notification_service.js と同じ名前）
  private static let cloudCategory = "CLOUD_REPORT"
  private static let seenAction = "seen"
  private static let notSeenAction = "not_seen"

  /// 通知のボタンで答えたものを、アプリが次に開いたときに reports へ送るまで残しておく場所。
  /// shared_preferences の「pending_reports」（文字列のリスト）と同じ場所
  private static let pendingReportsKey = "flutter.pending_reports"

  private let locationManager = CLLocationManager()
  private var alwaysResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)

    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    registerCloudCategory()
    Messaging.messaging().delegate = self
    // 作った直後にも許可の状態の知らせが来るので、お願いより前に受け取り役を決めておく
    locationManager.delegate = self
    // 許可のお願いはしない（はじめての起動の画面でお願いする）。トークンの準備だけ
    application.registerForRemoteNotifications()

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "thunder_cloud/location_always", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        if call.method == "requestAlways" {
          self?.requestAlways(result: result)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    // トークンはアプリ（Dart）が members に書く
  }

  // MARK: - 通知の「見えた」「見えなかった」

  private func registerCloudCategory() {
    // アプリを開かずに答えられるよう、ボタンは前に出さない（options: []）
    let seen = UNNotificationAction(identifier: AppDelegate.seenAction, title: "見えた", options: [])
    let notSeen = UNNotificationAction(identifier: AppDelegate.notSeenAction, title: "見えなかった", options: [])
    let category = UNNotificationCategory(identifier: AppDelegate.cloudCategory, actions: [seen, notSeen], intentIdentifiers: [], options: [])
    UNUserNotificationCenter.current().setNotificationCategories([category])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let action = response.actionIdentifier
    guard action == AppDelegate.seenAction || action == AppDelegate.notSeenAction else {
      // 通知そのものを押したときは、これまでどおり firebase_messaging に渡す（方角ガイドを開く）
      super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
      return
    }
    let info = response.notification.request.content.userInfo
    let report: [String: Any] = [
      "seen": action == AppDelegate.seenAction,
      "cloudId": info["cloudId"] as? String ?? "",
      "bearingDeg": info["bearingDeg"] as? String ?? "",
      "distanceKm": info["distanceKm"] as? String ?? "",
      "answeredAt": Int(Date().timeIntervalSince1970 * 1000),
    ]
    if let data = try? JSONSerialization.data(withJSONObject: report),
       let json = String(data: data, encoding: .utf8) {
      let defaults = UserDefaults.standard
      var pending = defaults.array(forKey: AppDelegate.pendingReportsKey) as? [String] ?? []
      pending.append(json)
      defaults.set(pending, forKey: AppDelegate.pendingReportsKey)
    }
    completionHandler()
  }

  // MARK: - 位置情報の「常に」（AlwaysAllow.html）

  /// 「使用中」の人に「常に」をお願いする。
  /// 返す値: "always"（常にになった）、"declined"（確認の画面で断った）、"unavailable"（iOS が確認の画面を出さなかった。2回目以降など）
  private func requestAlways(result: @escaping FlutterResult) {
    let status = locationManager.authorizationStatus
    guard status == .authorizedWhenInUse else {
      result(status == .authorizedAlways ? "always" : "unavailable")
      return
    }
    alwaysResult = result
    locationManager.requestAlwaysAuthorization()
    // 確認の画面が出なかったとき（アプリが前に出たまま）は、知らせが来ないので少し待って返す
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
      if UIApplication.shared.applicationState == .active { self?.finishAlways(otherwise: "unavailable") }
    }
    // 確認の画面で「使用中のままにする」を選ぶと状態が変わらず知らせも来ないので、アプリに戻ったときに返す
    var observer: NSObjectProtocol?
    observer = NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      if let observer = observer { NotificationCenter.default.removeObserver(observer) }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.finishAlways(otherwise: "declined") }
    }
  }

  private func finishAlways(otherwise: String) {
    guard let pending = alwaysResult else { return }
    alwaysResult = nil
    pending(locationManager.authorizationStatus == .authorizedAlways ? "always" : otherwise)
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if manager.authorizationStatus == .authorizedAlways { finishAlways(otherwise: "always") }
  }
}
