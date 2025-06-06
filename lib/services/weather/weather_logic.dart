// lib/services/weather/weather_logic.dart - 大幅削除
import 'dart:developer';

/// 手動チェック用の軽量ロジック（必要に応じて）
class WeatherLogic {

  /// 手動での入道雲チェック（デバッグ用）
  static Future<String> manualThunderCloudCheck(
    double latitude,
    double longitude
  ) async {
    try {
      log("🔍 手動チェック実行: $latitude, $longitude");

      // サーバーサイドに委譲するため、実際の判定は行わない
      return "サーバーが5分間隔で監視中です";

    } catch (e) {
      log("❌ 手動チェックエラー: $e");
      return "チェックに失敗しました";
    }
  }
}

// ❌ 削除対象メソッド:
// - fetchAdvancedWeatherInDirections()
// - isAdvancedThunderCloudConditionMet()
// - calculateDirectionCoordinates() (サーバーに移行済み)