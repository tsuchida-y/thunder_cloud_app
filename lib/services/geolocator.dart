import 'dart:developer';

import 'package:geolocator/geolocator.dart';

// 位置情報の権限を確認する関数
Future<void> checkPermission() async {
  LocationPermission permission = await Geolocator.checkPermission();
  
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      log("位置情報のアクセスが拒否されました。");
      return;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    log("設定から位置情報の権限を有効にしてください。");
    return;
  }
}

// 現在地を取得する関数
Future<Position> getCurrentLocation() async {
  try {
    await checkPermission(); // 権限を確認
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    log("現在地: 緯度 ${position.latitude}, 経度 ${position.longitude}");
    return position; // 現在地を返す
  } catch (e) {
    log("位置情報の取得に失敗しました: $e");
    rethrow; // エラーを呼び出し元に伝える
  }
}