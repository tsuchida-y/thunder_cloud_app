import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';

/// 入道雲または青空の画像を表示するウィジェット。
///
/// [name]: 表示する雲の名前（地域名）。
/// [top]: 画像の垂直方向の位置。
/// [left]: 画像の水平方向の位置。
/// [isCloudy]: 入道雲を表示するかどうかのフラグ。
/// [radius]: アバターの半径。
class CloudAvatar extends StatelessWidget {
  final String name;
  final double top;
  final double left;
  final bool isCloudy;
  final double radius;

  const CloudAvatar({
    super.key,
    required this.name,
    required this.top,
    required this.left,
    required this.isCloudy,
    this.radius = AppConstants.defaultAvatarRadius,
  });

  /// 天候に応じた画像を取得する。
  AssetImage _getImage() {
    return isCloudy
        ? const AssetImage("image/cloud2.jpg") // 入道雲の画像
        : const AssetImage("image/bluesky.jpg"); // 青空の画像
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: Colors.white,
            backgroundImage: _getImage(),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCloudy ? Colors.red : Colors.blue,
                  width: AppConstants.avatarBorderWidth,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.smallPadding),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.smallPadding,
              vertical: AppConstants.extraSmallPadding,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: AppConstants.overlayOpacity),
              borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
            ),
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppConstants.smallFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
