import 'dart:convert';
import 'dart:developer' as dev;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/coordinate.dart';

/// 気象データのキャッシュ機能付きサービスクラス
class WeatherCacheService {
  static const String _cacheKeyPrefix = 'weather_cache_';
  static const Duration _cacheValidDuration = Duration(minutes: 10);

  // Firebase Functions インスタンス
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// 現在地の各方向の気象データを取得（キャッシュ機能付き）
  static Future<Map<String, Map<String, dynamic>>?> getWeatherDataWithCache(
    LatLng currentLocation,
  ) async {
    dev.log("🌦️ === キャッシュ付き気象データ取得開始 ===");
    dev.log("📍 現在地: 緯度 ${currentLocation.latitude}, 経度 ${currentLocation.longitude}");

    final cacheKey = _generateCacheKey(currentLocation);

    try {
      // キャッシュから取得を試行
      final cachedData = await _getCachedData(cacheKey);
      if (cachedData != null) {
        dev.log("💾 キャッシュからデータを取得");
        return cachedData;
      }

      dev.log("🌐 新しいデータを取得中...");

      // Firebase Functionsから複数方向の気象データを一括取得
      final result = await _functions.httpsCallable('getDirectionalWeatherData').call({
        'latitude': currentLocation.latitude,
        'longitude': currentLocation.longitude,
        'directions': 'north,south,east,west',
      });

      final Map<String, Map<String, dynamic>> weatherData = {};

      if (result.data != null) {
        final data = result.data as Map<String, dynamic>;

        // 各方向のデータを処理
        for (String direction in ['north', 'south', 'east', 'west']) {
          if (data.containsKey(direction)) {
            final directionData = Map<String, dynamic>.from(data[direction]);
            weatherData[direction] = directionData;
          }
        }
      }

      if (weatherData.isNotEmpty) {
        // キャッシュに保存
        await _saveCachedData(cacheKey, weatherData);
        dev.log("✅ 気象データ取得・キャッシュ保存完了: ${weatherData.length}方向");
        return weatherData;
      }

      dev.log("❌ 気象データの取得に失敗");
      return null;

    } catch (e) {
      dev.log("❌ 気象データ取得エラー: $e");

      // エラー時は単一地点データ取得にフォールバック
      return await _fetchSingleLocationFallback(currentLocation);
    }
  }

  /// フォールバック用の単一地点データ取得
  static Future<Map<String, Map<String, dynamic>>?> _fetchSingleLocationFallback(
    LatLng currentLocation,
  ) async {
    dev.log("🔄 フォールバック処理開始");

    try {
      final Map<String, Map<String, dynamic>> result = {};

      // 各方向の気象データを個別に取得
      for (String direction in ['north', 'south', 'east', 'west']) {
        final coordinates = CoordinateUtils.calculateDirectionCoordinates(
          direction,
          currentLocation.latitude,
          currentLocation.longitude,
          50.0
        );

        try {
          // Firebase Functionsから単一地点のデータを取得
          final functionResult = await _functions.httpsCallable('getWeatherData').call({
            'latitude': coordinates.latitude,
            'longitude': coordinates.longitude,
          });

          if (functionResult.data != null) {
            final weatherData = Map<String, dynamic>.from(functionResult.data);
            result[direction] = weatherData;
          }
        } catch (e) {
          dev.log("❌ [$direction方向] データ取得エラー: $e");
        }
      }

      if (result.isNotEmpty) {
        // キャッシュに保存
        final cacheKey = _generateCacheKey(currentLocation);
        await _saveCachedData(cacheKey, result);
        dev.log("✅ フォールバック処理完了: ${result.length}方向");
      }

      return result.isNotEmpty ? result : null;
    } catch (e) {
      dev.log("❌ フォールバック処理エラー: $e");
      return null;
    }
  }

  /// キャッシュキーを生成
  static String _generateCacheKey(LatLng location) {
    return '$_cacheKeyPrefix${location.latitude.toStringAsFixed(4)}_${location.longitude.toStringAsFixed(4)}';
  }

  /// キャッシュからデータを取得
  static Future<Map<String, Map<String, dynamic>>?> _getCachedData(
    String cacheKey,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(cacheKey);
      final cacheTimeKey = '${cacheKey}_time';
      final cacheTime = prefs.getInt(cacheTimeKey);

      if (cachedJson != null && cacheTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final cacheAge = now - cacheTime;

        // キャッシュが有効期限内かチェック
        if (cacheAge < _cacheValidDuration.inMilliseconds) {
          final data = json.decode(cachedJson) as Map<String, dynamic>;
          return data.cast<String, Map<String, dynamic>>();
        } else {
          // 期限切れのキャッシュを削除
          await _clearCache(cacheKey);
        }
      }

      return null;
    } catch (e) {
      dev.log("❌ キャッシュ読み込みエラー: $e");
      return null;
    }
  }

  /// データをキャッシュに保存
  static Future<void> _saveCachedData(
    String cacheKey,
    Map<String, Map<String, dynamic>> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(data);
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      await prefs.setString(cacheKey, jsonString);
      await prefs.setInt('${cacheKey}_time', currentTime);

      dev.log("💾 データをキャッシュに保存: $cacheKey");
    } catch (e) {
      dev.log("❌ キャッシュ保存エラー: $e");
    }
  }

  /// 特定のキャッシュを削除
  static Future<void> _clearCache(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(cacheKey);
      await prefs.remove('${cacheKey}_time');
    } catch (e) {
      dev.log("❌ キャッシュ削除エラー: $e");
    }
  }

  /// 全ての気象データキャッシュを削除
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (String key in keys) {
        if (key.startsWith(_cacheKeyPrefix)) {
          await prefs.remove(key);
          await prefs.remove('${key}_time');
        }
      }

      dev.log("🧹 全ての気象データキャッシュを削除");
    } catch (e) {
      dev.log("❌ キャッシュ全削除エラー: $e");
    }
  }

  /// キャッシュの状態を取得
  static Future<Map<String, dynamic>> getCacheStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      int cacheCount = 0;
      int validCacheCount = 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      for (String key in keys) {
        if (key.startsWith(_cacheKeyPrefix) && !key.endsWith('_time')) {
          cacheCount++;

          final timeKey = '${key}_time';
          final cacheTime = prefs.getInt(timeKey);

          if (cacheTime != null) {
            final cacheAge = now - cacheTime;
            if (cacheAge < _cacheValidDuration.inMilliseconds) {
              validCacheCount++;
            }
          }
        }
      }

      return {
        'totalCaches': cacheCount,
        'validCaches': validCacheCount,
        'cacheValidDuration': _cacheValidDuration.inMinutes,
      };
    } catch (e) {
      dev.log("❌ キャッシュ状態取得エラー: $e");
      return {
        'totalCaches': 0,
        'validCaches': 0,
        'cacheValidDuration': _cacheValidDuration.inMinutes,
      };
    }
  }
}
