import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/lat_lng.dart';
import '../../utils/logger.dart';
import '../plus/plus_service.dart';

/// 利用者の情報（v2.0、docs/入道雲サーチ_決定事項.md の5章）
///
/// - 匿名ログインの uid で本人を確かめる。アプリを消すまで同じ uid が続く
/// - members/{uid} はアプリが書く（位置、最後に開いた時刻、見張る場所、設定、FCM トークン）
/// - member_server/{uid} はサーバーだけが書く（Plus かどうか、通知の記録）。アプリは読むだけ
/// - 位置は小数第2位（約1km）に丸めて保存する
///
/// FCM トークンはまだ書かない。サーバーはトークンのある人にだけ通知を送るので、
/// 通知の表示（ボタン付き）を作るまでは、このアプリから通知が届くことはない。
class MemberService {
  MemberService._();

  static const String membersCollection = 'members';
  static const String memberServerCollection = 'member_server';

  /// v1 で端末ごとに作っていた ID（UserIdService と同じキー）
  static const String _legacyUserIdKey = 'unique_user_id';

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static String? get uid => FirebaseAuth.instance.currentUser?.uid;

  /// 匿名ログインして、自分の members を用意する（2回目からはすぐ終わる）
  ///
  /// はじめての起動で通信できないときは例外を投げる（ホームは「通信できないとき」を出す）。
  static Future<String> ensureSignedIn() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
    if (user == null) throw StateError('匿名ログインできませんでした');

    final prefs = await SharedPreferences.getInstance();
    final createdKey = 'member_created_${user.uid}';
    if (prefs.getBool(createdKey) != true) {
      await _db.collection(membersCollection).doc(user.uid).set({
        'createdAt': FieldValue.serverTimestamp(),
        'platform': Platform.isIOS ? 'ios' : 'android',
        'settings': {'quietHours': MemberSettings.defaultQuietHours.toMap()},
        // v1 の利用者が v2.0 に上げたときの手がかり。新しく入れた人にはない
        if (prefs.getString(_legacyUserIdKey) != null) 'legacyUserId': prefs.getString(_legacyUserIdKey),
      }, SetOptions(merge: true));
      await prefs.setBool(createdKey, true);
      AppLogger.info('members を作りました', tag: 'MemberService');
    }
    return user.uid;
  }

  /// アプリを開いたことと、いまいる場所を残す
  ///
  /// サーバーは「開いて10分以内の人には通知しない」ために lastOpenedAt を見る。
  /// [clearLocation] が true（位置情報がオフ）のときは、前の位置を消す。残っていると、サーバーが
  /// 登録した場所の代わりに古い位置を見張り続けてしまうため（watchPointsOf は位置があればそれを使う）。
  /// 通信できないときは端末に残り、つながったときに送られる。送り終わるのは待たない。
  static void recordOpened({LatLng? location, bool clearLocation = false}) {
    final id = uid;
    if (id == null) return;
    _db.collection(membersCollection).doc(id).set({
      'lastOpenedAt': FieldValue.serverTimestamp(),
      if (location != null) ...{
        'location': {
          'latitude': _round2(location.latitude),
          'longitude': _round2(location.longitude),
        },
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      } else if (clearLocation) ...{
        'location': FieldValue.delete(),
        'locationUpdatedAt': FieldValue.delete(),
      },
    }, SetOptions(merge: true)).catchError((Object e) {
      AppLogger.warning('members の更新に失敗: $e', tag: 'MemberService');
    });
  }

  /// まだ一度も「通知しない時間」を決めていない人に、初めの値（22:00〜6:00）を入れる
  ///
  /// 「なし」を選んだ人は quietHours が null で入っているので、上書きしない。
  static void ensureDefaultSettings(Map<String, dynamic>? member) {
    if (member == null) return;
    final settings = member['settings'];
    if (settings is Map && settings.containsKey('quietHours')) return;
    updateSettings({'quietHours': MemberSettings.defaultQuietHours.toMap()}).catchError((Object e) {
      AppLogger.warning('通知しない時間の初めの値を書けませんでした: $e', tag: 'MemberService');
    });
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchMember(String id) =>
      _db.collection(membersCollection).doc(id).snapshots();

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchServer(String id) =>
      _db.collection(memberServerCollection).doc(id).snapshots();

  /// Plus かどうか（期限つき。期限がなければ Plus のまま）。サーバーの isPlusActive と同じ
  ///
  /// 買った直後や復元した直後は、サーバーに届くまで少しかかるので、ストア（RevenueCat）で Plus なら Plus とする。
  static bool isPlusActive(Map<String, dynamic>? server, DateTime now) {
    if (PlusService.activeInStore.value) return true;
    if (server == null || server['isPlus'] != true) return false;
    final expiresAt = server['plusExpiresAt'];
    return expiresAt is! Timestamp || expiresAt.toDate().isAfter(now);
  }

  /// 登録した場所（設定の「見張る場所」）
  static List<WatchPlace> placesOf(Map<String, dynamic>? member) {
    final places = member?['places'];
    if (places is! List) return const [];
    return places
        .whereType<Map>()
        .where((p) => p['latitude'] is num && p['longitude'] is num)
        .map((p) => WatchPlace(
              label: (p['label'] as String?) ?? '登録した場所',
              name: p['name'] as String?,
              location: LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble()),
            ))
        .toList();
  }

  /// 登録した場所をまとめて書き換える（サーバーの watchPointsOf が読む。無料は1か所目だけ、Plus は3か所まで）
  static Future<void> savePlaces(List<WatchPlace> places) async {
    final id = uid;
    if (id == null) return;
    await _db.collection(membersCollection).doc(id).set({
      'places': places.map((p) => p.toMap()).toList(),
    }, SetOptions(merge: true));
  }

  /// 設定（settings）の一部を書き換える。サーバーは notifyAppeared, rangeKm, quietHours を読む
  static Future<void> updateSettings(Map<String, dynamic> fields) async {
    final id = uid;
    if (id == null) return;
    await _db.collection(membersCollection).doc(id).set({'settings': fields}, SetOptions(merge: true));
  }

  /// 端末に残しておく印（許可のお願いと使い方を見終わったこと。welcome_screen.dart と intro_screen.dart のキー）。
  /// 削除のあとに、また最初の画面から見せないため
  static const Set<String> _keepKeys = {'welcome_done', 'intro_done'};

  /// 自分のデータを、サーバーから削除する（設定の「データを削除」）
  ///
  /// サーバーの deleteMyData が、members・member_server・自分の reports と匿名ログインのアカウントを消す。
  /// そのあと端末の保存も消して（_keepKeys 以外）、新しい匿名ログインで始め直す。Plus の購入はストアに残る。
  /// 失敗したときは例外を投げる（このときサーバーのデータは消えていないことがある）。
  static Future<void> deleteMyData() async {
    await FirebaseFunctions.instanceFor(region: 'asia-northeast1').httpsCallable('deleteMyData').call<void>();
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (!_keepKeys.contains(key)) await prefs.remove(key);
    }
    final newUid = await ensureSignedIn();
    await PlusService.logIn(newUid);
  }

  static double _round2(double value) => (value * 100).roundToDouble() / 100;
}

/// 登録した場所
class WatchPlace {
  /// 利用者がつけた名前（「家」「学校」）
  final String label;

  /// 地名（「盛岡市」）。分からなければ null
  final String? name;
  final LatLng location;

  const WatchPlace({required this.label, required this.location, this.name});

  /// 位置は「いまいる場所」と同じく小数第2位（約1km）に丸めて残す
  Map<String, dynamic> toMap() => {
        'label': label,
        if (name != null) 'name': name,
        'latitude': MemberService._round2(location.latitude),
        'longitude': MemberService._round2(location.longitude),
      };

  WatchPlace copyWith({String? label}) => WatchPlace(label: label ?? this.label, name: name, location: location);
}

/// 通知しない時間（日本時間の 0:00 からの分。終わりが始まりより前なら日をまたぐ）
class QuietHours {
  final int startMinutes;
  final int endMinutes;

  const QuietHours(this.startMinutes, this.endMinutes);

  static QuietHours? fromMap(Object? value) {
    if (value is! Map || value['startMinutes'] is! num || value['endMinutes'] is! num) return null;
    return QuietHours((value['startMinutes'] as num).toInt(), (value['endMinutes'] as num).toInt());
  }

  Map<String, dynamic> toMap() => {'startMinutes': startMinutes, 'endMinutes': endMinutes};

  static String clock(int minutes) => '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

  /// 「22:00〜6:00」
  String get label => '${clock(startMinutes)}〜${clock(endMinutes)}';
}

/// 設定画面で使う、members.settings の中身
class MemberSettings {
  /// 通知しない時間の初めの値（2026-10-22、tsuchida さんの希望で初めからオン。夜は別に自動で休む）
  static const QuietHours defaultQuietHours = QuietHours(22 * 60, 6 * 60);

  final bool notifyAppeared;
  final num? rangeKm;
  final QuietHours? quietHours;

  const MemberSettings({this.notifyAppeared = true, this.rangeKm, this.quietHours});

  factory MemberSettings.fromMember(Map<String, dynamic>? member) {
    final settings = member?['settings'];
    if (settings is! Map) return const MemberSettings();
    return MemberSettings(
      notifyAppeared: settings['notifyAppeared'] != false,
      rangeKm: settings['rangeKm'] as num?,
      quietHours: QuietHours.fromMap(settings['quietHours']),
    );
  }
}
