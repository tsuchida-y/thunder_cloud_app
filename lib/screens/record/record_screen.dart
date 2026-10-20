import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common/page_header.dart';
import '../../widgets/common/sky_page.dart';

/// 記録（docs/design/Record.html）
///
/// ステップ3では土台だけ。見えた入道雲の一覧と写真はステップ8で作る。
class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkyPage(
      gradient: SkyGradient.light,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: '記録'),
        ],
      ),
    );
  }
}
