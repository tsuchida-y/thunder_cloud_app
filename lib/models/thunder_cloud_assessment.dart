/// 積乱雲評価結果クラス
class ThunderCloudAssessment {
  final bool isThunderCloudLikely;
  final double totalScore;
  final double confidence;
  final String riskLevel;
  final Map<String, double> individualScores;
  final Map<String, String> details;
  final String recommendation;
  final Map<String, dynamic> analysisDetails;

  ThunderCloudAssessment({
    required this.isThunderCloudLikely,
    required this.totalScore,
    required this.confidence,
    required this.riskLevel,
    required this.individualScores,
    required this.details,
    required this.recommendation,
    required this.analysisDetails,
  });

  @override
  String toString() {
    return 'ThunderCloudAssessment('
        'likely: $isThunderCloudLikely, '
        'score: ${(totalScore * 100).toStringAsFixed(1)}%, '
        'confidence: ${(confidence * 100).toStringAsFixed(1)}%, '
        'risk: $riskLevel)';
  }
}
