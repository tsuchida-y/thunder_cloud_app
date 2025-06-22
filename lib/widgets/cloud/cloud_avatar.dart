import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';

/// 入道雲または青空の画像を表示するウィジェット。
///
/// [name]: 表示する雲の名前。
/// [top]: 画像の垂直方向の位置。
/// [left]: 画像の水平方向の位置。
/// [isCloudy]: 入道雲を表示するかどうかのフラグ。
class CloudAvatar extends StatelessWidget {
  final String imageUrl;
  final String userName;
  final double radius;

  const CloudAvatar({
    super.key,
    required this.imageUrl,
    required this.userName,
    this.radius = AppConstants.defaultAvatarRadius,
  });

  /// 天候に応じた画像を取得する。
  AssetImage _getImage(bool isCloudy) {
    return isCloudy
        ? const AssetImage("image/cloud2.jpg") // 入道雲の画像
        : const AssetImage("image/bluesky.jpg"); // 青空の画像
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0.0,
      left: 0.0,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        backgroundImage: _getImage(false),
      ),
    );
  }
}
