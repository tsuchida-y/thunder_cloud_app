import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 気象データのデバッグ用サービスクラス
class WeatherDebugService {
  static final WeatherDebugService _instance = WeatherDebugService._internal();
  factory WeatherDebugService() => _instance;
  WeatherDebugService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Firestoreから気象データを取得してデバッグ情報を表示
  Future<Map<String, dynamic>?> debugWeatherData(
    double latitude,
    double longitude,
  ) async {
    print("\n🐛 === 気象データデバッグ開始 ===");
    print("📍 座標: 緯度 ${latitude.toStringAsFixed(6)}, 経度 ${longitude.toStringAsFixed(6)}");

    try {
      // Firestoreから気象データを取得
      final cacheKey = _generateCacheKey(latitude, longitude);
      final doc = await _firestore.collection('weather_cache').doc(cacheKey).get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('data')) {
          final weatherData = data['data'] as Map<String, dynamic>;
          final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

          print("✅ Firestoreからデータを取得");
          print("⏰ データ取得時刻: ${timestamp?.toString() ?? 'N/A'}");

          _printWeatherDetails(weatherData);

          if (weatherData.containsKey('analysis')) {
            _printAnalysisDetails(weatherData['analysis']);
          }

          return weatherData;
        }
      }

      print("⚠️ Firestoreにデータが見つかりません");
      return null;

    } catch (e) {
      print("❌ デバッグエラー: $e");
      return null;
    }
  }

  /// 複数方向の気象データをFirestoreから取得してデバッグ
  Future<Map<String, Map<String, dynamic>>?> debugDirectionalWeatherData(
    LatLng currentLocation,
  ) async {
    print("\n🐛 === 複数方向気象データデバッグ開始 ===");
    print("📍 現在地: 緯度 ${currentLocation.latitude}, 経度 ${currentLocation.longitude}");

    try {
      // Firestoreから複数方向のデータを取得
      final cacheKey = _generateDirectionalCacheKey(currentLocation);
      final doc = await _firestore.collection('weather_cache').doc(cacheKey).get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('data')) {
          final directionalData = Map<String, Map<String, dynamic>>.from(
            data['data'].cast<String, Map<String, dynamic>>()
          );
          final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

          print("✅ Firestoreから複数方向データを取得");
          print("⏰ データ取得時刻: ${timestamp?.toString() ?? 'N/A'}");
          print("🧭 取得方向数: ${directionalData.length}");

          // 各方向のデータを詳細表示
          for (String direction in ['north', 'south', 'east', 'west']) {
            if (directionalData.containsKey(direction)) {
              print("\n🧭 === [$direction方向] デバッグ情報 ===");
              _printWeatherDetails(directionalData[direction]!);

              if (directionalData[direction]!.containsKey('analysis')) {
                _printAnalysisDetails(directionalData[direction]!['analysis']);
              }
            } else {
              print("⚠️ [$direction方向] データなし");
            }
          }

          return directionalData;
        }
      }

      print("⚠️ Firestoreに複数方向データが見つかりません");
      return null;

    } catch (e) {
      print("❌ 複数方向デバッグエラー: $e");
      return null;
    }
  }

  /// Firestoreの気象データ状況を確認
  Future<void> debugFirestoreStatus() async {
    print("\n🔍 === Firestore気象データ状況確認 ===");

    try {
      // weather_cacheコレクションの全ドキュメントを取得
      final querySnapshot = await _firestore.collection('weather_cache').get();

      print("📊 総ドキュメント数: ${querySnapshot.docs.length}");

      if (querySnapshot.docs.isEmpty) {
        print("⚠️ Firestoreに気象データが存在しません");
        print("💡 Firebase Functionsによる自動データ取得を確認してください");
        return;
      }

      // 各ドキュメントの詳細を表示
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        final dataAge = timestamp != null
          ? DateTime.now().difference(timestamp).inMinutes
          : null;

        print("\n📄 ドキュメントID: ${doc.id}");
        print("⏰ データ時刻: ${timestamp?.toString() ?? 'N/A'}");
        print("📅 データ経過時間: ${dataAge != null ? '$dataAge分前' : 'N/A'}");

        if (data.containsKey('data')) {
          final weatherData = data['data'];
          if (weatherData is Map) {
            print("📊 データ項目数: ${weatherData.length}");
            print("🔑 データキー: ${weatherData.keys.join(', ')}");
          }
        }
      }

    } catch (e) {
      print("❌ Firestore状況確認エラー: $e");
    }
  }

  /// キャッシュキーを生成
  String _generateCacheKey(double latitude, double longitude) {
    return 'weather_${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}';
  }

  String _generateCacheKeyFromLocation(LatLng location) {
    return 'weather_${location.latitude.toStringAsFixed(2)}_${location.longitude.toStringAsFixed(2)}';
  }

  /// 複数方向用のキャッシュキーを生成
  String _generateDirectionalCacheKey(LatLng location) {
    return 'weather_${location.latitude.toStringAsFixed(4)}_${location.longitude.toStringAsFixed(4)}';
  }

  /// 気象データの詳細を表示
  void _printWeatherDetails(Map<String, dynamic> weatherData) {
    print("📊 === 気象データ詳細 ===");
    print("🔥 CAPE: ${weatherData['cape']?.toStringAsFixed(1) ?? 'N/A'} J/kg");
    print("📈 Lifted Index: ${weatherData['lifted_index']?.toStringAsFixed(1) ?? 'N/A'}");
    print("🚧 CIN: ${weatherData['convective_inhibition']?.toStringAsFixed(1) ?? 'N/A'} J/kg");
    print("🌡️ 気温: ${weatherData['temperature']?.toStringAsFixed(1) ?? 'N/A'}°C");
    print("💨 風速: ${weatherData['wind_speed']?.toStringAsFixed(1) ?? 'N/A'} m/s");
    print("🧭 風向: ${weatherData['wind_direction']?.toStringAsFixed(0) ?? 'N/A'}°");
    print("☁️ 全雲量: ${weatherData['cloud_cover']?.toStringAsFixed(1) ?? 'N/A'}%");
    print("🌫️ 中層雲: ${weatherData['cloud_cover_mid']?.toStringAsFixed(1) ?? 'N/A'}%");
    print("⛅ 高層雲: ${weatherData['cloud_cover_high']?.toStringAsFixed(1) ?? 'N/A'}%");
    print("💧 湿度: ${weatherData['relative_humidity']?.toStringAsFixed(1) ?? 'N/A'}%");
    print("📊 気圧: ${weatherData['surface_pressure']?.toStringAsFixed(1) ?? 'N/A'} hPa");
  }

  /// 分析結果の詳細を表示
  void _printAnalysisDetails(Map<String, dynamic> analysis) {
    print("⚡ === 入道雲分析結果 ===");
    print("🎯 判定: ${analysis['isLikely'] == true ? '入道雲の可能性あり' : '入道雲なし'}");
    print("📊 総合スコア: ${((analysis['totalScore'] ?? 0) * 100).toStringAsFixed(1)}%");
    print("🏷️ リスクレベル: ${analysis['riskLevel'] ?? 'N/A'}");
    print("📋 詳細スコア:");
    print("   - CAPE: ${((analysis['capeScore'] ?? 0) * 100).toStringAsFixed(1)}%");
    print("   - Lifted Index: ${((analysis['liScore'] ?? 0) * 100).toStringAsFixed(1)}%");
    print("   - CIN: ${((analysis['cinScore'] ?? 0) * 100).toStringAsFixed(1)}%");
    print("   - 温度: ${((analysis['tempScore'] ?? 0) * 100).toStringAsFixed(1)}%");

    if (analysis.containsKey('factors')) {
      final factors = analysis['factors'] as Map<String, dynamic>? ?? {};
      print("🔍 判定要因:");
      factors.forEach((key, value) {
        print("   - $key: $value");
      });
    }
  }
}