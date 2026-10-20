import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common/page_header.dart';
import '../../widgets/common/sky_page.dart';

/// 設定（docs/design/Settings.html）
///
/// ステップ3では土台だけ。中身はステップ7で作る。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkyPage(
      gradient: SkyGradient.light,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: '設定'),
        ],
      ),
    );
  }
}
