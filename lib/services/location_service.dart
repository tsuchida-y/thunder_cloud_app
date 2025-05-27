import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'geolocator.dart';


///位置情報取得サービスを提供するクラス
///低レベルな位置情報取得処理をGoogle Maps用の型に変換し、アプリケーション全体で統一された位置情報APIを提供する役割
class LocationService {
  static Future<LatLng?> getCurrentLocationAsLatLng() async {
    try {
      final locationData = await getCurrentLocation();
      return LatLng(locationData.latitude, locationData.longitude);
    } catch (e) {
      return null;
    }
  }
}