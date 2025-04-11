import 'package:flutter/material.dart';

class CloudAvatar extends StatelessWidget {
  final String name;
  final double top;
  final double left;

  const CloudAvatar({
    super.key,
    required this.name,
    required this.top,
    required this.left,
  });

  AssetImage _getImage(String name) {
    // 条件に応じて画像を切り替える
    if (name == "Ninohe" || name == "Hanamaki" || name == "Miyako" || name == "Senboku") {
      return const AssetImage("image/cloud2.jpg");
    }
    return const AssetImage("image/bluesky.jpg");
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      child: CircleAvatar(
        radius: 50,
        backgroundColor: Colors.white,
        backgroundImage: _getImage(name),
      ),
    );
  }
}