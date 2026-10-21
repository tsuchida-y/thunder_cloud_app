import 'package:flutter/material.dart';

import '../../../models/sky_cloud.dart';
import '../../../navigation/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/time_text.dart';
import '../../../widgets/common/app_buttons.dart';
import '../../../widgets/common/sky_card.dart';

/// ホームの上の帯（場所の名前と、記録・設定への入り口）
class HomeHeader extends StatelessWidget {
  final String label;
  final bool showPin;
  final bool showRecord;
  final bool showSettings;

  const HomeHeader({
    super.key,
    required this.label,
    this.showPin = true,
    this.showRecord = true,
    this.showSettings = true,
  });

  /// 「滝沢市の空」。名前が分からなければ「いまいる場所の空」
  static String skyOf(String? placeName) => '${placeName ?? 'いまいる場所'}の空';

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color ?? AppColors.onSky;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          if (showPin) ...[const Icon(Icons.place_outlined, size: 16), const SizedBox(width: 6)],
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body(color: color).copyWith(fontSize: 14, height: 1.3),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showRecord)
            IconTapButton(
              icon: Icons.event_note_outlined,
              semanticLabel: '記録',
              onPressed: () => AppRoutes.openRecord(context),
            ),
          if (showSettings)
            IconTapButton(
              icon: Icons.tune_rounded,
              semanticLabel: '設定',
              onPressed: () => AppRoutes.openSettings(context),
            ),
        ],
      ),
    );
  }
}

/// 見出しの上の小さな札（「いま、見えています」「空を見守っています」など）
class StatusBadge extends StatelessWidget {
  final String text;
  final Color foreground;
  final Color background;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.text,
    required this.foreground,
    required this.background,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 12, color: foreground), const SizedBox(width: 6)],
              Text(
                text,
                style: AppTextStyles.caption(color: foreground).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 札・見出し・説明のまとまり
class HomeHeadline extends StatelessWidget {
  final Widget? badge;
  final String title;
  final String body;
  final double titleSize;

  const HomeHeadline({super.key, this.badge, required this.title, required this.body, this.titleSize = 30});

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color ?? AppColors.onSky;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (badge != null) ...[badge!, const SizedBox(height: 8)],
        Semantics(header: true, child: Text(title, style: AppTextStyles.headline(color: color, fontSize: titleSize))),
        const SizedBox(height: 8),
        Text(body, style: AppTextStyles.body(color: color)),
      ],
    );
  }
}

/// 見える範囲の雲の一覧（Main.html の下のカード）
class CloudListCard extends StatelessWidget {
  final List<CloudView> clouds;

  /// 多すぎると下のボタンや出典が遠くなるので、近い順にこの数まで
  static const int maxRows = 3;

  const CloudListCard({super.key, required this.clouds});

  @override
  Widget build(BuildContext context) {
    final rows = clouds.take(maxRows).toList();
    return SkyCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i < rows.length - 1
                    ? const Border(bottom: BorderSide(color: AppColors.dividerOnCard))
                    : null,
              ),
              child: _CloudRow(view: rows[i]),
            ),
        ],
      ),
    );
  }
}

class _CloudRow extends StatelessWidget {
  final CloudView view;

  const _CloudRow({required this.view});

  @override
  Widget build(BuildContext context) {
    final since = TimeText.clock(view.cloud.firstSeenAt);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: [
          view.maybeVisible ? const _DashedDot() : const _FilledDot(),
          const SizedBox(width: 12),
          Expanded(child: Text('${view.directionName} ・ ${view.roundedKm}km', style: AppTextStyles.item())),
          const SizedBox(width: 8),
          view.maybeVisible
              ? Text('$sinceから ・ 見えるかも', style: AppTextStyles.note().copyWith(height: 1.3))
              : Text(
                  '$sinceから見えています',
                  style: AppTextStyles.note(color: AppColors.accent).copyWith(fontWeight: FontWeight.w700, height: 1.3),
                ),
        ],
      ),
    );
  }
}

class _FilledDot extends StatelessWidget {
  const _FilledDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.2), spreadRadius: 4)],
      ),
    );
  }
}

class _DashedDot extends StatelessWidget {
  const _DashedDot();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size.square(12), painter: _DashedDotPainter());
  }
}

class _DashedDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.textSub;
    final rect = Offset.zero & size;
    const count = 6;
    const step = 2 * 3.141592653589793 / count;
    for (var i = 0; i < count; i++) {
      canvas.drawArc(rect.deflate(1), i * step, step * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedDotPainter oldDelegate) => false;
}
