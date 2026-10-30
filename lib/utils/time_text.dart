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

  /// 「3分前」「2時間前」
  static String ago(DateTime time, DateTime now) {
    final minutes = now.difference(time).inMinutes;
    if (minutes < 1) return '1分前';
    if (minutes < 60) return '$minutes分前';
    final hours = minutes ~/ 60;
    if (hours < 24) return '$hours時間前';
    return '${hours ~/ 24}日前';
  }

  /// 夜の画面の再開時刻: 「あすの朝 5:10 ごろ」（日付が変わったあとは「朝 5:10 ごろ」）
  static String morning(DateTime sunrise, DateTime now) {
    final s = sunrise.toLocal();
    final n = now.toLocal();
    final sameDay = s.year == n.year && s.month == n.month && s.day == n.day;
    return '${sameDay ? '朝' : 'あすの朝'} ${clock(s)} ごろ';
  }
}
