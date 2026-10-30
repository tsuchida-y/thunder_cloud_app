import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';

/// 設定のまとまりの見出し（「通知」「そのほか」）
class SettingsSectionLabel extends StatelessWidget {
  final String text;

  const SettingsSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
      child: Semantics(header: true, child: Text(text, style: AppTextStyles.sectionLabel())),
    );
  }
}

/// 明るい背景の上の白いカード。中の行は線で区切る（Settings.html, Places.html）
class SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const SettingsCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardSolid,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: i < children.length - 1
                        ? const Border(bottom: BorderSide(color: AppColors.divider))
                        : null,
                  ),
                  child: children[i],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 設定の1行（題名・補足・右側）
class SettingsRow extends StatelessWidget {
  final Widget title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsRow({super.key, required this.title, this.subtitle, this.trailing, this.onTap});

  /// 文字だけの題名
  SettingsRow.text(String title, {Key? key, String? subtitle, Widget? trailing, VoidCallback? onTap})
      : this(
          key: key,
          title: Text(title, style: AppTextStyles.item()),
          subtitle: subtitle,
          trailing: trailing,
          onTap: onTap,
        );

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppTextStyles.note().copyWith(height: 1.4)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// 右側の値（「なし」「いまいる場所」）
class SettingsValue extends StatelessWidget {
  final String text;

  const SettingsValue(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.body(color: AppColors.textSub).copyWith(fontSize: 14, height: 1.3));
  }
}

/// 「Plus」の小さな札
class PlusBadge extends StatelessWidget {
  const PlusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text('Plus', style: AppTextStyles.caption(color: Colors.white).copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// オン・オフのスイッチ（52×32、オンは紺、オフは灰色）
class SkySwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  const SkySwitch({super.key, required this.value, required this.onChanged, required this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      toggled: value,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: SizedBox(
          width: 52,
          height: AppSizes.minTapTarget,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 52,
              height: 32,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value ? AppColors.primary : AppColors.switchOff,
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
