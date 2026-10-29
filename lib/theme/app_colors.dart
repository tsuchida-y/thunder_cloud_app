import 'package:flutter/material.dart';

/// v2.0 の色（docs/design の HTML と CLAUDE.md の「デザインの決まり」）
///
/// オレンジも使ってよい（2026-10-27 tsuchida さん）。いまは朝と夕方の空の色に使っている。
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

/// 読み込み画面の色（「雲がもくもく湧く」読み込み、2026-10-29）
///
/// 画面に直接書かず、テーマ（AppTheme.light の extensions）から取る。アプリの色に合わせ、
/// 雲がないときのホームと同じ空の背景に、白い雲と白い文字を置く。
/// アプリはダークモードで色を変えていないので、読み込み画面も変えない。
@immutable
class LoadingColors extends ThemeExtension<LoadingColors> {
  final SkyGradient background;
  final Color cloud;

  /// 雲のふちと丸のすき間に見える影の色
  final Color shade;
  final Color text;

  const LoadingColors({required this.background, required this.cloud, required this.shade, required this.text});

  static const LoadingColors standard = LoadingColors(
    background: SkyGradient.calm,
    cloud: Colors.white,
    shade: Color(0xFFC7DDF5),
    text: AppColors.onSky,
  );

  /// テーマに登録した色。登録がなければ standard
  static LoadingColors of(BuildContext context) => Theme.of(context).extension<LoadingColors>() ?? standard;

  @override
  LoadingColors copyWith({SkyGradient? background, Color? cloud, Color? shade, Color? text}) => LoadingColors(
        background: background ?? this.background,
        cloud: cloud ?? this.cloud,
        shade: shade ?? this.shade,
        text: text ?? this.text,
      );

  @override
  LoadingColors lerp(ThemeExtension<LoadingColors>? other, double t) {
    if (other is! LoadingColors) return this;
    return LoadingColors(
      background: t < 0.5 ? background : other.background,
      cloud: Color.lerp(cloud, other.cloud, t)!,
      shade: Color.lerp(shade, other.shade, t)!,
      text: Color.lerp(text, other.text, t)!,
    );
  }
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

  /// 朝や夕方（太陽が低いとき）の、雲があるときのホーム。上は青、下へ藤色からオレンジの夕焼けの色にする
  dayLow(
    [Color(0xFF22479A), Color(0xFF5D72BE), Color(0xFFE7A98F), Color(0xFFFFE4C8)],
    [0.0, 0.36, 0.68, 1.0],
  ),

  /// 朝や夕方（太陽が低いとき）の、雲がないときのホーム
  calmLow(
    [Color(0xFF2B4F9C), Color(0xFF6A7FC6), Color(0xFFF0B79A), Color(0xFFFFEBD4)],
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

  /// Plus のご案内（下の方まで明るい）
  plus(
    [Color(0xFF1C4FA8), Color(0xFF3F86D6), Color(0xFF9CCDF3), Color(0xFFEAF5FF)],
    [0.0, 0.30, 0.56, 0.78],
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
