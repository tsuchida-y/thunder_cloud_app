import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../screens/settings_screen.dart';

///AppBar用のウィジェット
///今後おしゃれにしていきたいから、別ファイルに分離
class WeatherAppBar extends StatelessWidget implements PreferredSizeWidget {
  final LatLng? currentLocation;
  final VoidCallback? onProfileUpdated;

  const WeatherAppBar({
    super.key,
    this.currentLocation,
    this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false, // 左側のアイコンを削除
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
          onPressed: () async {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SettingsScreen(currentLocation: currentLocation),
              ),
            );
            // プロフィールが更新された場合、コールバックを実行
            if (result == true && onProfileUpdated != null) {
              onProfileUpdated!();
            }
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}