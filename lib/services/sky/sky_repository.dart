import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/sky_cloud.dart';

/// サーバーが5分ごとに作る雲の一覧を読む
///
/// 気象庁へはサーバーだけがアクセスする（CLAUDE.md）。アプリは Firestore の clouds と
/// system/jma_nowcast を読むだけ。
class SkyRepository {
  SkyRepository._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// いま続いている雲。通信できないかを知るため、端末のキャッシュから来たかも一緒に流す
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchActiveClouds() => _db
      .collection('clouds')
      .where('status', isEqualTo: 'active')
      .snapshots(includeMetadataChanges: true);

  /// 最後に気象庁のデータで雲の一覧を作った時刻（「3分前に空を見ました」）
  static Stream<DateTime?> watchObservedAt() =>
      _db.doc('system/jma_nowcast').snapshots().map((doc) {
        final observedAt = doc.data()?['observedAt'];
        return observedAt is Timestamp ? observedAt.toDate() : null;
      });

  /// ホームの「いまの空」用のアメダスの最新の観測（サーバーが10分ごとに置く）
  static Stream<Map<String, dynamic>?> watchAmedasLatest() =>
      _db.doc('system/amedas_latest').snapshots().map((doc) => doc.data());

  /// きょう（端末の日付）見えていた雲。夜の画面の「きょう見えた入道雲」に使う
  static Future<List<SkyCloud>> cloudsSeenSince(DateTime since) async {
    final snap = await _db
        .collection('clouds')
        .where('lastSeenAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get();
    return snap.docs.map(SkyCloud.fromDoc).whereType<SkyCloud>().toList();
  }
}

/// 最後に見た空（通信できないときに「最後に見た空（15:21）」として出す）
class LastSky {
  final DateTime checkedAt;
  final String directionName;
  final int distanceKm;

  const LastSky({required this.checkedAt, required this.directionName, required this.distanceKm});

  static const String _key = 'last_sky';

  /// 雲が見えていたときはその雲を、見えていなかったときは null を残す
  static Future<void> save(LastSky? sky) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (sky == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, jsonEncode({
          'checkedAt': sky.checkedAt.millisecondsSinceEpoch,
          'directionName': sky.directionName,
          'distanceKm': sky.distanceKm,
        }));
      }
    } catch (_) {
      // 残せなくても、ホームの表示には困らない
    }
  }

  static Future<LastSky?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return LastSky(
        checkedAt: DateTime.fromMillisecondsSinceEpoch(data['checkedAt'] as int),
        directionName: data['directionName'] as String,
        distanceKm: data['distanceKm'] as int,
      );
    } catch (_) {
      return null;
    }
  }
}
