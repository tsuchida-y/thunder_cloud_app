import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// v2.0 の文字の決まり
///
/// 見出しは Zen Old Mincho、本文は Zen Maru Gothic、数字は Outfit。
/// フォントは初回の起動で取得して端末に残す（google_fonts の標準の動き）。
/// 取得できるまでは端末の標準フォントで表示される。
class AppTextStyles {
  AppTextStyles._();

  /// 本文のフォント（テーマ全体に使う）
  static TextTheme textTheme(TextTheme base) => GoogleFonts.zenMaruGothicTextTheme(base);

  /// ホームの大見出し（「南東の空に、入道雲。」）
  static TextStyle headline({Color color = AppColors.onSky}) => GoogleFonts.zenOldMincho(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.35,
        letterSpacing: 32 * 0.04,
        color: color,
      );

  /// 方角ガイドの「右へ」など、少し大きい見出し
  static TextStyle display({Color color = AppColors.onSky}) => GoogleFonts.zenOldMincho(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: color,
      );

  /// 画面の上の題名（「設定」「南東の入道雲へ」）
  static TextStyle pageTitle({Color color = AppColors.text}) => GoogleFonts.zenMaruGothic(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
      );

  /// 本文
  static TextStyle body({Color color = AppColors.text}) => GoogleFonts.zenMaruGothic(
        fontSize: 15,
        height: 1.7,
        color: color,
      );

  /// 一覧の項目など（太め）
  static TextStyle item({Color color = AppColors.text}) => GoogleFonts.zenMaruGothic(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: color,
      );

  /// 補足（13px）
  static TextStyle note({Color color = AppColors.textSub}) => GoogleFonts.zenMaruGothic(
        fontSize: 13,
        height: 1.6,
        color: color,
      );

  /// 小さい注記（出典など、12px）
  static TextStyle caption({Color color = AppColors.textSub}) => GoogleFonts.zenMaruGothic(
        fontSize: 12,
        color: color,
      );

  /// 設定のまとまりの見出し（「通知」「そのほか」）
  static TextStyle sectionLabel() => GoogleFonts.zenMaruGothic(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSub,
      );

  /// 大きいボタンの文字
  static TextStyle button({Color color = Colors.white, double fontSize = 17}) => GoogleFonts.zenMaruGothic(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
      );

  /// 数字（「35°」「42km」）
  static TextStyle number({double fontSize = 15, Color color = AppColors.text}) => GoogleFonts.outfit(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: color,
      );
}
