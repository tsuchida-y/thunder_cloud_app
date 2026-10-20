import 'package:flutter/material.dart';

import '../../navigation/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/app_buttons.dart';
import '../../widgets/common/sky_page.dart';
import '../../widgets/common/source_note.dart';

/// ホーム（docs/design/Main.html, Empty.html）
///
/// ステップ3では土台だけ。見出し・レーダー・雲の一覧と、夜・オフライン・許可がないときの状態はステップ4で作る。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SkyPage(
      gradient: SkyGradient.calm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HomeHeader(placeLabel: 'いまいる場所の空'),
          const SizedBox(height: 14),
          Text('いまは、\n静かな空です。', style: AppTextStyles.headline()),
          const Spacer(),
          PrimaryButton(
            label: '雲の方角を調べる',
            icon: Icons.explore_outlined,
            onPressed: () => AppRoutes.openFinder(context),
          ),
          const SizedBox(height: 14),
          const SourceNote(),
        ],
      ),
    );
  }
}

/// ホームの上の帯（場所の名前と、記録・設定への入り口）
class HomeHeader extends StatelessWidget {
  final String placeLabel;

  const HomeHeader({super.key, required this.placeLabel});

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color ?? AppColors.onSky;
    return Row(
      children: [
        const Icon(Icons.place_outlined, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(placeLabel, style: AppTextStyles.body(color: color).copyWith(fontSize: 14)),
        ),
        IconTapButton(
          icon: Icons.photo_outlined,
          semanticLabel: '記録',
          onPressed: () => AppRoutes.openRecord(context),
        ),
        IconTapButton(
          icon: Icons.tune_rounded,
          semanticLabel: '設定',
          onPressed: () => AppRoutes.openSettings(context),
        ),
      ],
    );
  }
}
