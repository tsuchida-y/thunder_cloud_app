// lib/constants/weather_constants.dart - 位置監視設定（AppConstantsを参照）
import 'package:geolocator/geolocator.dart';

import 'app_constants.dart';

class WeatherConstants {
  // AppConstantsから参照
  static const List<String> checkDirections = AppConstants.checkDirections;
  static const List<double> checkDistances = AppConstants.checkDistances;

  // 表示用設定
  static const String appTitle = AppConstants.appTitle;
  static const String monitoringMessage = AppConstants.monitoringMessage;

  // 位置監視設定
  static const double locationUpdateDistanceFilter = AppConstants.locationUpdateDistanceFilter;
  static const int locationUpdateTimeInterval = AppConstants.locationUpdateTimeInterval;
  static const LocationAccuracy locationAccuracy = AppConstants.locationAccuracy;

  // バッテリー節約モード
  static const double batterySaveDistanceFilter = AppConstants.batterySaveDistanceFilter;
  static const LocationAccuracy batterySaveAccuracy = AppConstants.batterySaveAccuracy;
}