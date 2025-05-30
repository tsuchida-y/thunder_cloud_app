class WeatherConstants {
  // CAPE閾値
  static const double capeHighThreshold = 2500.0;
  static const double capeMediumThreshold = 1000.0;
  static const double capeLowThreshold = 500.0;
  
  // リフティド指数閾値
  static const double liHighRiskThreshold = -6.0;
  static const double liMediumRiskThreshold = -3.0;
  static const double liStableThreshold = 0.0;
  
  // 対流抑制閾値
  static const double cinLowThreshold = 25.0;
  static const double cinMediumThreshold = 50.0;
  static const double cinHighThreshold = 100.0;
  
  // 温度閾値
  static const double tempHighThreshold = 30.0;
  static const double tempMediumThreshold = 25.0;
  static const double tempLowThreshold = 20.0;
  
  // 総合判定閾値
  static const double thunderCloudThreshold = 0.6;
  
  // 検索距離設定（統一管理）
  static const List<double> searchDistances = [50.0, 160.0, 250.0]; // km
  
  // 距離ラベル（searchDistancesと連動）
  static Map<double, String> distanceLabels = {
    50.0: "近距離",
    120.0: "中距離", 
    200.0: "遠距離",
  };
  
  // 座標計算用定数
  static const double latitudePerDegreeKm = 111.0; // 緯度1度あたりのkm
  
  // 重み係数（CIN追加版）
  static const Map<String, double> analysisWeights = {
    'cape': 0.5,
    'lifted_index': 0.3,
    'cin': 0.1,
    'temperature': 0.1,
  };
  
  // ヘルパーメソッド：距離ラベル取得
  static String getDistanceLabel(double distance) {
    return distanceLabels[distance] ?? "${distance}km";
  }
  
  // ヘルパーメソッド：すべての距離を取得
  static List<double> getAllSearchDistances() {
    return List.from(searchDistances);
  }
  
  // 新規追加：API使用量計算
  static int calculateDailyApiRequests({
    int intervalSeconds = 180, // weather_screen.dartの現在設定
    int directionsCount = 4,
  }) {
    final distanceCount = searchDistances.length;
    final requestsPerInterval = directionsCount * distanceCount;
    final intervalsPerDay = (24 * 60 * 60) ~/ intervalSeconds;
    return requestsPerInterval * intervalsPerDay;
  }
  
  // 新規追加：設定情報取得
  static Map<String, dynamic> getConfigInfo() {
    return {
      'distances': searchDistances,
      'distanceLabels': distanceLabels,
      'estimatedDailyRequests': calculateDailyApiRequests(),
      'currentInterval': 180, // 秒
      'totalCheckPoints': searchDistances.length * 4, // 距離数 × 方向数
    };
  }
  
  // 新規追加：距離設定の妥当性チェック
  static bool validateDistanceSettings() {
    if (searchDistances.isEmpty) return false;
    if (searchDistances.length != distanceLabels.length) return false;
    
    // 距離が昇順になっているかチェック
    for (int i = 1; i < searchDistances.length; i++) {
      if (searchDistances[i] <= searchDistances[i - 1]) return false;
    }
    
    return true;
  }
}