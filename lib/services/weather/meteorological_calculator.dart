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
    final windSpeed850 = advancedData['wind_speed_850'] ?? windSpeed10m; // フォールバック
    
    return (windSpeed850 - windSpeed10m).abs();
  }
  
  /// 大気安定度指数の総合評価
  static Map<String, double> calculateStabilityIndices(Map<String, dynamic> advancedData) {
    return {
      'k_index': calculateKIndex(advancedData),
      'ssi': calculateSSI(advancedData),
      'wind_shear': calculateWindShear(advancedData),
      'cape': advancedData['cape'] ?? 0.0,
      'lifted_index': advancedData['lifted_index'] ?? 0.0,
      'cin': advancedData['convective_inhibition'] ?? 0.0,
    };
  }
  
  /// 指数に基づく安定度評価
  static String evaluateAtmosphericStability(Map<String, double> indices) {
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
    
    // CAPE評価
    if (cape >= 2500) {
      instabilityScore += 3;
    } else if (cape >= 1000) {
      instabilityScore += 2;
    } else if (cape >= 500) {
      instabilityScore += 1;
    }
    
    // LI評価
    if (li <= -6) {
      instabilityScore += 3;
    } else if (li <= -3) {
      instabilityScore += 2;
    } else if (li <= 0) {
      instabilityScore += 1;
    }
    
    // 総合評価
    if (instabilityScore >= 9) return "極めて不安定";
    if (instabilityScore >= 6) return "非常に不安定";
    if (instabilityScore >= 4) return "不安定";
    if (instabilityScore >= 2) return "やや不安定";
    return "安定";
  }
}