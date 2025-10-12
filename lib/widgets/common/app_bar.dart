import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:thunder_cloud_app/screens/settings_screen.dart';

///AppBar用のウィジェット
///今後おしゃれにしていきたいから、別ファイルに分離
class WeatherAppBar extends StatelessWidget implements PreferredSizeWidget {
  final LatLng? currentLocation;
  final VoidCallback? onProfileUpdated;
  final String title;

  const WeatherAppBar({
    super.key,
    this.currentLocation,
    this.onProfileUpdated,
    this.title = "入道雲サーチ画面",
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false, // 左側のアイコンを削除
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_outlined,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
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
      actions: _buildActions(context),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    // 全ての画面で設定ボタンを表示
    return [
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const SettingsScreen(),
            ),
          );
          // プロフィールが更新された場合、コールバックを実行
          if (result == true && onProfileUpdated != null) {
            onProfileUpdated!();
          }
        },
      ),
    ];
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

}