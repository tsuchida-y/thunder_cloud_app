import 'dart:developer';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

/// 位置情報取得サービスを提供するクラス
/// 低レベルな位置情報取得処理をGoogle Maps用の型に変換し、アプリケーション全体で統一された位置情報APIを提供する役割
class LocationService {
  
  /// 現在地をLatLng型で取得（公開メソッド）
  static Future<LatLng?> getCurrentLocationAsLatLng() async {
    try {
      final locationData = await _getCurrentPosition();
      
      // LatLng型(GoogleMapで使用する)に変換
      return LatLng(locationData.latitude, locationData.longitude);
    } catch (e) {
      log("位置情報取得エラー: $e");
      return null;
    }
  }
  
  /// 現在地を取得する内部メソッド
  static Future<Position> _getCurrentPosition() async {
    try {
      await _checkPermission(); // 権限を確認
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      log("現在地: 緯度 ${position.latitude}, 経度 ${position.longitude}");
      return position;
    } catch (e) {
      log("位置情報の取得に失敗しました: $e");
      rethrow; // エラーを呼び出し元に伝える
    }
  }
  
  /// 位置情報の権限を確認する内部メソッド
  static Future<void> _checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        log("位置情報のアクセスが拒否されました。");
        throw Exception("位置情報のアクセスが拒否されました");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      log("設定から位置情報の権限を有効にしてください。");
      throw Exception("位置情報の権限が永続的に拒否されています");
    }
  }
}