import 'package:flutter/material.dart';

/// v2.0 の色（docs/design の HTML と CLAUDE.md の「デザインの決まり」）
///
/// オレンジは使わない。
class AppColors {
  AppColors._();

  // 文字
  static const Color text = Color(0xFF14284A); // 本文
  static const Color textSub = Color(0xFF47597A); // 補足
  static const Color onSky = Colors.white; // 空の背景の上の文字

  // ボタンと強調
  static const Color primary = Color(0xFF14408F);
  static const Color accent = Color(0xFF1C4FA8);
  static const Color primaryShadow = Color(0x4D14408F); // rgba(20, 64, 143, 0.3)

  // 部品
  static const Color card = Color(0xE0FFFFFF); // 空の上のカード（白 88%）
  static const Color cardSolid = Colors.white; // 明るい背景の上のカード
  static const Color cardShadow = Color(0x0F1C4FA8); // rgba(28, 79, 168, 0.06)
  static const Color divider = Color(0xFFE6ECF2);
  static const Color dividerOnCard = Color(0x1414284A); // rgba(20, 40, 74, 0.08)
  static const Color chip = Color(0xFFE3EEFA); // 「見えた」「見えなかった」のボタン
  static const Color switchOff = Color(0xFFC9D6E3);
}

/// 画面ごとの背景のグラデーション（上から下）
enum SkyGradient {
  /// 昼の空（ホーム、許可のお願いなど）
  day(
    [Color(0xFF1C4FA8), Color(0xFF3F86D6), Color(0xFF9CCDF3), Color(0xFFEAF5FF)],
    [0.0, 0.36, 0.68, 1.0],
  ),

  /// 雲がないときのホーム（少し明るい空）
  calm(
    [Color(0xFF2A62B8), Color(0xFF5C9BDD), Color(0xFFBFE0F7), Color(0xFFF0F8FF)],
    [0.0, 0.36, 0.68, 1.0],
  ),

  /// 方角ガイド
  finder(
    [Color(0xFF1C4FA8), Color(0xFF3F86D6), Color(0xFF9CCDF3), Color(0xFFEAF5FF)],
    [0.0, 0.40, 0.72, 1.0],
  ),

  /// 夜（見張りを休んでいるとき）
  night(
    [Color(0xFF0B1630), Color(0xFF14295A), Color(0xFF24427E)],
    [0.0, 0.55, 1.0],
  ),

  /// 通信できないとき
  offline(
    [Color(0xFF4E6E96), Color(0xFF7C9BBE), Color(0xFFC4D5E6), Color(0xFFEEF3F8)],
    [0.0, 0.40, 0.72, 1.0],
  ),

  /// 設定・場所の登録・記録（明るい背景で紺の文字）
  light(
    [Color(0xFFDCEBFA), Color(0xFFF4F8FC), Color(0xFFEEF6FF)],
    [0.0, 0.40, 1.0],
  );

  const SkyGradient(this.colors, this.stops);

  final List<Color> colors;
  final List<double> stops;

  /// この背景の上で使う文字の色
  Color get foreground => this == SkyGradient.light ? AppColors.text : AppColors.onSky;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
        stops: stops,
      );
}
