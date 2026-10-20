import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common/app_buttons.dart';
import '../../widgets/common/page_header.dart';
import '../../widgets/common/sky_page.dart';
import '../camera_screen.dart';

/// 方角ガイド（docs/design/Finder.html, FinderAligned.html）
///
/// ステップ3では土台だけ。方位センサーで「右へ35°」を出す部分はステップ5で作る。
class FinderScreen extends StatelessWidget {
  const FinderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SkyPage(
      gradient: SkyGradient.finder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(title: '入道雲へ'),
          const Spacer(),
          PrimaryButton(
            label: '見つけた！写真を撮る',
            icon: Icons.photo_camera_outlined,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CameraScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
