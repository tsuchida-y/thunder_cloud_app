import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common/page_header.dart';
import '../../widgets/common/sky_page.dart';

/// Plus のご案内（docs/design/Plus.html）
///
/// ステップ7では土台だけ。値段・無料体験・購入はステップ9（RevenueCat）で作る。
class PlusScreen extends StatelessWidget {
  const PlusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkyPage(
      gradient: SkyGradient.day,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: 'Plus'),
        ],
      ),
    );
  }
}
