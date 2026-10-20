import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// グラデーションの背景を敷いた画面の土台
///
/// 小さいスマホ（iPhone SE など）で中身があふれてもボタンがつぶれないよう、
/// [scrollable] が true（初期値）のときは画面全体をスクロールできるようにする。
class SkyPage extends StatelessWidget {
  final SkyGradient gradient;
  final Widget child;
  final bool scrollable;
  final EdgeInsetsGeometry padding;

  const SkyPage({
    super.key,
    required this.child,
    this.gradient = SkyGradient.day,
    this.scrollable = true,
    this.padding = const EdgeInsets.fromLTRB(AppSizes.pageGutter, 8, AppSizes.pageGutter, 20),
  });

  @override
  Widget build(BuildContext context) {
    final isLight = gradient == SkyGradient.light;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: gradient.gradient),
          child: SafeArea(
            child: DefaultTextStyle.merge(
              style: TextStyle(color: gradient.foreground),
              child: IconTheme.merge(
                data: IconThemeData(color: gradient.foreground),
                child: scrollable
                    ? CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: padding,
                            // 中身が少ないときは画面いっぱいに広げ、Spacer で下寄せの部品（ボタンなど）を下に置けるようにする
                            sliver: SliverFillRemaining(hasScrollBody: false, child: child),
                          ),
                        ],
                      )
                    : Padding(padding: padding, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
