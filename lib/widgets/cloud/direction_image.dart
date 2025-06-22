import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';

///画面右上に方向を示す画像を表示するウィジェット（レスポンシブ対応）
class DirectionImage extends StatelessWidget {
  const DirectionImage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = AppConstants.isTablet(screenSize);

    // デバイスサイズに応じたサイズ調整
    final double imageSize = isTablet ? AppConstants.directionImageSizeTablet : AppConstants.directionImageSize;
    final double topMargin = isTablet ? AppConstants.directionImageTopMarginTablet : AppConstants.directionImageTopMargin;
    final double rightMargin = isTablet ? AppConstants.directionImageRightMarginTablet : AppConstants.directionImageRightMargin;

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
