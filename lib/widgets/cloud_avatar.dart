import 'package:flutter/material.dart';

class CloudAvatar extends StatelessWidget {
  /*
  条件に応じて円形の画像を表示する関数
  円形にしたのは背景に馴染みやすくするため
  */
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
    return isCloudy
      ? const AssetImage("image/cloud2.jpg") // 入道雲の画像
      : const AssetImage("image/bluesky.jpg"); // 青空の画像
  }
  //TODO：将来的には円形ではなく、雲だけを出現するようにしたい。
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