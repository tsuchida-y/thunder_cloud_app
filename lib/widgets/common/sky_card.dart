import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// 角丸22のカード
///
/// 空の背景の上では白88%（[solid] が false）、明るい背景の上では白に薄い影（[solid] が true）。
class SkyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool solid;

  const SkyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: solid ? AppColors.cardSolid : AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: solid
            ? const [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: Offset(0, 2))]
            : null,
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: AppColors.text),
        child: IconTheme.merge(
          data: const IconThemeData(color: AppColors.text),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
