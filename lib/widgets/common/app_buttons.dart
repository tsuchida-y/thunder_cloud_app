import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';

/// いちばん大事な操作のボタン（高さ56・角丸28・紺）
///
/// 例: 「雲の方角を調べる」「許可してはじめる」「写真を撮る」
/// [compact] が true のときはカードの中の小さいボタン（高さ44・影なし、例: 「設定アプリを開く」）。
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool compact;

  const PrimaryButton({super.key, required this.label, this.icon, this.onPressed, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final height = compact ? AppSizes.minTapTarget : AppSizes.buttonHeight;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: compact
            ? null
            : const [BoxShadow(color: AppColors.primaryShadow, blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: SizedBox(
        height: height,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(height / 2)),
            textStyle: AppTextStyles.button(fontSize: compact ? 15 : 17),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 枠だけのボタン（例: 方位の調整の「このまま続ける」、許可がないときの「通知をオンにする」）
class OutlinePillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;

  const OutlinePillButton({super.key, required this.label, this.onPressed, this.height = 52});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(height / 2)),
          textStyle: AppTextStyles.button(color: AppColors.primary, fontSize: 15),
        ),
        child: Text(label),
      ),
    );
  }
}

/// 小さな選択のボタン（例: 「見えた」「見えなかった」）
class ChoiceButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const ChoiceButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.minTapTarget,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.chip,
          foregroundColor: AppColors.text,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.small)),
          textStyle: AppTextStyles.button(color: AppColors.text, fontSize: 15),
        ),
        child: Text(label),
      ),
    );
  }
}

/// 文字だけの控えめなボタン（例: 「あとで設定する」「いまのままにする」）
class TextLinkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  const TextLinkButton({super.key, required this.label, this.onPressed, this.color = AppColors.text});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
        textStyle: AppTextStyles.body(color: color).copyWith(fontSize: 14, height: 1.2),
      ),
      child: Text(label),
    );
  }
}

/// 44×44 の、アイコンだけのボタン（例: ホーム右上の「記録」「設定」、戻る）
class IconTapButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  const IconTapButton({super.key, required this.icon, required this.semanticLabel, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: semanticLabel,
      icon: Icon(icon, size: 22, semanticLabel: semanticLabel),
      constraints: const BoxConstraints.tightFor(width: AppSizes.minTapTarget, height: AppSizes.minTapTarget),
      padding: EdgeInsets.zero,
    );
  }
}
