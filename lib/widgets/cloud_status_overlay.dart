import 'package:flutter/material.dart';
import '../constants/avatar_positions.dart';
import 'cloud_avatar.dart';
import 'direction_image.dart';


///背景の上に重ねる天気情報オーバーレイを作成するウィジェット
///方角がわかる画像と東西南北の入道雲を表示する
class CloudStatusOverlay extends StatelessWidget {
  final List<String> matchingCities;

  const CloudStatusOverlay({
    super.key,
    required this.matchingCities,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DirectionImage(),

        //各方向のCloudAvatarを動的に生成する処理
        //.entries：キーと値をセットで取得
        ...avatarPositions.entries.map((entry) {
          return CloudAvatar(
            name: entry.key,
            top: entry.value.dy,
            left: entry.value.dx,
            isCloudy: matchingCities.contains(entry.key),
          );
        })
      ],
    );
  }
}