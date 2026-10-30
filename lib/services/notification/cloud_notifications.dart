import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../models/finder_target.dart';
import '../../utils/logger.dart';
import '../member/member_service.dart';
import '../sky/report_service.dart';

/// 入道雲の通知（v2.0、Notify.html）
///
/// サーバー（functions/modules/notification/notification_service.js）と名前をそろえる。
/// - iOS: 通知はそのまま届き、カテゴリ CLOUD_REPORT で「見えた」「見えなかった」のボタンが付く
///   （カテゴリとボタンの処理は ios/Runner/AppDelegate.swift）
/// - Android: データだけが届くので、アプリがチャンネル cloud_appeared でボタン付きの通知を出す
/// - 通知を押すと方角ガイドを開く。ボタンを押したときはアプリを開かず、答えを残して次に開いたときに送る
class CloudNotifications {
  CloudNotifications._();

  static const String channelId = 'cloud_appeared';
  static const String channelName = '入道雲のお知らせ';
  static const String seenAction = 'seen';
  static const String notSeenAction = 'not_seen';

  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static final StreamController<FinderTarget> _opened = StreamController<FinderTarget>.broadcast();

  /// iOS: 通知を押したことを AppDelegate.swift から受け取る（UIScene の起動の仕組みでは firebase_messaging に届かないため）
  static const MethodChannel _iosTap = MethodChannel('thunder_cloud/notification_tap');
  static bool _initialized = false;
  static StreamSubscription<String>? _tokenSub;

  /// 通知を押してアプリを開いたとき、案内する雲が流れる
  static Stream<FinderTarget> get opened => _opened.stream;

  /// 閉じていたアプリを通知で開いたときの雲（ホームができる前に分かるので、ホームが取りに来るまで持っておく）
  static FinderTarget? _launchTarget;

  static FinderTarget? takeLaunchTarget() {
    final target = _launchTarget;
    _launchTarget = null;
    return target;
  }

  /// アプリの起動時に1回呼ぶ（画面を出すのを待たせないよう、終わりを待たずに呼んでよい）
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (Platform.isAndroid) {
      await _initLocal(onTap: _onLocalResponse);
      final launch = await _local.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if (launch?.didNotificationLaunchApp == true && response != null && response.actionId == null) {
        final data = _payload(response);
        _launchTarget = data == null ? null : FinderTarget.fromNotification(data);
      }
    } else {
      // UIScene の起動の仕組み（iOS 27 で必須）では、firebase_messaging の onMessageOpenedApp と
      // getInitialMessage に通知を押したことが届かない（2026-10-23 に実機で確かめた）。
      // AppDelegate.swift が押された通知のデータを持っておくので、知らせが来たときと起動したときに取りに行く
      _iosTap.setMethodCallHandler((call) async {
        if (call.method == 'tapped') await _takeIosTap();
      });
      // アプリを開いているときに届いた通知も出す
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, sound: true);
      // 閉じていたアプリを通知で開いたとき
      await _takeIosTap();
    }

    // Android はアプリを開いているときもデータだけが届くので、自分で出す
    FirebaseMessaging.onMessage.listen((message) {
      if (Platform.isAndroid) showFromData(message.data);
    });
  }

  static Future<void> _initLocal({DidReceiveNotificationResponseCallback? onTap}) async {
    await _local.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: onTap,
      onDidReceiveBackgroundNotificationResponse: onNotificationActionInBackground,
    );
  }

  /// Android: サーバーから届いたデータで、ボタン付きの通知を出す（アプリが閉じていても呼ばれる）
  static Future<void> showFromData(Map<String, dynamic> data) async {
    if (data['type'] != 'cloud_appeared') return;
    await _initLocal();
    final cloudId = '${data['cloudId'] ?? ''}';
    await _local.show(
      cloudId.hashCode,
      data['title'] as String?,
      data['body'] as String?,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: '入道雲が見える範囲に現れたときのお知らせ',
          importance: Importance.high,
          priority: Priority.high,
          // 同じ雲の通知は1つにまとめる
          tag: cloudId,
          category: AndroidNotificationCategory.recommendation,
          actions: const [
            AndroidNotificationAction(seenAction, '見えた'),
            AndroidNotificationAction(notSeenAction, '見えなかった'),
          ],
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  static void _onLocalResponse(NotificationResponse response) {
    final data = _payload(response);
    if (data == null) return;
    if (response.actionId == seenAction || response.actionId == notSeenAction) {
      ReportService.queueFromNotification(data, seen: response.actionId == seenAction)
          .then((_) => ReportService.flushPending());
    } else {
      _openFromData(data);
    }
  }

  static Future<void> _takeIosTap() async {
    try {
      final data = await _iosTap.invokeMapMethod<String, dynamic>('takeTap');
      final target = data == null ? null : FinderTarget.fromNotification(data);
      if (target == null) return;
      // ホームがもう聞いていれば流し、まだなら取りに来るまで持っておく
      if (_opened.hasListener) {
        _opened.add(target);
      } else {
        _launchTarget = target;
      }
    } catch (e) {
      AppLogger.warning('押された通知を受け取れませんでした: $e', tag: 'CloudNotifications');
    }
  }

  static Map<String, dynamic>? _payload(NotificationResponse response) {
    try {
      return jsonDecode(response.payload ?? '') as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static void _openFromData(Map<String, dynamic> data) {
    final target = FinderTarget.fromNotification(data);
    if (target != null) _opened.add(target);
  }

  /// 通知が許可されているか
  static Future<bool> allowed() async {
    try {
      final status = (await FirebaseMessaging.instance.getNotificationSettings()).authorizationStatus;
      return status == AuthorizationStatus.authorized || status == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// 通知の許可をお願いする（はじめての起動の画面と、許可がないときの画面から）。許可されたら宛先を登録する
  static Future<bool> request() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    final ok = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (ok) await registerToken();
    return ok;
  }

  /// 通知の宛先（FCM トークン）を members に書く。許可されていなければ何もしない
  ///
  /// ここで初めて、サーバーがこの端末に通知を送れるようになる。
  static Future<void> registerToken() async {
    final uid = MemberService.uid;
    if (uid == null || !await allowed()) return;
    try {
      if (Platform.isIOS && await FirebaseMessaging.instance.getAPNSToken() == null) {
        // APNs の準備ができていない（シミュレータなど）と FCM トークンは取れない
        AppLogger.warning('APNs のトークンがまだありません', tag: 'CloudNotifications');
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(uid, token);
      _tokenSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        final id = MemberService.uid;
        if (id != null) _saveToken(id, t);
      });
    } catch (e) {
      AppLogger.warning('通知の宛先を登録できませんでした: $e', tag: 'CloudNotifications');
    }
  }

  static Future<void> _saveToken(String uid, String token) =>
      FirebaseFirestore.instance.collection(MemberService.membersCollection).doc(uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}

/// Android: アプリが動いていないときに通知のボタンが押されたとき（別の isolate で動く）
@pragma('vm:entry-point')
void onNotificationActionInBackground(NotificationResponse response) {
  if (response.actionId != CloudNotifications.seenAction && response.actionId != CloudNotifications.notSeenAction) {
    return;
  }
  void logFailure(Object e, StackTrace stackTrace) {
    // 「見えた」「見えなかった」の答えを残せなかったので、本番でも気づけるように出す
    AppLogger.error('通知のボタンの答えを残せませんでした', error: e, stackTrace: stackTrace, tag: 'CloudNotifications');
  }

  try {
    final data = jsonDecode(response.payload ?? '') as Map<String, dynamic>;
    ReportService.queueFromNotification(data, seen: response.actionId == CloudNotifications.seenAction)
        .catchError((Object e, StackTrace stackTrace) => logFailure(e, stackTrace));
  } catch (e, stackTrace) {
    logFailure(e, stackTrace);
  }
}
