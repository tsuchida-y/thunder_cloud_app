// lib/constants/app_constants.dart - アプリ全体の定数管理
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/user/user_id_service.dart';

/// アプリ全体で使用される定数を管理するクラス
class AppConstants {
  // ===== アプリ基本情報 =====
  static const String appTitle = "入道雲サーチ";
  static const String appVersion = "1.0.0";
  static const String defaultUserId = "user_001";

  // デバッグモード設定（本番では false に設定）
  static const bool isDebugMode = false; // App Store 審査用にfalseに変更

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

  // 地球の半径（km）- 地理計算に使用
  static const double earthRadiusKm = 6371.0;

  // 位置監視設定
  static const double locationUpdateDistanceFilter = 1000.0; // 1km移動で更新（5kmから変更）
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
  static const double elevationSmall = 1.0;
  static const double elevationMedium = 3.0;
  static const double elevationHigh = 4.0;

  // 影のオフセット
  static const Offset shadowOffsetSmall = Offset(0, 2);
  static const Offset shadowOffsetMedium = Offset(0, -2);

  // ===== アバター・画像関連 =====
  static const double defaultAvatarRadius = 50.0;
  static const double avatarBorderWidth = 2.0;
  static const double thumbnailSize = 60.0;

  // パディング・マージンの追加定数
  static const double smallPadding = 8.0;
  static const double extraSmallPadding = 4.0;

  // オーバーレイ透明度
  static const double overlayOpacity = 0.7;

  // ボーダー半径の追加定数
  static const double smallBorderRadius = 4.0;

  // フォントサイズの追加定数
  static const double smallFontSize = 12.0;

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

  // ===== コミュニティ関連 =====
  static const int defaultPhotoLimit = 20;
  static const double nearbyPhotosRadiusKm = 50.0;
  static const double scrollThreshold = 200.0;
  static const int snackBarDurationSeconds = 3;
  static const double photoAspectRatio = 16.0 / 9.0;
  static const double avatarRadiusSmall = 20.0;
  static const Color backgroundColorLight = Color(0xFFF5F5F5);

  // ===== 気象データ分析関連 =====
  static const double defaultTemperature = 20.0;
  static const double defaultWeatherValue = 0.0;

  // 監視メッセージ
  static const String monitoringMessage = "サーバーが5分間隔で監視中";
  static const String firebaseFunctionsMessage = "Firebase Functions: 5分間隔で監視中";

  // ===== ログレベル定数 =====
  static const String logLevelDebug = 'DEBUG';
  static const String logLevelInfo = 'INFO';
  static const String logLevelWarning = 'WARNING';
  static const String logLevelError = 'ERROR';
  static const String logLevelSuccess = 'SUCCESS';

  // ===== 型安全性向上のための定数 =====
  /// 空文字列定数
  static const String emptyString = '';

  /// ゼロ値定数
  static const int zeroInt = 0;
  static const double zeroDouble = 0.0;

  /// 無効なインデックス
  static const int invalidIndex = -1;

  // ===== エラーメッセージ定数 =====
  static const String errorLocationNotFound = '位置情報を取得できませんでした';
  static const String errorNetworkConnection = 'ネットワークに接続できません';
  static const String errorDataNotFound = 'データが見つかりません';
  static const String errorPermissionDenied = '権限が拒否されました';
  static const String errorUnknown = '不明なエラーが発生しました';

  // ===== 成功メッセージ定数 =====
  static const String successDataLoaded = 'データの読み込みが完了しました';
  static const String successLocationUpdated = '位置情報が更新されました';
  static const String successPhotoSaved = '写真が保存されました';

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

  // ===== ヘルパーメソッド（型安全性向上） =====

  /// 安全な文字列変換
  static String safeString(dynamic value) {
    if (value == null) return emptyString;
    return value.toString();
  }

  /// 安全な整数変換
  static int safeInt(dynamic value) {
    if (value == null) return zeroInt;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? zeroInt;
    return zeroInt;
  }

  /// 安全な浮動小数点変換
  static double safeDouble(dynamic value) {
    if (value == null) return zeroDouble;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? zeroDouble;
    return zeroDouble;
  }

  /// リストが空でないかチェック
  static bool isNotEmptyList<T>(List<T>? list) {
    return list != null && list.isNotEmpty;
  }

  /// 文字列が空でないかチェック
  static bool isNotEmptyString(String? str) {
    return str != null && str.isNotEmpty;
  }

  /// マップが空でないかチェック
  static bool isNotEmptyMap<K, V>(Map<K, V>? map) {
    return map != null && map.isNotEmpty;
  }

  /// 日時を読みやすい形式でフォーマット
  static String formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/'
           '${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 時刻のみを読みやすい形式でフォーマット
  static String formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// バイトサイズを読みやすい形式でフォーマット
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // ===== ユーザーID関連 =====

  /// 現在のユーザーIDを取得（UUID使用）
  static Future<String> getCurrentUserId() async {
    return await UserIdService.getUserId();
  }

  /// 現在のユーザーIDを同期的に取得（キャッシュのみ）
  /// 注意: 初回起動時はnullの可能性があります
  static String? get currentUserIdSync => UserIdService.currentUserId;
}
