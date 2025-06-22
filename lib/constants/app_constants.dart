// lib/constants/app_constants.dart - アプリ全体の定数管理
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// アプリ全体で使用される定数を管理するクラス
class AppConstants {
  // ===== アプリ基本情報 =====
  static const String appTitle = "入道雲サーチ";
  static const String appVersion = "1.0.0";
  static const String defaultUserId = "user_001";

  // ===== 色定義 =====
  static const Color primarySkyBlue = Color.fromRGBO(135, 206, 250, 1.0);
  static const Color primarySkyBlueLight = Color.fromARGB(255, 135, 206, 250);

  // 透明度定数
  static const double opacityHigh = 0.9;
  static const double opacityMedium = 0.5;
  static const double opacityLow = 0.3;
  static const double opacityVeryLow = 0.2;
  static const double opacityMinimal = 0.1;

  // ===== 位置・気象関連 =====
  static const List<String> checkDirections = ["north", "south", "east", "west"];
  static const List<double> checkDistances = [50.0, 160.0, 250.0];

  // 座標精度
  static const int coordinatePrecision = 2; // 小数点以下桁数
  static const double coordinateRoundingFactor = 100.0; // 0.01度単位

  // 距離計算
  static const double latitudePerDegreeKm = 111.0; // 緯度1度あたりのkm

  // 位置監視設定
  static const double locationUpdateDistanceFilter = 5000.0; // 5km移動で更新
  static const int locationUpdateTimeInterval = 5; // 最低5分間隔
  static const LocationAccuracy locationAccuracy = LocationAccuracy.medium;

  // バッテリー節約モード
  static const double batterySaveDistanceFilter = 5000.0;
  static const LocationAccuracy batterySaveAccuracy = LocationAccuracy.medium;

  // ===== 時間関連 =====
  static const Duration cacheValidityDuration = Duration(minutes: 5);
  static const Duration locationValidityDuration = Duration(minutes: 10);
  static const Duration tokenValidityDuration = Duration(hours: 1);
  static const Duration appInitializationTimeout = Duration(seconds: 15);
  static const Duration locationTimeout = Duration(seconds: 10);
  static const Duration weatherDataTimeout = Duration(seconds: 10);
  static const Duration mainScreenDelay = Duration(seconds: 2);
  static const Duration settingsUpdateDelay = Duration(seconds: 2);
  static const Duration debugTestDelay = Duration(milliseconds: 500);
  static const Duration periodicUpdateInterval = Duration(seconds: 30);
  static const Duration realtimeUpdateInterval = Duration(seconds: 1);

  // リトライ設定
  static const int maxLocationRetries = 3;
  static const int maxLocationAttempts = 15; // 最大15秒待機
  static const int baseLocationTimeoutSeconds = 20;
  static const int locationTimeoutIncrementSeconds = 10;
  static const int retryDelayMultiplier = 2;

  // ===== UI・レイアウト関連 =====
  // 画面サイズ判定
  static const double tabletBreakpoint = 600.0;
  static const double smallScreenBreakpoint = 375.0; // iPhone SE等

  // フォントサイズ
  static const double fontSizeTitle = 18.0;
  static const double fontSizeLarge = 16.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeRegular = 13.0;
  static const double fontSizeSmall = 12.0;
  static const double fontSizeXSmall = 11.0;
  static const double fontSizeXXSmall = 10.0;
  static const double fontSizeTiny = 9.0;

  // アイコンサイズ
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 20.0;
  static const double iconSizeLarge = 24.0;
  static const double iconSizeXLarge = 48.0;

  // パディング・マージン
  static const double paddingXSmall = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 12.0;
  static const double paddingLarge = 16.0;
  static const double paddingXLarge = 20.0;
  static const double paddingXXLarge = 24.0;
  static const double paddingHuge = 30.0;

  // ボーダー半径
  static const double borderRadiusSmall = 4.0;
  static const double borderRadiusMedium = 8.0;
  static const double borderRadiusLarge = 12.0;

  // エレベーション
  static const double elevationLow = 2.0;
  static const double elevationMedium = 3.0;
  static const double elevationHigh = 4.0;

  // 影のオフセット
  static const Offset shadowOffsetSmall = Offset(0, 2);
  static const Offset shadowOffsetMedium = Offset(0, -2);

  // ===== アバター・画像関連 =====
  static const double defaultAvatarRadius = 50.0;

  // 方向画像サイズ
  static const double directionImageSize = 70.0;
  static const double directionImageSizeTablet = 100.0;
  static const double directionImageTopMargin = 10.0;
  static const double directionImageTopMarginTablet = 20.0;
  static const double directionImageRightMargin = 20.0;
  static const double directionImageRightMarginTablet = 30.0;

  // 画像圧縮設定
  static const int imageMaxWidth = 300;
  static const int imageMaxHeight = 300;
  static const int imageQuality = 80;

  // ===== 地図関連 =====
  static const double defaultMapZoom = 12.0;

  // ===== ナビゲーション関連 =====
  static const int navigationIndexWeather = 0;
  static const int navigationIndexGallery = 1;
  static const int navigationIndexCommunity = 2;

  // ===== 気象データ分析関連 =====
  static const double defaultTemperature = 20.0;
  static const double defaultWeatherValue = 0.0;

  // 監視メッセージ
  static const String monitoringMessage = "サーバーが5分間隔で監視中";
  static const String firebaseFunctionsMessage = "Firebase Functions: 5分間隔で監視中";

  // ===== ヘルパーメソッド =====

  /// 画面がタブレットサイズかどうかを判定
  static bool isTablet(Size screenSize) {
    return screenSize.width > tabletBreakpoint;
  }

  /// 画面が小さいサイズかどうかを判定
  static bool isSmallScreen(Size screenSize) {
    return screenSize.width < smallScreenBreakpoint;
  }

  /// 座標を指定精度で丸める
  static double roundCoordinate(double coordinate) {
    return (coordinate * coordinateRoundingFactor).round() / coordinateRoundingFactor;
  }

  /// 座標文字列を生成
  static String formatCoordinate(double coordinate) {
    return coordinate.toStringAsFixed(coordinatePrecision);
  }

  /// キャッシュキーを生成
  static String generateCacheKey(double latitude, double longitude) {
    final roundedLat = roundCoordinate(latitude);
    final roundedLng = roundCoordinate(longitude);
    return 'weather_${formatCoordinate(roundedLat)}_${formatCoordinate(roundedLng)}';
  }
}
