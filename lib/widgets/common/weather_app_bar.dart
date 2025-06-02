import 'package:flutter/material.dart';


///AppBar用のウィジェット
///今後おしゃれにしていきたいから、別ファイルに分離
class WeatherAppBar extends StatelessWidget implements PreferredSizeWidget {
  const WeatherAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text("入道雲サーチ画面"),
      centerTitle: true,
      backgroundColor: const Color.fromARGB(255, 196, 248, 199),
      elevation: 3,
      shadowColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}