import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// 角丸や寸法の決まり
class AppRadius {
  AppRadius._();

  static const double card = 22;
  static const double button = 28;
  static const double small = 14; // 「見えた」「見えなかった」、範囲の選択など
}

class AppSizes {
  AppSizes._();

  static const double buttonHeight = 56;
  static const double minTapTarget = 44; // タップできる所は44以上
  static const double pageGutter = 20; // 画面の左右の余白
}

/// アプリ全体のテーマ
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.cardSolid,
        onSurface: AppColors.text,
      ),
      // 背景は各画面のグラデーション（SkyBackground）で描く
      scaffoldBackgroundColor: Colors.transparent,
      splashFactory: InkSparkle.splashFactory,
    );
    return base.copyWith(
      textTheme: AppTextStyles.textTheme(base.textTheme).apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );
  }
}
