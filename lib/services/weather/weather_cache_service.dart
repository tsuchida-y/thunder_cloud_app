import 'package:cloud_firestore/cloud_firestore.dart';

import '../../constants/app_constants.dart';

/// 気象データのFirestore取得サービスクラス
class WeatherCacheService {
  static final WeatherCacheService _instance = WeatherCacheService._internal();
  factory WeatherCacheService() => _instance;
  WeatherCacheService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Duration _cacheValidityDuration = AppConstants.cacheValidityDuration;

  /// 現在地の各方向の気象データを取得（Firestoreから直接）
  Future<Map<String, dynamic>?> getWeatherDataWithCache(
    double latitude,
    double longitude,
  ) async {
    final cacheKey = _generateCacheKey(latitude, longitude);

    print("🔍 === Firestore気象データ取得デバッグ ===");
    print("📍 位置情報: 緯度 $latitude, 経度 $longitude");
    print("🔑 生成されたキャッシュキー: $cacheKey");

    try {
      // Firestoreから直接取得
      print("📡 Firestoreからデータを取得中...");
      final doc = await _firestore.collection('weather_cache').doc(cacheKey).get();

      print("📄 ドキュメント存在: ${doc.exists}");

      if (doc.exists) {
        final data = doc.data();
        print("📊 ドキュメントデータ: ${data != null ? 'あり' : 'なし'}");

        if (data != null) {
          print("🔍 データキー: ${data.keys.toList()}");

          final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
          final now = DateTime.now();
          final timeDiff = now.difference(timestamp);

          print("⏰ タイムスタンプ: $timestamp");
          print("🕐 現在時刻: $now");
          print("⌛ 経過時間: ${timeDiff.inMinutes}分");
          print("✅ 有効期限: ${_cacheValidityDuration.inMinutes}分");

          // Firestoreのデータが有効期限内かチェック
          if (timeDiff < _cacheValidityDuration) {
            final weatherData = data['data'] as Map<String, dynamic>?;
            print("🌦️ 気象データ: ${weatherData != null ? 'あり' : 'なし'}");

            if (weatherData != null) {
              print("📋 気象データキー: ${weatherData.keys.toList()}");
              print("✅ Firestoreから有効なデータを取得");
              return weatherData;
            } else {
              print("❌ 気象データがnull");
            }
          } else {
            print("⏰ Firestoreのデータが期限切れ (${timeDiff.inMinutes}分経過)");
          }
        } else {
          print("❌ ドキュメントデータがnull");
        }
      } else {
        print("❌ ドキュメントが存在しません");

        // 存在するドキュメントを確認
        print("🔍 weather_cacheコレクション内の全ドキュメントを確認中...");
        final allDocs = await _firestore.collection('weather_cache').get();
        print("📊 コレクション内のドキュメント数: ${allDocs.docs.length}");

        for (var doc in allDocs.docs) {
          print("📄 ドキュメントID: ${doc.id}");
        }
      }

      print("⚠️ 有効なキャッシュデータが見つかりません。Firebase Functionsによる自動更新を待機中...");
      return null;

    } catch (e) {
      print("❌ Firestoreからのデータ取得エラー: $e");
      print("❌ エラータイプ: ${e.runtimeType}");
      return null;
    }
  }

  /// Firestoreの気象データをリアルタイム監視
  Stream<Map<String, dynamic>?> watchWeatherData(
    double latitude,
    double longitude,
  ) {
    final cacheKey = _generateCacheKey(latitude, longitude);

    print("📡 === リアルタイム監視開始 ===");
    print("📍 監視位置: 緯度 $latitude, 経度 $longitude");
    print("🔑 監視キー: $cacheKey");

    return _firestore.collection('weather_cache').doc(cacheKey).snapshots().map((snapshot) {
      print("📡 リアルタイム更新受信: ${snapshot.exists ? 'データあり' : 'データなし'}");

      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          print("🔍 受信データキー: ${data.keys.toList()}");

          final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
          final now = DateTime.now();
          final timeDiff = now.difference(timestamp);

          print("⏰ データタイムスタンプ: $timestamp");
          print("⌛ 経過時間: ${timeDiff.inMinutes}分");

          // データが有効期限内かチェック
          if (timeDiff < _cacheValidityDuration) {
            final weatherData = data['data'] as Map<String, dynamic>?;
            if (weatherData != null) {
              print("✅ リアルタイム: 有効な気象データを受信");
              print("📋 気象データキー: ${weatherData.keys.toList()}");
              return weatherData;
            } else {
              print("❌ リアルタイム: 気象データがnull");
            }
          } else {
            print("⏰ リアルタイム: データが期限切れ (${timeDiff.inMinutes}分経過)");
          }
        } else {
          print("❌ リアルタイム: ドキュメントデータがnull");
        }
      } else {
        print("❌ リアルタイム: ドキュメントが存在しません");
      }

      return null;
    }).handleError((error) {
      print("❌ リアルタイム監視エラー: $error");
      print("❌ エラータイプ: ${error.runtimeType}");
    });
  }

  /// キャッシュキーを生成
  String _generateCacheKey(double latitude, double longitude) {
    // 精度を下げて、より広い範囲で同じキャッシュを使用
    // 0.01度 ≈ 約1km の範囲で同じキャッシュを使用
    final roundedLat = (latitude * 100).round() / 100;
    final roundedLng = (longitude * 100).round() / 100;
    return 'weather_${roundedLat.toStringAsFixed(2)}_${roundedLng.toStringAsFixed(2)}';
  }

  /// キャッシュの統計情報を取得（Firestoreベース）
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final querySnapshot = await _firestore.collection('weather_cache').get();
      final now = DateTime.now();

      int validEntries = 0;
      List<String> allCacheKeys = [];
      List<String> validCacheKeys = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        allCacheKeys.add(doc.id);

        if (timestamp != null && now.difference(timestamp) < _cacheValidityDuration) {
          validEntries++;
          validCacheKeys.add(doc.id);
        }
      }

      print("📊 === キャッシュ統計情報 ===");
      print("📄 全キャッシュ数: ${querySnapshot.docs.length}");
      print("✅ 有効キャッシュ数: $validEntries");
      print("📋 全キャッシュキー: $allCacheKeys");
      print("✅ 有効キャッシュキー: $validCacheKeys");
      print("⏰ キャッシュ有効期限: ${_cacheValidityDuration.inMinutes}分");

      return {
        'totalEntries': querySnapshot.docs.length,
        'validEntries': validEntries,
        'cacheValidityMinutes': _cacheValidityDuration.inMinutes,
        'allCacheKeys': allCacheKeys,
        'validCacheKeys': validCacheKeys,
      };
    } catch (e) {
      print("❌ キャッシュ統計取得エラー: $e");
      return {
        'totalEntries': 0,
        'validEntries': 0,
        'cacheValidityMinutes': _cacheValidityDuration.inMinutes,
        'allCacheKeys': [],
        'validCacheKeys': [],
      };
    }
  }
}
