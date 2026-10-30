import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'cloud_loading.dart';

/// 読み込み画面（2026-10-29）
///
/// 背景の真ん中に一辺64の雲を1つだけ置き、すぐ下に小さく「読み込み中」と出す。色はテーマ（[LoadingColors]）から取る。
/// 起動したあと最初のデータを待つあいだと、「もう一度読み込む」で読み込み直しているあいだに出す。
/// データが届いたら、呼んだ側がすぐに次の画面に切り替える（アニメーションを見せるために待たせない）。
/// 読み上げは「読み込んでいます」だけにする（雲の絵と、見えている「読み込み中」の文字は読み上げない）。
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  /// 読み上げる文
  static const String semanticLabel = '読み込んでいます';

  @override
  Widget build(BuildContext context) {
    final colors = LoadingColors.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: colors.background == SkyGradient.light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: colors.background.gradient),
          child: Center(
            child: Semantics(
              label: semanticLabel,
              liveRegion: true,
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CloudLoading(size: 64),
                    const SizedBox(height: 6),
                    Text(
                      '読み込み中',
                      style: AppTextStyles.caption(color: colors.text).copyWith(fontSize: 12, letterSpacing: 12 * 0.08),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
