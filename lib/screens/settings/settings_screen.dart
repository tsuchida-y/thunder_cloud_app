import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/core/app_initialization.dart';
import '../../services/notification/fcm_token_manager.dart';
import '../../services/notification/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  bool _isNotificationDebugLoading = false;

  // 通知デバッグ情報
  String? _fcmToken;
  String? _apnsToken;
  AuthorizationStatus? _authorizationStatus;
  Map<String, dynamic> _notificationSettings = {};

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
            _buildNotificationDebugInfo(),
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

  /// 通知デバッグ情報を表示
  Widget _buildNotificationDebugInfo() {
    return ExpansionTile(
      title: const Text('🔔 通知デバッグ'),
      subtitle: const Text('FCMトークンと通知権限の確認'),
      children: [
        // Phase 1: 基本情報の確認
        ListTile(
          title: const Text('📱 Phase 1: 基本情報確認'),
          subtitle: const Text('FCMトークンと通知権限を確認'),
          trailing: _isNotificationDebugLoading
              ? const CircularProgressIndicator()
              : const Icon(Icons.info_outline),
          onTap: _isNotificationDebugLoading ? null : () => _debugBasicInfo(),
        ),

        // Phase 2: 通知テスト
        ListTile(
          title: const Text('🧪 Phase 2: 通知テスト'),
          subtitle: const Text('ローカル通知とFCM通知のテスト'),
          trailing: const Icon(Icons.notifications_active),
          onTap: () => _debugNotificationTest(),
        ),

        // Phase 3: 詳細診断
        ListTile(
          title: const Text('🔍 Phase 3: 詳細診断'),
          subtitle: const Text('通知チャンネルとシステム設定の確認'),
          trailing: const Icon(Icons.settings_applications),
          onTap: () => _debugDetailedDiagnosis(),
        ),

        // デバッグ情報表示
        if (_fcmToken != null) ...[
          const Divider(),
          _buildDebugInfoTile('FCMトークン', _fcmToken!, isToken: true),
          if (_apnsToken != null)
            _buildDebugInfoTile('APNSトークン', _apnsToken!, isToken: true),
          _buildDebugInfoTile('通知権限', _authorizationStatus?.name ?? 'Unknown'),
          ..._notificationSettings.entries.map((entry) =>
            _buildDebugInfoTile(entry.key, entry.value.toString())),
        ],
      ],
    );
  }

  /// デバッグ情報項目を作成
  Widget _buildDebugInfoTile(String title, String value, {bool isToken = false}) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(
        isToken ? '${value.substring(0, 20)}...' : value,
        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
      ),
      trailing: isToken
          ? IconButton(
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () => _copyToClipboard(value, title),
            )
          : null,
    );
  }

  /// Phase 1: 基本情報の確認
  Future<void> _debugBasicInfo() async {
    setState(() {
      _isNotificationDebugLoading = true;
    });

    try {
      // FCMトークンの取得
      _fcmToken = await FCMTokenManager.getToken(forceRefresh: true);

      // 通知権限の確認
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      _authorizationStatus = settings.authorizationStatus;

      // APNSトークンの取得（iOS）
      _apnsToken = await FirebaseMessaging.instance.getAPNSToken();

             // 詳細な通知設定
       _notificationSettings = {
         'Alert': settings.alert.name,
         'Badge': settings.badge.name,
         'Sound': settings.sound.name,
         'CriticalAlert': settings.criticalAlert.name,
         'Announcement': settings.announcement.name,
         'CarPlay': settings.carPlay.name,
         'LockScreen': settings.lockScreen.name,
         'NotificationCenter': settings.notificationCenter.name,
         'ShowPreviews': settings.showPreviews.name,
         'TimeSensitive': settings.timeSensitive.name,
       };

      // 結果をダイアログで表示
      if (!mounted) return;

      _showDebugResultDialog('Phase 1: 基本情報確認結果', _buildPhase1Results());

    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Phase 1 エラー', e.toString());
    } finally {
      setState(() {
        _isNotificationDebugLoading = false;
      });
    }
  }

  /// Phase 1の結果を構築
  Widget _buildPhase1Results() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildResultItem('FCMトークン取得', _fcmToken != null ? '✅ 成功' : '❌ 失敗'),
        _buildResultItem('トークン長', _fcmToken != null ? '${_fcmToken!.length}文字' : 'N/A'),
        _buildResultItem('通知権限', _getAuthorizationStatusText(_authorizationStatus)),
        if (_apnsToken != null)
          _buildResultItem('APNSトークン', '✅ 取得済み'),
        const SizedBox(height: 16),

        // 問題の診断
        Text('🔍 診断結果:', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ..._buildDiagnosisResults(),
      ],
    );
  }

  /// Phase 2: 通知テスト
  Future<void> _debugNotificationTest() async {
    if (_fcmToken == null) {
      _showErrorDialog('テストエラー', 'まずPhase 1で基本情報を確認してください');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🧪 通知テスト'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('ローカル通知テスト'),
              subtitle: const Text('アプリ内での通知表示をテスト'),
              trailing: const Icon(Icons.phone_android),
              onTap: () => _testLocalNotification(),
            ),
            ListTile(
              title: const Text('FCMトークンをコピー'),
              subtitle: const Text('Firebase Consoleでのテスト用'),
              trailing: const Icon(Icons.copy),
              onTap: () => _copyToClipboard(_fcmToken!, 'FCMトークン'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  /// Phase 3: 詳細診断
  Future<void> _debugDetailedDiagnosis() async {
    // 通知チャンネルの確認とシステム設定の詳細診断
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔍 詳細診断'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('通知チャンネル確認:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              const Text('• Android: 設定 → アプリ → Thunder Cloud → 通知'),
              const Text('• iOS: 設定 → 通知 → Thunder Cloud'),
              const SizedBox(height: 16),

              Text('システム設定確認:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              const Text('• バッテリー最適化の除外'),
              const Text('• おやすみモードの設定'),
              const Text('• 通知の表示設定'),
              const SizedBox(height: 16),

              Text('Firebase Console確認:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              const Text('• プロジェクト設定の確認'),
              const Text('• APNs証明書の設定（iOS）'),
              const Text('• Server Key の設定（Android）'),
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
  }

  /// ローカル通知テスト
  Future<void> _testLocalNotification() async {
    try {
      await NotificationService.showLocalNotification(
        title: '🧪 テスト通知',
        body: 'ローカル通知のテストです。この通知が表示されれば、基本的な通知機能は動作しています。',
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ローカル通知を送信しました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('ローカル通知エラー', e.toString());
    }
  }

  /// 診断結果を構築
  List<Widget> _buildDiagnosisResults() {
    List<Widget> results = [];

    // FCMトークンの診断
    if (_fcmToken == null) {
      results.add(_buildDiagnosisItem('❌ FCMトークンが取得できません',
          'アプリの再起動、権限の確認、ネットワーク接続を確認してください'));
    } else if (_fcmToken!.length < 140) {
      results.add(_buildDiagnosisItem('⚠️ FCMトークンが短すぎます',
          'トークンの長さ: ${_fcmToken!.length}文字（通常は152-163文字）'));
    } else {
      results.add(_buildDiagnosisItem('✅ FCMトークンは正常です',
          'トークンの長さ: ${_fcmToken!.length}文字'));
    }

    // 通知権限の診断
    if (_authorizationStatus == AuthorizationStatus.denied) {
      results.add(_buildDiagnosisItem('❌ 通知権限が拒否されています',
          'デバイスの設定から通知権限を有効にしてください'));
    } else if (_authorizationStatus == AuthorizationStatus.notDetermined) {
      results.add(_buildDiagnosisItem('⚠️ 通知権限が未設定です',
          'アプリを再起動して権限を許可してください'));
    } else if (_authorizationStatus == AuthorizationStatus.authorized) {
      results.add(_buildDiagnosisItem('✅ 通知権限は正常です',
          '通知を受信できる状態です'));
    }

    return results;
  }

  /// 診断項目を構築
  Widget _buildDiagnosisItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  /// 結果項目を構築
  Widget _buildResultItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  /// 権限状態のテキスト取得
  String _getAuthorizationStatusText(AuthorizationStatus? status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return '✅ 許可済み';
      case AuthorizationStatus.denied:
        return '❌ 拒否';
      case AuthorizationStatus.notDetermined:
        return '⚠️ 未設定';
      case AuthorizationStatus.provisional:
        return '📋 仮許可';
      default:
        return '❓ 不明';
    }
  }

  /// クリップボードにコピー
  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$labelをクリップボードにコピーしました'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// デバッグ結果ダイアログを表示
  void _showDebugResultDialog(String title, Widget content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  /// エラーダイアログを表示
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
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