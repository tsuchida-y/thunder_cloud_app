import CoreLocation
import Flutter
import UIKit
import Firebase
import FirebaseAuth
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, MessagingDelegate, CLLocationManagerDelegate {
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
    // プラグインとチャンネルの登録は didInitializeImplicitFlutterEngine で行う（UIScene の起動の仕組み。iOS 27 で必須）

    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    registerCloudCategory()
    Messaging.messaging().delegate = self
    // 作った直後にも許可の状態の知らせが来るので、お願いより前に受け取り役を決めておく
    locationManager.delegate = self
    // 「常に」の人は、大きく移動したときに場所を書く（アプリが閉じていても OS が起こしてくれる）
    BackgroundLocation.shared.sync()
    // 許可のお願いはしない（はじめての起動の画面でお願いする）。トークンの準備だけ
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Flutter のエンジンができたとき（UIScene の起動の仕組みでは、ここでプラグインとチャンネルを登録する）
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "thunder_cloud/location_always",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "requestAlways" {
        self?.requestAlways(result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
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
    BackgroundLocation.shared.sync()
  }
}

/// 位置情報を「常に」にした人の場所を、アプリを閉じているあいだも members に書く（iOS）
///
/// - OS の「大きな移動の検知」（数百m〜1km ほど動いたとき）を使う。電池をほとんど使わず、アプリが閉じていても起こしてもらえる
/// - 前に書いた場所から1km以上動いたときだけ書く。位置は小数第2位（約1km）に丸める
/// - lastOpenedAt は書かない（サーバーは「開いて10分以内の人には送らない」に使うため）
/// - Firestore には REST で書く（Flutter 側の Firestore と設定がぶつからないように）。
///   本人のログインの ID トークンを付けるので、firestore.rules の「本人だけが自分の members を書ける」がそのまま効く
final class BackgroundLocation: NSObject, CLLocationManagerDelegate {
  static let shared = BackgroundLocation()

  private let manager = CLLocationManager()
  private let minMoveMeters: CLLocationDistance = 1000
  private let lastLatKey = "background_location_lat"
  private let lastLngKey = "background_location_lng"

  private override init() {
    super.init()
    manager.delegate = self
  }

  /// 「常に」なら見張りを始め、そうでなければ止める
  func sync() {
    if manager.authorizationStatus == .authorizedAlways && CLLocationManager.significantLocationChangeMonitoringAvailable() {
      manager.startMonitoringSignificantLocationChanges()
    } else {
      manager.stopMonitoringSignificantLocationChanges()
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    sync()
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    let defaults = UserDefaults.standard
    if defaults.object(forKey: lastLatKey) != nil {
      let last = CLLocation(latitude: defaults.double(forKey: lastLatKey), longitude: defaults.double(forKey: lastLngKey))
      if location.distance(from: last) < minMoveMeters { return }
    }
    guard let user = Auth.auth().currentUser,
          let projectId = FirebaseApp.app()?.options.projectID else { return }

    // 書き終わるまでアプリを止めないよう OS にお願いする
    var task: UIBackgroundTaskIdentifier = .invalid
    task = UIApplication.shared.beginBackgroundTask { UIApplication.shared.endBackgroundTask(task) }
    user.getIDToken { [weak self] token, _ in
      guard let self = self, let token = token else {
        UIApplication.shared.endBackgroundTask(task)
        return
      }
      self.write(location: location, uid: user.uid, projectId: projectId, idToken: token) { ok in
        if ok {
          defaults.set(location.coordinate.latitude, forKey: self.lastLatKey)
          defaults.set(location.coordinate.longitude, forKey: self.lastLngKey)
        }
        UIApplication.shared.endBackgroundTask(task)
      }
    }
  }

  private func round2(_ value: Double) -> Double { (value * 100).rounded() / 100 }

  /// members/{uid} の location だけを書き換える（Firestore REST の commit）
  private func write(location: CLLocation, uid: String, projectId: String, idToken: String, done: @escaping (Bool) -> Void) {
    let docName = "projects/\(projectId)/databases/(default)/documents/members/\(uid)"
    let body: [String: Any] = [
      "writes": [[
        "update": [
          "name": docName,
          "fields": [
            "location": ["mapValue": ["fields": [
              "latitude": ["doubleValue": round2(location.coordinate.latitude)],
              "longitude": ["doubleValue": round2(location.coordinate.longitude)],
            ]]],
            "locationSource": ["stringValue": "background"],
          ],
        ],
        "updateMask": ["fieldPaths": ["location", "locationSource"]],
        "updateTransforms": [["fieldPath": "locationUpdatedAt", "setToServerValue": "REQUEST_TIME"]],
        // アプリが作った members があるときだけ書く
        "currentDocument": ["exists": true],
      ]],
    ]
    guard let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents:commit"),
          let data = try? JSONSerialization.data(withJSONObject: body) else {
      done(false)
      return
    }
    var request = URLRequest(url: url, timeoutInterval: 20)
    request.httpMethod = "POST"
    request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
    request.httpBody = data
    URLSession.shared.dataTask(with: request) { _, response, _ in
      let code = (response as? HTTPURLResponse)?.statusCode ?? 0
      if !(200...299).contains(code) { print("BackgroundLocation: 場所を書けませんでした HTTP \(code)") }
      done((200...299).contains(code))
    }.resume()
  }
}
