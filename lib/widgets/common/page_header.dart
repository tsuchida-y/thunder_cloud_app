import 'package:flutter/material.dart';

import '../../theme/app_text_styles.dart';
import 'app_buttons.dart';

/// 戻るボタンと題名の帯（設定・記録・方角ガイドなどの上）
class PageHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const PageHeader({super.key, required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color;
    return Row(
      children: [
        // デザインでは戻るボタンを左に10寄せて、題名の頭を余白の線にそろえている
        Transform.translate(
          offset: const Offset(-10, 0),
          child: IconTapButton(
            icon: Icons.chevron_left_rounded,
            semanticLabel: 'ホームに戻る',
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
        ),
        Expanded(
          child: Transform.translate(
            offset: const Offset(-6, 0),
            child: Text(
              title,
              style: AppTextStyles.pageTitle(color: color ?? Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
