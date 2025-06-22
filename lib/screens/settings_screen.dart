import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/app_constants.dart';
import '../utils/logger.dart';
import 'settings/settings_service.dart';

/// 設定画面 - アプリの各種設定と状態確認
class SettingsScreen extends StatefulWidget {
  final LatLng? currentLocation;

  const SettingsScreen({
    super.key,
    this.currentLocation,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ===== サービス =====
  late final SettingsService _settingsService;

  // ===== 状態管理 =====
  bool _isLoading = false;
  bool _isLoadingUserInfo = true;
  Map<String, dynamic> _weatherData = {};
  Map<String, dynamic> _userInfo = {};
  DateTime? _lastUpdateTime;

  @override
  void initState() {
    super.initState();
    _settingsService = SettingsService();
    _initializeScreen();
  }

  @override
  void dispose() {
    _settingsService.dispose();
    super.dispose();
  }

  // ===== 初期化 =====

  /// 画面を初期化
  Future<void> _initializeScreen() async {
    setState(() {
      _isLoading = true;
      _isLoadingUserInfo = true;
    });

    try {
      AppLogger.info('設定画面初期化開始', tag: 'SettingsScreen');

      await _settingsService.initialize(widget.currentLocation);

      // データ更新のコールバックを設定
      _settingsService.setDataUpdateCallback(_onDataUpdate);

      // 初期データを取得
      _updateDataFromService();

      AppLogger.success('設定画面初期化完了', tag: 'SettingsScreen');
    } catch (e) {
      AppLogger.error('設定画面初期化エラー', error: e, tag: 'SettingsScreen');
      _showErrorSnackBar('初期化に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingUserInfo = false;
        });
      }
    }
  }

  /// サービスからデータを更新
  void _updateDataFromService() {
    setState(() {
      _weatherData = _settingsService.weatherData;
      _userInfo = _settingsService.userInfo;
      _lastUpdateTime = _settingsService.lastUpdateTime;
    });
  }

  /// データ更新時のコールバック
  void _onDataUpdate(Map<String, dynamic> weatherData, DateTime? updateTime) {
    if (mounted) {
      setState(() {
        _weatherData = weatherData;
        _lastUpdateTime = updateTime;
      });
    }
  }

  // ===== イベントハンドラー =====

  /// 位置情報を更新
  Future<void> _updateLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _settingsService.updateLocation();
      _updateDataFromService();
      _showSuccessSnackBar('位置情報を更新しました');
    } catch (e) {
      AppLogger.error('位置情報更新エラー', error: e, tag: 'SettingsScreen');
      _showErrorSnackBar('位置情報の更新に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 気象データを手動更新
  Future<void> _refreshWeatherData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _settingsService.fetchWeatherData();
      _updateDataFromService();
      _showSuccessSnackBar('気象データを更新しました');
    } catch (e) {
      AppLogger.error('気象データ更新エラー', error: e, tag: 'SettingsScreen');
      _showErrorSnackBar('気象データの更新に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// キャッシュをクリア
  Future<void> _clearCache() async {
    try {
      await _settingsService.clearCache();
      _showSuccessSnackBar('キャッシュをクリアしました');
    } catch (e) {
      AppLogger.error('キャッシュクリアエラー', error: e, tag: 'SettingsScreen');
      _showErrorSnackBar('キャッシュのクリアに失敗しました: $e');
    }
  }

  /// プロフィール編集ダイアログを表示
  Future<void> _showProfileEditDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ProfileEditDialog(
        currentUserInfo: _userInfo,
      ),
    );

    if (result != null) {
      try {
        await _settingsService.updateUserInfo(result);
        _updateDataFromService();
        _showSuccessSnackBar('プロフィールを更新しました');
      } catch (e) {
        AppLogger.error('プロフィール更新エラー', error: e, tag: 'SettingsScreen');
        _showErrorSnackBar('プロフィールの更新に失敗しました: $e');
      }
    }
  }

  // ===== UI構築 =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColorLight,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  /// アプリバーを構築
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        '設定',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: AppConstants.primarySkyBlue,
      elevation: AppConstants.elevationMedium,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _isLoading ? null : _refreshWeatherData,
          tooltip: '気象データ更新',
        ),
      ],
    );
  }

  /// メインボディを構築
  Widget _buildBody() {
    if (_isLoading && _weatherData.isEmpty) {
      return _buildLoadingIndicator();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserSection(),
          const SizedBox(height: AppConstants.paddingLarge),
          _buildLocationSection(),
          const SizedBox(height: AppConstants.paddingLarge),
          _buildWeatherSection(),
          const SizedBox(height: AppConstants.paddingLarge),
          _buildCacheSection(),
          const SizedBox(height: AppConstants.paddingLarge),
          _buildSystemSection(),
        ],
      ),
    );
  }

  /// ローディングインジケーターを構築
  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primarySkyBlue),
          ),
          SizedBox(height: AppConstants.paddingMedium),
          Text(
            '設定を読み込み中...',
            style: TextStyle(fontSize: AppConstants.fontSizeMedium),
          ),
        ],
      ),
    );
  }

  /// ユーザーセクションを構築
  Widget _buildUserSection() {
    return _buildSection(
      title: 'ユーザー情報',
      icon: Icons.person,
      children: [
        _buildUserCard(),
        const SizedBox(height: AppConstants.paddingMedium),
        _buildActionButton(
          label: 'プロフィール編集',
          icon: Icons.edit,
          onPressed: _showProfileEditDialog,
        ),
      ],
    );
  }

  /// ユーザーカードを構築
  Widget _buildUserCard() {
    if (_isLoadingUserInfo) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppConstants.paddingMedium),
          child: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: AppConstants.paddingMedium),
              Text('ユーザー情報を読み込み中...'),
            ],
          ),
        ),
      );
    }

    final userName = _userInfo['userName'] as String? ?? 'ユーザー';
    final avatarUrl = _userInfo['avatarUrl'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Row(
          children: [
            CircleAvatar(
              radius: AppConstants.avatarRadiusSmall,
              backgroundColor: AppConstants.primarySkyBlue,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Text(
                      userName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: AppConstants.fontSizeLarge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'ユーザーID: ${AppConstants.currentUserId}',
                    style: TextStyle(
                      fontSize: AppConstants.fontSizeSmall,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 位置情報セクションを構築
  Widget _buildLocationSection() {
    final location = _settingsService.currentLocation;

    return _buildSection(
      title: '位置情報',
      icon: Icons.location_on,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (location != null) ...[
                  Text(
                    '緯度: ${location.latitude.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: AppConstants.fontSizeMedium),
                  ),
                  Text(
                    '経度: ${location.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: AppConstants.fontSizeMedium),
                  ),
                ] else ...[
                  const Text(
                    '位置情報が取得されていません',
                    style: TextStyle(
                      fontSize: AppConstants.fontSizeMedium,
                      color: Colors.red,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppConstants.paddingMedium),
        _buildActionButton(
          label: '位置情報を更新',
          icon: Icons.my_location,
          onPressed: _updateLocation,
        ),
      ],
    );
  }

  /// 気象データセクションを構築
  Widget _buildWeatherSection() {
    return _buildSection(
      title: '気象データ',
      icon: Icons.cloud,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_weatherData.isNotEmpty) ...[
                  Text(
                    '最終更新: ${_formatDateTime(_lastUpdateTime)}',
                    style: const TextStyle(fontSize: AppConstants.fontSizeMedium),
                  ),
                  const SizedBox(height: AppConstants.paddingSmall),
                  Text(
                    'データ件数: ${_weatherData.length}件',
                    style: const TextStyle(fontSize: AppConstants.fontSizeMedium),
                  ),
                ] else ...[
                  const Text(
                    '気象データが取得されていません',
                    style: TextStyle(
                      fontSize: AppConstants.fontSizeMedium,
                      color: Colors.red,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppConstants.paddingMedium),
        _buildActionButton(
          label: '気象データを更新',
          icon: Icons.refresh,
          onPressed: _refreshWeatherData,
        ),
      ],
    );
  }

  /// キャッシュセクションを構築
  Widget _buildCacheSection() {
    return _buildSection(
      title: 'キャッシュ管理',
      icon: Icons.storage,
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(AppConstants.paddingMedium),
            child: Text(
              'アプリのパフォーマンス向上のため、データをキャッシュしています。',
              style: TextStyle(fontSize: AppConstants.fontSizeMedium),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.paddingMedium),
        _buildActionButton(
          label: 'キャッシュをクリア',
          icon: Icons.clear,
          onPressed: _clearCache,
          color: Colors.orange,
        ),
      ],
    );
  }

  /// システムセクションを構築
  Widget _buildSystemSection() {
    return _buildSection(
      title: 'システム情報',
      icon: Icons.info,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'アプリ名: ${AppConstants.appTitle}',
                  style: const TextStyle(fontSize: AppConstants.fontSizeMedium),
                ),
                Text(
                  'バージョン: ${AppConstants.appVersion}',
                  style: const TextStyle(fontSize: AppConstants.fontSizeMedium),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// セクションを構築
  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppConstants.primarySkyBlue),
            const SizedBox(width: AppConstants.paddingSmall),
            Text(
              title,
              style: const TextStyle(
                fontSize: AppConstants.fontSizeLarge,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.paddingMedium),
        ...children,
      ],
    );
  }

  /// アクションボタンを構築
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppConstants.primarySkyBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMedium),
        ),
      ),
    );
  }

  // ===== ヘルパーメソッド =====

  /// 日時をフォーマット
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '未取得';
    
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/'
           '${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// エラースナックバーを表示
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: AppConstants.snackBarDurationSeconds),
      ),
    );
  }

  /// 成功スナックバーを表示
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: AppConstants.snackBarDurationSeconds),
      ),
    );
  }
}

/// プロフィール編集ダイアログ
class _ProfileEditDialog extends StatefulWidget {
  final Map<String, dynamic> currentUserInfo;

  const _ProfileEditDialog({
    required this.currentUserInfo,
  });

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _avatarUrlController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.currentUserInfo['userName'] as String? ?? '',
    );
    _avatarUrlController = TextEditingController(
      text: widget.currentUserInfo['avatarUrl'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('プロフィール編集'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'ユーザー名',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          TextField(
            controller: _avatarUrlController,
            decoration: const InputDecoration(
              labelText: 'アバターURL（任意）',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            final updatedInfo = {
              'userName': _nameController.text.trim(),
              'avatarUrl': _avatarUrlController.text.trim(),
            };
            Navigator.of(context).pop(updatedInfo);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
