import 'package:flutter/material.dart';
import '../constants/avatar_positions.dart';
import 'cloud_avatar.dart';
import 'direction_image.dart';


///背景の上に重ねる天気情報オーバーレイを作成するウィジェット
class WeatherOverlay extends StatelessWidget {
  final List<String> matchingCities;

  const WeatherOverlay({
    super.key,
    required this.matchingCities,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DirectionImage(),

        //各方向のCloudAvatarを動的に生成する処理
        ...avatarPositions.entries.map((entry) {
          final direction = entry.key;
          final position = entry.value;
          return CloudAvatar(
            name: direction,
            top: position.dy,
            left: position.dx,
            isCloudy: matchingCities.contains(direction),
          );
        })


      ],
    );
  }
}