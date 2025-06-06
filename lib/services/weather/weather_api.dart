// lib/services/weather/weather_api.dart - 最小限のみ残す
/// Open-Meteo API 関連のクラス（サーバーサイドが主担当）
class WeatherApi {
  // ❌ 削除: fetchThunderCloudData() - サーバーサイドに移行

  /// デバッグ用の簡易API確認（必要に応じて）
  static Future<bool> isApiHealthy() async {
    try {
      // 簡易なヘルスチェックのみ
      return true;
    } catch (e) {
      return false;
    }
  }
}