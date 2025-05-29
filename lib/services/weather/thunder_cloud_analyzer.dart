import 'package:thunder_cloud_app/models/thunder_cloud_assessment.dart';

class ThunderCloudAnalyzer {
  /// Open-Meteoデータのみでの積乱雲分析
  static ThunderCloudAssessment analyzeWithMeteoDataOnly(
    Map<String, dynamic> meteoData,
  ) {
    final scores = <String, double>{};

    // 1. CAPE評価（重み40%）
    final cape = meteoData['cape'] ?? 0.0;
    if (cape >= 2500) {
      scores['cape'] = 1.0;
    } else if (cape >= 1000) {
      scores['cape'] = 0.8;
    } else if (cape >= 500) {
      scores['cape'] = 0.4;
    } else {
      scores['cape'] = 0.1;
    }

    // 2. リフティド指数評価（重み30%）
    final li = meteoData['lifted_index'] ?? 0.0;
    if (li <= -6) {
      scores['lifted_index'] = 1.0;
    } else if (li <= -3) {
      scores['lifted_index'] = 0.8;
    } else if (li <= 0) {
      scores['lifted_index'] = 0.5;
    } else {
      scores['lifted_index'] = 0.2;
    }

    // 3. 対流抑制（CIN）評価（重み15%）
    final cin = meteoData['convective_inhibition'] ?? 0.0;
    if (cin <= 25) {
      scores['cin'] = 1.0; // 低いCIN = 対流しやすい
    } else if (cin <= 50) {
      scores['cin'] = 0.6;
    } else {
      scores['cin'] = 0.2;
    }

    // 4. 温度評価（重み15%）
    final temperature = meteoData['temperature'] ?? 20.0;
    if (temperature >= 30) {
      scores['temperature'] = 1.0;
    } else if (temperature >= 25) {
      scores['temperature'] = 0.8;
    } else {
      scores['temperature'] = 0.3;
    }

    // 総合スコア計算（新しい重み配分）
    final totalScore = (scores['cape']! * 0.4 +
        scores['lifted_index']! * 0.3 +
        scores['cin']! * 0.15 +
        scores['temperature']! * 0.15);

    final confidence = 1.0; // Open-Meteoデータが完全にある場合
    final riskLevel = totalScore >= 0.8
        ? "非常に高い"
        : totalScore >= 0.6
            ? "高い"
            : totalScore >= 0.4
                ? "中程度"
                : "低い";

    return ThunderCloudAssessment(
      isThunderCloudLikely: totalScore >= 0.6,
      totalScore: totalScore,
      confidence: confidence,
      riskLevel: riskLevel,
      individualScores: scores,
      details: {
        'cape': '${cape.toStringAsFixed(1)} J/kg',
        'lifted_index': li.toStringAsFixed(1),
        'cin': '${cin.toStringAsFixed(1)} J/kg',
        'temperature': '${temperature.toStringAsFixed(1)}°C',
      },
      recommendation:
          totalScore >= 0.6 ? "積乱雲の可能性があります。注意してください。" : "積乱雲の可能性は低いです。",
    );
  }

  // 旧来のanalyzeThunderCloudPotentialメソッドは削除
}
