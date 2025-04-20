import 'package:flutter/material.dart';

class DirectionImage extends StatelessWidget {
  //画面右上に方向を示す画像を表示するウィジェット
  const DirectionImage({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10.0,
      left: 300.0,
      width: 80.0,
      height: 80.0,
      child: Image.asset("image/direction.png"),
    );
  }
}