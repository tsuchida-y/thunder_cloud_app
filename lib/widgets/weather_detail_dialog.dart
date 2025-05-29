import 'package:flutter/material.dart';
import '../models/thunder_cloud_assessment.dart';

/// 詳細分析結果表示ダイアログ
class WeatherDetailDialog extends StatelessWidget {
  final ThunderCloudAssessment assessment;
  
  const WeatherDetailDialog({
    super.key,
    required this.assessment,
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
}