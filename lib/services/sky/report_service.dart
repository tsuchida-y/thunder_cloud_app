import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/finder_target.dart';
import '../../utils/logger.dart';
import '../member/member_service.dart';

/// 「見えた」「見えなかった」の答え（Firestore の reports）
///
/// 本人が作り、あとから書き換えない（firestore.rules）。同じ雲には1回だけ答えてもらう。
class ReportService {
  ReportService._();

  static String _answeredKey(String cloudId) => 'report_answered_$cloudId';

  /// この雲にもう答えたか
  static Future<bool> answered(String? cloudId) async {
    if (cloudId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_answeredKey(cloudId)) == true;
  }

  static Future<void> send(FinderTarget target, {required bool seen}) async {
    final uid = MemberService.uid;
    if (uid == null) return;
    try {
      if (target.cloudId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_answeredKey(target.cloudId!), true);
      }
      // 通信できないときは端末に残り、つながったときに送られる。送り終わるのは待たない
      FirebaseFirestore.instance.collection('reports').add({
        'uid': uid,
        'seen': seen,
        'cloudId': target.cloudId,
        'source': target.source.name,
        'bearingDeg': double.parse(target.bearingDeg.toStringAsFixed(1)),
        'distanceKm': double.parse(target.distanceKm.toStringAsFixed(1)),
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
