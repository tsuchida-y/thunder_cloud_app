import 'package:flutter/material.dart';

///画面右上に方向を示す画像を表示するウィジェット（レスポンシブ対応）
class DirectionImage extends StatelessWidget {
  const DirectionImage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    // デバイスサイズに応じたサイズ調整
    final double imageSize = isTablet ? 100.0 : 70.0;
    final double topMargin = isTablet ? 20.0 : 10.0;
    final double rightMargin = isTablet ? 30.0 : 20.0;

    return Positioned(
      top: topMargin,
      right: rightMargin,
      width: imageSize,
      height: imageSize,
      child: Image.asset(
        "image/direction.png",
        fit: BoxFit.contain,
      ),
    );
  }
}
