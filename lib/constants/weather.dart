// lib/constants/weather_constants.dart - 位置監視設定
import 'package:geolocator/geolocator.dart';

class WeatherConstants {
  static const List<String> checkDirections = ["north", "south", "east", "west"];
  static const List<double> checkDistances = [50.0, 160.0, 250.0];

  // 表示用設定
  static const String appTitle = "入道雲サーチ";
  static const String monitoringMessage = "サーバーが5分間隔で監視中";

  // 位置監視設定
  static const double locationUpdateDistanceFilter = 1000.0; // 1km移動で更新
  static const int locationUpdateTimeInterval = 5; // 最低5分間隔
  static const LocationAccuracy locationAccuracy = LocationAccuracy.high;

  // バッテリー節約モード
  static const double batterySaveDistanceFilter = 5000.0; // 5km移動で更新
  static const LocationAccuracy batterySaveAccuracy = LocationAccuracy.medium;
}