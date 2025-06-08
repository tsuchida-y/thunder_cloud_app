/// 入道雲分析ロジックを担当するクラス
class ThunderCloudAnalyzer {

  /// 気象データから入道雲の可能性を分析
  static Map<String, dynamic> analyzeWeatherData(Map<String, dynamic> weatherData) {
    final double cape = weatherData['cape']?.toDouble() ?? 0.0;
    final double liftedIndex = weatherData['lifted_index']?.toDouble() ?? 0.0;
    final double cin = weatherData['convective_inhibition']?.toDouble() ?? 0.0;
    final double temperature = weatherData['temperature']?.toDouble() ?? 20.0;

    Map<String, double> scores = {};

    // CAPE評価（重み50%）
    scores['cape'] = _evaluateCAPE(cape);

    // Lifted Index評価（重み35%）
    scores['liftedIndex'] = _evaluateLiftedIndex(liftedIndex);

    // CIN評価（重み5%）
    scores['cin'] = _evaluateCIN(cin);

    // 温度評価（重み10%）
    scores['temperature'] = _evaluateTemperature(temperature);

    // 総合スコア計算
    final double totalScore = (
      scores['cape']! * 0.5 +
      scores['liftedIndex']! * 0.35 +
      scores['cin']! * 0.05 +
      scores['temperature']! * 0.1
    );

    return {
      'isLikely': totalScore >= 0.6,
      'totalScore': totalScore,
      'riskLevel': _getRiskLevel(totalScore),
      'capeScore': scores['cape']!,
      'liScore': scores['liftedIndex']!,
      'cinScore': scores['cin']!,
      'tempScore': scores['temperature']!,
    };
  }

  /// CAPE（対流有効位置エネルギー）を評価
  static double _evaluateCAPE(double cape) {
    if (cape >= 2500) {
      return 1.0;
    } else if (cape >= 1000) {
      return 0.8;
    } else if (cape >= 500) {
      return 0.6;
    } else if (cape >= 100) {
      return 0.3;
    } else {
      return 0.0;
    }
  }

  /// Lifted Index（リフティド指数）を評価
  static double _evaluateLiftedIndex(double liftedIndex) {
    if (liftedIndex <= -6) {
      return 1.0;
    } else if (liftedIndex <= -3) {
      return 0.8;
    } else if (liftedIndex <= 0) {
      return 0.6;
    } else if (liftedIndex <= 3) {
      return 0.4;
    } else if (liftedIndex <= 6) {
      return 0.2;
    } else {
      return 0.0;
    }
  }

  /// CIN（対流抑制）を評価
  static double _evaluateCIN(double cin) {
    if (cin <= 10) {
      return 0.3;
    } else if (cin <= 50) {
      return 0.1;
    } else {
      return 0.0;
    }
  }

  /// 温度を評価
  static double _evaluateTemperature(double temperature) {
    if (temperature >= 30) {
      return 1.0;
    } else if (temperature >= 25) {
      return 0.8;
    } else if (temperature >= 20) {
      return 0.6;
    } else if (temperature >= 15) {
      return 0.4;
    } else {
      return 0.0;
    }
  }

  /// 総合スコアからリスクレベルを決定
  static String _getRiskLevel(double totalScore) {
    if (totalScore >= 0.6) {
      return "高い";
    } else if (totalScore >= 0.3) {
      return "中程度";
    } else if (totalScore >= 0.15) {
      return "低い";
    } else {
      return "極めて低い";
    }
  }
}