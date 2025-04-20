import 'package:flutter/material.dart';

/// 入道雲または青空の画像を表示するウィジェット。
///
/// [name]: 表示する雲の名前。
/// [top]: 画像の垂直方向の位置。
/// [left]: 画像の水平方向の位置。
/// [isCloudy]: 入道雲を表示するかどうかのフラグ。
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
    this.radius = 50.0,
  });

  /// 天候に応じた画像を取得する。
  ///
  /// [isCloudy]: 入道雲を表示するかどうかのフラグ。
  /// 戻り値: 表示する画像。
  AssetImage _getImage(bool isCloudy) {
    return isCloudy
        ? const AssetImage("image/cloud2.jpg") // 入道雲の画像
        : const AssetImage("image/bluesky.jpg"); // 青空の画像
  }

  // TODO: 雲の形状を画像ではなくカスタム描画で表現する。
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        backgroundImage: _getImage(isCloudy),
      ),
    );
  }
}
