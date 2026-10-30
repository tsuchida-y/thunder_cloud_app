import 'package:flutter/material.dart';

import '../../theme/app_text_styles.dart';

/// 画面の下に出す出典の一行
///
/// 画面では「出典：気象庁」と短く書く。詳しい書き方（「出典：気象庁ホームページ（加工して作成）」）は
/// 設定から開くデータの出典ページに置く（CLAUDE.md の出典表記）。
class SourceNote extends StatelessWidget {
  /// 出典の前に添える文（例: 「3分前に空を見ました」）
  final String? prefix;

  const SourceNote({super.key, this.prefix});

  static const String source = '出典：気象庁';

  @override
  Widget build(BuildContext context) {
    return Text(
      prefix == null ? source : '$prefix ・ $source',
      textAlign: TextAlign.center,
      style: AppTextStyles.caption(),
    );
  }
}
