import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/finder_target.dart';
import '../../utils/logger.dart';
import '../member/member_service.dart';

/// 「見えた」「見えなかった」の答え（Firestore の reports）
///
/// 本人が作り、あとから書き換えない（firestore.rules）。同じ雲には1回だけ答えてもらう。
///
/// 通知のボタンで答えたものは、アプリを開かずに受け取るので、いったん端末の「pending_reports」に残し、
/// 次にアプリを開いたときに送る（iOS は AppDelegate.swift、Android は通知のボタンの処理が残す）。
class ReportService {
  ReportService._();

  static const String pendingKey = 'pending_reports';

  static String _answeredKey(String cloudId) => 'report_answered_$cloudId';

  /// この雲にもう答えたか
  static Future<bool> answered(String? cloudId) async {
    if (cloudId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_answeredKey(cloudId)) == true;
  }

  /// ことし「見えた」と答えた日の数（設定の「記録（写真と見えた雲）」の右に出す）
  static Future<int> seenDaysThisYear() async {
    final uid = MemberService.uid;
    if (uid == null) return 0;
    final snap = await FirebaseFirestore.instance.collection('reports').where('uid', isEqualTo: uid).get();
    final year = DateTime.now().year;
    final days = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final at = data['reportedAt'];
      if (data['seen'] != true || at is! Timestamp) continue;
      final t = at.toDate();
      if (t.year == year) days.add('${t.month}-${t.day}');
    }
    return days.length;
  }

  /// 方角ガイドで答えたとき
  static Future<void> send(FinderTarget target, {required bool seen}) => _send(
        cloudId: target.cloudId,
        seen: seen,
        source: target.source.name,
        bearingDeg: target.bearingDeg,
        distanceKm: target.distanceKm,
      );

  /// 通知のボタンで答えたものを、あとで送るために残す（アプリが動いていないときにも呼ばれる）
  static Future<void> queueFromNotification(Map<String, dynamic> data, {required bool seen}) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(pendingKey) ?? [];
    pending.add(jsonEncode({
      'seen': seen,
      'cloudId': data['cloudId'] ?? '',
      'bearingDeg': '${data['bearingDeg'] ?? ''}',
      'distanceKm': '${data['distanceKm'] ?? ''}',
      'answeredAt': DateTime.now().millisecondsSinceEpoch,
    }));
    await prefs.setStringList(pendingKey, pending);
  }

  /// 残っている通知のボタンの答えを送る（ログインのあとに呼ぶ）
  static Future<void> flushPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // iOS は AppDelegate が直接書くので、読み直す
    final pending = prefs.getStringList(pendingKey) ?? [];
    if (pending.isEmpty || MemberService.uid == null) return;
    await prefs.remove(pendingKey);
    for (final raw in pending) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final cloudId = (data['cloudId'] as String?)?.isEmpty ?? true ? null : data['cloudId'] as String;
        if (cloudId != null && await answered(cloudId)) continue;
        await _send(
          cloudId: cloudId,
          seen: data['seen'] == true,
          source: 'notification_button',
          bearingDeg: double.tryParse('${data['bearingDeg']}'),
          distanceKm: double.tryParse('${data['distanceKm']}'),
          answeredAt: data['answeredAt'] is int ? DateTime.fromMillisecondsSinceEpoch(data['answeredAt'] as int) : null,
        );
      } catch (e) {
        AppLogger.warning('残っていた答えを読めませんでした: $e', tag: 'ReportService');
      }
    }
  }

  static Future<void> _send({
    required String? cloudId,
    required bool seen,
    required String source,
    double? bearingDeg,
    double? distanceKm,
    DateTime? answeredAt,
  }) async {
    final uid = MemberService.uid;
    if (uid == null) return;
    try {
      if (cloudId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_answeredKey(cloudId), true);
      }
      // 通信できないときは端末に残り、つながったときに送られる。送り終わるのは待たない
      FirebaseFirestore.instance.collection('reports').add({
        'uid': uid,
        'seen': seen,
        'cloudId': cloudId,
        'source': source,
        if (bearingDeg != null) 'bearingDeg': double.parse(bearingDeg.toStringAsFixed(1)),
        if (distanceKm != null) 'distanceKm': double.parse(distanceKm.toStringAsFixed(1)),
        if (answeredAt != null) 'answeredAt': Timestamp.fromDate(answeredAt),
        'reportedAt': FieldValue.serverTimestamp(),
      }).catchError((Object e) {
        AppLogger.warning('答えを送れませんでした: $e', tag: 'ReportService');
        return FirebaseFirestore.instance.collection('reports').doc();
      });
    } catch (e) {
      AppLogger.warning('答えを送れませんでした: $e', tag: 'ReportService');
    }
  }
}
