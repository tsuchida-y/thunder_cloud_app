/// 積乱雲総合分析クラス
class ThunderCloudAnalyzer {
  /// 積乱雲発生の総合判定
  static ThunderCloudAssessment analyzeThunderCloudPotential(
    Map<String, dynamic> basicWeather,
    Map<String, dynamic> advancedWeather,
  ) {
    final scores = <String, double>{};

    // 1. CAPE評価
    final cape = advancedWeather['cape'] ?? 0.0;
    if (cape >= 2500) {
      scores['cape'] = 1.0;
    } else if (cape >= 1000) {
      scores['cape'] = 0.8;
    } else if (cape >= 500) {
      scores['cape'] = 0.4;
    } else {
      scores['cape'] = 0.1;
    }

    // 2. リフティド指数評価
    final li = advancedWeather['lifted_index'] ?? 0.0;
    if (li <= -6) {
      scores['lifted_index'] = 1.0;
    } else if (li <= -3) {
      scores['lifted_index'] = 0.8;
    } else if (li <= 0) {
      scores['lifted_index'] = 0.5;
    } else {
      scores['lifted_index'] = 0.2;
    }

    // 3. 温度条件評価
    final temperature = advancedWeather['temperature'] ?? 20.0;
    if (temperature >= 30) {
      scores['temperature'] = 1.0;
    } else if (temperature >= 25) {
      scores['temperature'] = 0.8;
    } else {
      scores['temperature'] = 0.3;
    }

    // 4. 基本天気条件評価
    final weatherMain = basicWeather["weather"] ?? "";
    if (weatherMain == "Thunderstorm") {
      scores['basic_weather'] = 1.0;
    } else if (weatherMain == "Clouds") {
      scores['basic_weather'] = 0.5;
    } else {
      scores['basic_weather'] = 0.1;
    }

    // 総合スコア計算（重み付き平均）
    final totalScore = (scores['cape']! * 0.4 + 
                       scores['lifted_index']! * 0.3 + 
                       scores['temperature']! * 0.2 + 
                       scores['basic_weather']! * 0.1);
    
    final confidence = scores.length / 4.0; // 4つの指標すべてがある場合は1.0
    final riskLevel = totalScore >= 0.8 ? "非常に高い" : 
                     totalScore >= 0.6 ? "高い" : 
                     totalScore >= 0.4 ? "中程度" : "低い";

    return ThunderCloudAssessment(
      isThunderCloudLikely: totalScore >= 0.6, // 60%以上で積乱雲と判定
      totalScore: totalScore,
      confidence: confidence,
      riskLevel: riskLevel,
      individualScores: scores,
      details: {},
      recommendation: totalScore >= 0.6 ? "積乱雲の可能性があります" : "積乱雲の可能性は低いです",
    );
  }
}

/// 積乱雲評価結果クラス
class ThunderCloudAssessment {
  final bool isThunderCloudLikely;
  final double totalScore;
  final double confidence;
  final String riskLevel;
  final Map<String, double> individualScores;
  final Map<String, String> details;
  final String recommendation;

  ThunderCloudAssessment({
    required this.isThunderCloudLikely,
    required this.totalScore,
    required this.confidence,
    required this.riskLevel,
    required this.individualScores,
    required this.details,
    required this.recommendation,
  });
}