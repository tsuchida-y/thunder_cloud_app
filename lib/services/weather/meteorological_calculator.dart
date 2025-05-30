import 'package:thunder_cloud_app/constants/weather_constants.dart';

/// 気象計算ユーティリティクラス
class MeteorologicalCalculator {
  /// K指数計算
  /// K指数 = (T850 - T500) + Td850 - (T700 - Td700)
  static double calculateKIndex(Map<String, dynamic> advancedData) {
    final temp850 = advancedData['temp_850'] ?? 0.0;
    final temp700 = advancedData['temp_700'] ?? 0.0;
    final temp500 = advancedData['temp_500'] ?? 0.0;
    final dewpoint850 = advancedData['dewpoint_850'] ?? 0.0;
    final dewpoint700 = advancedData['dewpoint_700'] ?? 0.0;

    return (temp850 - temp500) + dewpoint850 - (temp700 - dewpoint700);
  }

  /// ショワルター安定指数計算
  /// SSI = T500 - Tparcel(500hPa)
  static double calculateSSI(Map<String, dynamic> advancedData) {
    final temp500 = advancedData['temp_500'] ?? 0.0;
    final temp850 = advancedData['temp_850'] ?? 0.0;
    final dewpoint850 = advancedData['dewpoint_850'] ?? 0.0;

    // 簡易的なSSI計算（完全な計算には複雑な気象学的処理が必要）
    final liftedTemp = temp850 + (dewpoint850 - temp850) * 0.5; // 簡易リフト計算
    return temp500 - liftedTemp;
  }

  /// 風のシア計算（簡易版）
  /// 上層・下層の風速差を計算
  static double calculateWindShear(Map<String, dynamic> advancedData) {
    final windSpeed10m = advancedData['wind_speed'] ?? 0.0;
    final windSpeed850 = advancedData['wind_speed_850'] ?? 0.0;
    return windSpeed850 - windSpeed10m;
  }

  /// 基本的な大気安定度評価（CAPE + LI のみ）
  static String evaluateBasicStability(double cape, double li) {
    int instabilityScore = 0;

    // ✅ WeatherConstantsの閾値を使用
    if (cape >= WeatherConstants.capeHighThreshold) {
      instabilityScore += 3;
    } else if (cape >= WeatherConstants.capeMediumThreshold) {
      instabilityScore += 2;
    } else if (cape >= WeatherConstants.capeLowThreshold) {
      instabilityScore += 1;
    }

    // ✅ WeatherConstantsの閾値を使用
    if (li <= WeatherConstants.liHighRiskThreshold) {
      instabilityScore += 3;
    } else if (li <= WeatherConstants.liMediumRiskThreshold) {
      instabilityScore += 2;
    } else if (li <= WeatherConstants.liStableThreshold) {
      instabilityScore += 1;
    }

    // 総合評価
    if (instabilityScore >= 6) return "極めて不安定";
    if (instabilityScore >= 4) return "非常に不安定";
    if (instabilityScore >= 2) return "不安定";
    if (instabilityScore >= 1) return "やや不安定";
    return "安定";
  }

  /// 高度な大気安定度評価（K指数、SSI、CAPE、LI を総合）
  static String evaluateAdvancedStability(Map<String, double> indices) {
    final kIndex = indices['k_index'] ?? 0.0;
    final ssi = indices['ssi'] ?? 0.0;
    final cape = indices['cape'] ?? 0.0;
    final li = indices['lifted_index'] ?? 0.0;

    int instabilityScore = 0;

    // K指数評価
    if (kIndex >= 40) {
      instabilityScore += 3;
    } else if (kIndex >= 30) {
      instabilityScore += 2;
    } else if (kIndex >= 20) {
      instabilityScore += 1;
    }

    // SSI評価
    if (ssi <= -3) {
      instabilityScore += 3;
    } else if (ssi <= 0) {
      instabilityScore += 2;
    } else if (ssi <= 3) {
      instabilityScore += 1;
    }

    // CAPE評価 - ✅ WeatherConstantsの閾値を使用
    if (cape >= WeatherConstants.capeHighThreshold) {
      instabilityScore += 3;
    } else if (cape >= WeatherConstants.capeMediumThreshold) {
      instabilityScore += 2;
    } else if (cape >= WeatherConstants.capeLowThreshold) {
      instabilityScore += 1;
    }

    // LI評価 - ✅ WeatherConstantsの閾値を使用
    if (li <= WeatherConstants.liHighRiskThreshold) {
      instabilityScore += 3;
    } else if (li <= WeatherConstants.liMediumRiskThreshold) {
      instabilityScore += 2;
    } else if (li <= WeatherConstants.liStableThreshold) {
      instabilityScore += 1;
    }

    // 総合評価（4つの指標なので最高12点）
    if (instabilityScore >= 10) return "極めて不安定";
    if (instabilityScore >= 8) return "非常に不安定";
    if (instabilityScore >= 5) return "不安定";
    if (instabilityScore >= 2) return "やや不安定";
    return "安定";
  }

  /// 総合大気安定度評価（メイン評価メソッド）
  static String evaluateAtmosphericStability(Map<String, double> indices) {
    // K指数やSSIが利用可能な場合は高度評価を使用
    if (indices.containsKey('k_index') || indices.containsKey('ssi')) {
      return evaluateAdvancedStability(indices);
    } else {
      // CAPE と LI のみの場合は基本評価を使用
      final cape = indices['cape'] ?? 0.0;
      final li = indices['lifted_index'] ?? 0.0;
      return evaluateBasicStability(cape, li);
    }
  }
}