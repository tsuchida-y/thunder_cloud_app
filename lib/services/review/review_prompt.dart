import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/logger.dart';

/// App Store / Google Play のレビューのお願い（星を押す OS の画面）（2026-10-29）
///
/// 入道雲が「見えた」と答えたとき（アプリを気に入ってもらえていそうなとき）にだけ出す。
/// - 「見えた」が2回目以降のときから
/// - 前にお願いしてから120日以上たっているとき
/// 実際に画面を出すかは OS が決める（iPhone は1年に3回まで）。出なくても何も起きない。
class ReviewPrompt {
  ReviewPrompt._();

  static const String _seenCountKey = 'review_seen_count';
  static const String _askedAtKey = 'review_asked_at';
  static const int _minSeen = 2;
  static const Duration _interval = Duration(days: 120);

  /// 「見えた」と答えたあとに呼ぶ
  static Future<void> afterSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = (prefs.getInt(_seenCountKey) ?? 0) + 1;
      await prefs.setInt(_seenCountKey, seen);
      if (seen < _minSeen) return;

      final askedAt = prefs.getInt(_askedAtKey);
      final now = DateTime.now();
      if (askedAt != null && now.difference(DateTime.fromMillisecondsSinceEpoch(askedAt)) < _interval) return;

      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;
      await prefs.setInt(_askedAtKey, now.millisecondsSinceEpoch);
      // 「ありがとう」の表示を見てもらってから出す
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await review.requestReview();
    } catch (e) {
      AppLogger.warning('レビューのお願いを出せませんでした: $e', tag: 'ReviewPrompt');
    }
  }
}
