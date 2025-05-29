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
  
  // 重み係数
  static const Map<String, double> analysisWeights = {
    'cape': 0.4,
    'lifted_index': 0.3,
    'temperature': 0.2,
    'basic_weather': 0.1,
  };
}