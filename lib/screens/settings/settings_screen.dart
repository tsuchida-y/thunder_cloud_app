import 'package:flutter/material.dart';

import '../../services/core/app_initialization.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildDebugInfo(),
          ],
        ),
      ),
    );
  }

  /// ユーザー統計情報を表示
  Widget _buildDebugInfo() {
    return ExpansionTile(
      title: const Text('デバッグ情報'),
      children: [
        // ユーザー統計情報を追加
        ListTile(
          title: const Text('ユーザー統計情報'),
          subtitle: const Text('usersコレクションの状況を確認'),
          trailing: _isLoading ? const CircularProgressIndicator() : const Icon(Icons.analytics),
          onTap: _isLoading ? null : () => _showUserStatistics(),
        ),
      ],
    );
  }

  /// ユーザー統計情報を表示
  Future<void> _showUserStatistics() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final stats = await AppInitializationService.getUserStatistics();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ユーザー統計情報'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (stats.containsKey('error'))
                  Text('エラー: ${stats['error']}', style: const TextStyle(color: Colors.red))
                else ...[
                  _buildStatItem('総ドキュメント数', '${stats['totalDocuments']}'),
                  _buildStatItem('アクティブユーザー', '${stats['activeUsers']}'),
                  _buildStatItem('非アクティブユーザー', '${stats['inactiveUsers']}'),
                  _buildStatItem('ユニークFCMトークン', '${stats['uniqueFcmTokens']}'),
                  _buildStatItem('重複FCMトークン', '${stats['duplicateFcmTokens']}'),
                  const SizedBox(height: 16),
                  if (stats['duplicateFcmTokens'] > 0)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '⚠️ 重複FCMトークンが検出されました。\nアプリを再起動すると自動的にクリーンアップされます。',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('統計情報の取得に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 統計項目を表示
  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}