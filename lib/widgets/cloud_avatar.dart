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

  AssetImage _getImage(String name) {
    // 条件に応じて画像を切り替える
    if (name == "north" || name == "south" || name == "east" || name == "west") {
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