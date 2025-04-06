import 'package:geolocator/geolocator.dart';

// 位置情報の権限を確認する関数
Future<void> checkPermission() async {
  LocationPermission permission = await Geolocator.checkPermission();
  
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      print("位置情報のアクセスが拒否されました。");
      return;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    print("設定から位置情報の権限を有効にしてください。");
    return;
  }
}

Future<void> getCurrentLocation() async {
  try {
    await checkPermission();
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    
    print("現在地: 緯度 ${position.latitude}, 経度 ${position.longitude}");
  } catch (e) {
    print("位置情報の取得に失敗しました: $e");
  }
}