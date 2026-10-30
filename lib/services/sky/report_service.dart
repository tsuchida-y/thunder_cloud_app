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

  /// ことし「見えた」と答えた日の数（設定の「記録（見えた雲）」の右と、記録の画面に出す）
  static Future<int> seenDaysThisYear() async => countDays(await seenThisYear());

  static int countDays(List<SeenRecord> records) =>
      records.map((r) => '${r.seenAt.month}-${r.seenAt.day}').toSet().length;

  /// ことし「見えた」と答えた入道雲（新しい順、同じ雲は1つにまとめる）
  ///
  /// 雲が見えていた時間は、サーバーが雲を消す前に reports に写す（cloudFirstSeenAt, cloudLastSeenAt）。
  /// まだ写していない新しい記録は、残っている雲（clouds）から読む。
  static Future<List<SeenRecord>> seenThisYear() async {
    final uid = MemberService.uid;
    if (uid == null) return const [];
    final db = FirebaseFirestore.instance;
    final snap = await db.collection('reports').where('uid', isEqualTo: uid).get();
    final year = DateTime.now().year;

    final byCloud = <String, SeenRecord>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final at = data['answeredAt'] ?? data['reportedAt'];
      final bearing = data['bearingDeg'];
      final distance = data['distanceKm'];
      if (data['seen'] != true || at is! Timestamp || bearing is! num || distance is! num) continue;
      final seenAt = at.toDate();
      if (seenAt.year != year) continue;
      final key = (data['cloudId'] as String?) ?? doc.id;
      final record = SeenRecord(
        cloudId: data['cloudId'] as String?,
        seenAt: seenAt,
        bearingDeg: bearing.toDouble(),
        distanceKm: distance.toDouble(),
        from: (data['cloudFirstSeenAt'] as Timestamp?)?.toDate(),
        to: (data['cloudLastSeenAt'] as Timestamp?)?.toDate(),
      );
      final existing = byCloud[key];
      if (existing == null || record.seenAt.isBefore(existing.seenAt)) byCloud[key] = record;
    }

    final records = byCloud.values.toList();
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      if (r.from != null || r.cloudId == null) continue;
      try {
        final cloud = (await db.collection('clouds').doc(r.cloudId).get()).data();
        final first = cloud?['firstSeenAt'];
        final last = cloud?['lastSeenAt'];
        if (first is Timestamp && last is Timestamp) {
          records[i] = r.withTimes(first.toDate(), last.toDate());
        }
      } catch (_) {
        // 雲がもうなければ、答えた時刻だけを出す
      }
    }
    records.sort((a, b) => b.seenAt.compareTo(a.seenAt));
    return records;
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

/// 「見えた」と答えた入道雲（記録の画面の1行）
class SeenRecord {
  final String? cloudId;

  /// 「見えた」と答えた時刻
  final DateTime seenAt;
  final double bearingDeg;
  final double distanceKm;

  /// 雲が見えていた時間（分からなければ null）
  final DateTime? from;
  final DateTime? to;

  const SeenRecord({
    required this.cloudId,
    required this.seenAt,
    required this.bearingDeg,
    required this.distanceKm,
    this.from,
    this.to,
  });

  SeenRecord withTimes(DateTime from, DateTime to) => SeenRecord(
        cloudId: cloudId,
        seenAt: seenAt,
        bearingDeg: bearingDeg,
        distanceKm: distanceKm,
        from: from,
        to: to,
      );
}
