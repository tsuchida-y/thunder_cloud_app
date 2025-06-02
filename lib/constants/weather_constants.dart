class WeatherConstants {

  static const Map<String, double> analysisWeights = {
    'cape': 0.5,           // 50%
    'lifted_index': 0.35,  // 35%
    'cin': 0.05,          // 5%
    'temperature': 0.1,    // 10%
  };

  // タイマー間隔設定
  static const int weatherCheckInterval = 120;

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
  static const List<double> checkDistances = [50.0, 160.0, 250.0]; // km
  
  // 座標計算用定数
  static const double latitudePerDegreeKm = 111.0; // 緯度1度あたりのkm


  // 新規追加：距離設定の妥当性チェック
  static bool validateDistanceSettings() {
    if (checkDistances.isEmpty) return false;
    
    // 距離が昇順になっているかチェック
    for (int i = 1; i < checkDistances.length; i++) {
      if (checkDistances[i] <= checkDistances[i - 1]) return false;
    }
    
    return true;
  }
}