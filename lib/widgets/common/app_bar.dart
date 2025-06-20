import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../screens/settings_screen.dart';

///AppBar用のウィジェット
///今後おしゃれにしていきたいから、別ファイルに分離
class WeatherAppBar extends StatelessWidget implements PreferredSizeWidget {
  final LatLng? currentLocation;

  const WeatherAppBar({super.key, this.currentLocation});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_outlined,
            color: Colors.white,
            size: 24,
          ),
          SizedBox(width: 8),
          Text(
            "入道雲サーチ画面",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      centerTitle: true,
      backgroundColor: const Color.fromARGB(255, 135, 206, 250), // 空色（Sky Blue）
      foregroundColor: Colors.white, // アイコンと戻るボタンも白色に
      elevation: 3,
      shadowColor: Colors.black54,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SettingsScreen(currentLocation: currentLocation),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}