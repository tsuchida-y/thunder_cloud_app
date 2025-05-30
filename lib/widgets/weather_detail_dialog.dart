import 'package:flutter/material.dart';
import '../models/thunder_cloud_assessment.dart';

class WeatherDetailDialog extends StatelessWidget {
  final ThunderCloudAssessment assessment;
  final Map<String, dynamic>? detailedResults; // 詳細結果（オプション）
  
  const WeatherDetailDialog({
    super.key,
    required this.assessment,
    this.detailedResults,
  });
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('積乱雲分析詳細'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildScoreRow('総合判定', assessment.isThunderCloudLikely ? '積乱雲の可能性あり' : '積乱雲の可能性低い'),
            _buildScoreRow('総合スコア', '${(assessment.totalScore * 100).toStringAsFixed(1)}%'),
            _buildScoreRow('信頼度', '${(assessment.confidence * 100).toStringAsFixed(1)}%'),
            _buildScoreRow('リスクレベル', assessment.riskLevel),
            const Divider(),
            
            // 距離別詳細表示（新規追加）
            if (detailedResults != null) ...[
              const Text('距離別検出結果:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...detailedResults!.entries.map((entry) {
                final direction = entry.key;
                final results = entry.value as List<Map<String, dynamic>>;
                return _buildDistanceDetails(direction, results);
              }).toList(),
              const Divider(),
            ],
            
            const Text('推奨アクション:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(assessment.recommendation),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
  
  Widget _buildScoreRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }
  
  // 距離別詳細表示ウィジェット（新規追加）
  Widget _buildDistanceDetails(String direction, List<Map<String, dynamic>> results) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$direction方向:', style: const TextStyle(fontWeight: FontWeight.w500)),
          ...results.map((result) {
            final distance = result['distance'];
            final hasCloud = result['hasThunderCloud'];
            
            return Padding(
              padding: const EdgeInsets.only(left: 16, top: 2),
              child: Text(
                '${distance}km: ${hasCloud ? '⛈️ 積乱雲あり' : '☀️ 積乱雲なし'}',
                style: TextStyle(
                  color: hasCloud ? Colors.red : Colors.green,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}