import 'package:flutter/material.dart';

class CloudAvatar extends StatelessWidget {
  final String name;
  final double top;
  final double left;
  final bool isCloudy; 

  const CloudAvatar({
    super.key,
    required this.name,
    required this.top,
    required this.left,
    required this.isCloudy, 
  });

  AssetImage _getImage(bool isCloudy) {
    // 条件に応じて画像を切り替える
    return isCloudy
      ? const AssetImage("image/cloud2.jpg") // 入道雲の画像
      : const AssetImage("image/bluesky.jpg"); // 晴れの画像
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      child: CircleAvatar(
        radius: 50,
        backgroundColor: Colors.white,
        backgroundImage: _getImage(isCloudy),
      ),
    );
  }
}