import 'package:flutter/material.dart';

import '../../../models/sky_cloud.dart';
import '../../../services/location/current_place.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/time_text.dart';
import '../../../widgets/common/app_buttons.dart';
import '../../../widgets/common/source_note.dart';

/// 全国で見えている入道雲の一覧（ホームの「いちばん近い入道雲」のカードを押すと下から出る。2026-10-29）
///
/// 見張っている場所から近い順に、場所の目安（「秋田市のあたり」「太平洋の上」「秋田県の沖」）と、方角・距離を出す。
/// 見える範囲の外の雲なので、方角ガイドは開かない（押せる行にはしない）。
class NationwideSheet extends StatelessWidget {
  final List<CloudView> views;

  /// 多すぎると地名の検索に時間がかかるので、近い順にこの数まで
  static const int maxRows = 30;

  const NationwideSheet({super.key, required this.views});

  static Future<void> show(BuildContext context, List<CloudView> views) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFFF4F8FC),
        barrierColor: const Color(0x730B1630),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => NationwideSheet(views: views),
      );

  @override
  Widget build(BuildContext context) {
    final shown = views.take(maxRows).toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: AppColors.switchOff, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '全国で見えている入道雲（${views.length}か所）',
                      style: AppTextStyles.pageTitle().copyWith(fontSize: 18),
                    ),
                  ),
                  IconTapButton(
                    icon: Icons.close_rounded,
                    semanticLabel: '閉じる',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text('見張っている場所から近い順です。', style: AppTextStyles.note()),
              const SizedBox(height: 12),
              Flexible(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: shown.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.dividerOnCard),
                    itemBuilder: (_, i) => _NationwideRow(view: shown[i]),
                  ),
                ),
              ),
              if (views.length > maxRows) ...[
                const SizedBox(height: 8),
                Text('ほか${views.length - maxRows}か所', style: AppTextStyles.note(), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 10),
              Text(
                '場所は、雲の真ん中の位置のおおよその目安です。',
                style: AppTextStyles.caption(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const SourceNote(),
            ],
          ),
        ),
      ),
    );
  }
}

class _NationwideRow extends StatelessWidget {
  final CloudView view;

  const _NationwideRow({required this.view});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<String>(
                  future: CurrentPlace.areaName(view.cloud.center),
                  builder: (_, snap) => Text(snap.data ?? '場所を調べています', style: AppTextStyles.item()),
                ),
                const SizedBox(height: 2),
                Text('${TimeText.clock(view.cloud.firstSeenAt)}から見えています', style: AppTextStyles.caption()),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${view.directionName} ${view.roundedKm}km',
            style: AppTextStyles.item(color: AppColors.accent).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
