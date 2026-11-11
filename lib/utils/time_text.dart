import '../l10n/l10n.dart';

/// 画面に出す時刻の書き方
class TimeText {
  TimeText._();

  /// 「14:20」
  static String clock(DateTime time) {
    final t = time.toLocal();
    return '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  }

  /// 「14:20」。きょうでなければ「10/19 14:20」
  static String clockWithDate(DateTime time, DateTime now) {
    final t = time.toLocal();
    final n = now.toLocal();
    final today = t.year == n.year && t.month == n.month && t.day == n.day;
    return today ? clock(t) : '${t.month}/${t.day} ${clock(t)}';
  }

  /// 「2026年11月11日」「Nov 11, 2026」
  static String fullDate(DateTime time) {
    final t = time.toLocal();
    return L.t.dateFull('${t.year}', '${t.month}', '${t.day}');
  }

  /// 「3分前」「2時間前」
  static String ago(DateTime time, DateTime now) {
    final minutes = now.difference(time).inMinutes;
    final l10n = L.t;
    if (minutes < 1) return l10n.agoMinutes(1);
    if (minutes < 60) return l10n.agoMinutes(minutes);
    final hours = minutes ~/ 60;
    if (hours < 24) return l10n.agoHours(hours);
    return l10n.agoDays(hours ~/ 24);
  }

  /// 夜の画面の再開時刻: 「あすの朝 5:10 ごろ」（日付が変わったあとは「朝 5:10 ごろ」）
  static String morning(DateTime sunrise, DateTime now) {
    final s = sunrise.toLocal();
    final n = now.toLocal();
    final sameDay = s.year == n.year && s.month == n.month && s.day == n.day;
    return sameDay ? L.t.morningSameDay(clock(s)) : L.t.morningNextDay(clock(s));
  }
}
