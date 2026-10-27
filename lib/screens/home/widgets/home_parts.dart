import 'package:flutter/material.dart';

import '../../../models/sky_cloud.dart';
import '../home_controller.dart';
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

/// ホームの上の帯: 見張っている場所のチップと設定（場所の見せ方_画面一覧.png）
///
/// 登録した場所に切り替えられ、無料は1か所、Plus は3か所までは「＋」で足せる（2026-10-27、無料でも1か所）。
/// 無料で1か所を登録したあとは「＋ 場所を追加（Plus）」で Plus の案内を開く。
class SpotHeader extends StatelessWidget {
  final HomeState state;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;

  const SpotHeader({super.key, required this.state, required this.onSelect, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final canAdd = !state.isPlus || state.placeCount < SkyRules.plusMaxPlaces;
    final hasRoom = state.placeCount < SkyRules.maxPlaces(isPlus: state.isPlus);
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final chip in state.spots) ...[
                  _SpotChipButton(
                    chip: chip,
                    selected: chip.spot.id == state.selectedSpotId,
                    onTap: () => onSelect(chip.spot.id),
                  ),
                  const SizedBox(width: 8),
                ],
                if (canAdd) hasRoom ? _AddCircle(onTap: onAdd) : _AddPlusPill(onTap: onAdd),
              ],
            ),
          ),
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

class _SpotChipButton extends StatelessWidget {
  final SpotChip chip;
  final bool selected;
  final VoidCallback onTap;

  const _SpotChipButton({required this.chip, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.accent : Colors.white;
    return Semantics(
      selected: selected,
      button: true,
      label: '${chip.spot.isCurrent ? 'いまいる場所' : chip.spot.label}${chip.hasCloud ? '、入道雲あり' : ''}',
      excludeSemantics: true,
      child: Material(
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.2),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (chip.spot.isCurrent) ...[Icon(Icons.my_location_rounded, size: 14, color: fg), const SizedBox(width: 6)],
                Text(chip.spot.label, style: AppTextStyles.body(color: fg).copyWith(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2)),
                if (chip.hasCloud) ...[const SizedBox(width: 6), Icon(Icons.cloud_rounded, size: 14, color: fg)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 「＋」（点線の丸）。まだ場所を足せるとき
class _AddCircle extends StatelessWidget {
  final VoidCallback onTap;

  const _AddCircle({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '場所を追加',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorderPainter(radius: 22),
          child: const SizedBox.square(dimension: 44, child: Icon(Icons.add_rounded, color: Colors.white, size: 22)),
        ),
      ),
    );
  }
}

/// 無料で1か所を登録したあとの「＋ 場所を追加（Plus）」（点線のまる長）
class _AddPlusPill extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPlusPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '場所を追加。Plus の機能です',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorderPainter(radius: 22),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 4),
                Text('場所を追加', style: AppTextStyles.body(color: Colors.white).copyWith(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2)),
                const SizedBox(width: 6),
                DecoratedBox(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    child: Text('Plus', style: AppTextStyles.caption(color: AppColors.primary).copyWith(fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final double radius;

  _DashedBorderPainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius((Offset.zero & size).deflate(0.75), Radius.circular(radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.85);
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (double d = 0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.radius != radius;
}

/// 見える範囲の雲の一覧（Main.html の下のカード）
///
/// いま選んでいる場所の雲のあとに、ほかの場所に出ている雲（「家 ・ 北 ・ 55km」）を並べる。押すとその場所に切り替える。
class CloudListCard extends StatelessWidget {
  final List<CloudView> clouds;
  final List<OtherSpotCloud> others;
  final ValueChanged<String>? onSelectSpot;

  /// 多すぎると下のボタンや出典が遠くなるので、いま選んでいる場所の雲は近い順にこの数まで
  static const int maxRows = 2;

  const CloudListCard({super.key, required this.clouds, this.others = const [], this.onSelectSpot});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      for (final view in clouds.take(maxRows)) _CloudRow(view: view),
      for (final other in others) _OtherSpotRow(other: other, onTap: () => onSelectSpot?.call(other.spot.id)),
    ];
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
              child: rows[i],
            ),
        ],
      ),
    );
  }
}

class _OtherSpotRow extends StatelessWidget {
  final OtherSpotCloud other;
  final VoidCallback onTap;

  const _OtherSpotRow({required this.other, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = other.spot.isCurrent ? 'いま' : other.spot.label;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(
          children: [
            const Icon(Icons.cloud_rounded, size: 16, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text('$name ・ ${other.view.directionName} ・ ${other.view.roundedKm}km', style: AppTextStyles.item()),
            ),
            Text(
              other.view.maybeVisible ? '見えるかも' : '見えています',
              style: AppTextStyles.note(color: AppColors.accent).copyWith(fontWeight: FontWeight.w700, height: 1.3),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

/// ホームのいちばん下の「見えた入道雲の記録」
class RecordLink extends StatelessWidget {
  const RecordLink({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () => AppRoutes.openRecord(context),
        icon: const Icon(Icons.event_note_outlined, size: 18, color: AppColors.accent),
        label: Text('見えた入道雲の記録', style: AppTextStyles.body(color: AppColors.accent).copyWith(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2)),
        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
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
