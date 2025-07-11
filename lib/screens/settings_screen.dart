import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_constants.dart';
import '../services/photo/user_service.dart';
import '../utils/logger.dart';
import 'settings/settings_service.dart';

/// 設定画面 - アプリの各種設定と状態確認
class SettingsScreen extends StatefulWidget {
  final LatLng? currentLocation;
  final VoidCallback? onProfileUpdated; // プロフィール更新時のコールバック

  const SettingsScreen({
    super.key,
    this.currentLocation,
    this.onProfileUpdated, // コールバックを追加
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /*
  ================================================================================
                                    サービス
                           設定機能で使用するサービスクラス
  ================================================================================
  */
  late final SettingsService _settingsService;

  /*
  ================================================================================
                                    状態管理
                         設定画面の状態を管理する変数群
  ================================================================================
  */
  // UI状態管理
  bool _isLoading = false; // 全体的なローディング状態（位置情報更新等）
  bool _isLoadingUserInfo = true; // ユーザー情報読み込み状態（初期化時）

  // データ状態管理
  Map<String, dynamic> _weatherData = {}; // 現在位置の気象データキャッシュ
  Map<String, dynamic> _userInfo = {}; // ユーザープロフィール情報（名前・アバター等）
  DateTime? _lastUpdateTime; // 最後のデータ更新時刻（鮮度表示用）

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

  /*
  ================================================================================
                                    初期化
                        サービス初期化とユーザー情報読み込み処理
  ================================================================================
  */

  /// 設定画面の初期化処理
  /// サービス初期化→コールバック設定→初期データ取得の順で実行
  /// パフォーマンス：非同期処理でUIブロックを防止
  Future<void> _initializeScreen() async {
    final startTime = DateTime.now();

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

      final duration = DateTime.now().difference(startTime);
      AppLogger.success('設定画面初期化完了 (${duration.inMilliseconds}ms)', tag: 'SettingsScreen');
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

  /// サービスからUIデータを同期更新
  /// SettingsServiceで管理されているデータを画面の状態に反映
  /// 呼び出しタイミング：初期化後・データ更新後・ユーザー操作後
  void _updateDataFromService() {
    setState(() {
      _weatherData = _settingsService.weatherData;
      _userInfo = _settingsService.userInfo;
      _lastUpdateTime = _settingsService.lastUpdateTime;
    });
  }

  /// SettingsServiceからのデータ更新通知処理
  /// 気象データが自動更新された際にUIを即座に反映
  /// 制約：mounted状態チェックでメモリリーク防止
  void _onDataUpdate(Map<String, dynamic> weatherData, DateTime? updateTime) {
    if (mounted) {
      setState(() {
        _weatherData = weatherData;
        _lastUpdateTime = updateTime;
      });
    }
  }

  /*
  ================================================================================
                               イベントハンドラー
                        ユーザー操作（プロフィール編集等）への応答処理
  ================================================================================
  */

  /// 位置情報の手動更新処理
  /// GPS再取得→気象データ更新→UI反映の流れで実行
  /// エラー時：フォールバック処理なし（ユーザー通知のみ）
  Future<void> _updateLocation() async {
    final startTime = DateTime.now();

    setState(() {
      _isLoading = true;
    });

    try {
      await _settingsService.updateLocation();
      _updateDataFromService();

      final duration = DateTime.now().difference(startTime);
      AppLogger.success('位置情報更新完了 (${duration.inMilliseconds}ms)', tag: 'SettingsScreen');
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

  /// プロフィール編集ダイアログの表示と結果処理
  /// ダイアログ表示→ユーザー入力→サービス更新→UI反映の流れで実行
  /// 最適化：ユーザー情報の再読み込みでデータ整合性を確保
  Future<void> _showProfileEditDialog() async {
    final startTime = DateTime.now();

    // デバッグ用：現在のユーザー情報をログ出力
    AppLogger.info('プロフィール編集ダイアログ開始', tag: 'SettingsScreen');
    AppLogger.info('現在のユーザー情報: $_userInfo', tag: 'SettingsScreen');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ProfileEditDialog(
        currentUserInfo: _userInfo,
      ),
    );

    if (result != null) {
      try {
        // 1. サービス経由でユーザー情報を更新
        await _settingsService.updateUserInfo(result);

        // 2. データ整合性確保のため再読み込み実行
        await _settingsService.reloadUserInfo();

        // 3. UI状態を最新データで更新
        _updateDataFromService();

        // 4. メイン画面にプロフィール更新を通知（コミュニティ画面のリロード）
        if (widget.onProfileUpdated != null) {
          widget.onProfileUpdated!();
          AppLogger.info('プロフィール更新をメイン画面に通知', tag: 'SettingsScreen');
        }

        final duration = DateTime.now().difference(startTime);
        AppLogger.success('プロフィール更新完了 (${duration.inMilliseconds}ms)', tag: 'SettingsScreen');
        _showSuccessSnackBar('プロフィールを更新しました');
      } catch (e) {
        AppLogger.error('プロフィール更新エラー', error: e, tag: 'SettingsScreen');
        _showErrorSnackBar('プロフィールの更新に失敗しました: $e');
      }
    }
  }

  /*
  ================================================================================
                                   UI構築
                          画面レイアウトとウィジェット構築処理
  ================================================================================
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColorLight,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  /// 設定画面のアプリバー構築
  /// シンプルなタイトル表示のみ（アクション不要）
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
    );
  }

  /// メインボディの構築処理
  /// 条件分岐：初回ローディング時は専用インジケーター表示
  /// 通常時：スクロール可能な3セクション構成（ユーザー・位置・気象）
  Widget _buildBody() {
    // 初回ローディング中かつデータが空の場合のみローディング表示
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
        ],
      ),
    );
  }

  /// 初期化時のローディングインジケーター構築
  /// 中央配置のスピナー＋メッセージ表示
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

  /// ユーザー情報セクションの構築
  /// プロフィール表示＋編集機能を提供
  Widget _buildUserSection() {
    return _buildSection(
      title: 'ユーザー情報',
      icon: Icons.person,
      children: [
        _buildUserCard(),
      ],
    );
  }

  /// ユーザープロフィールカードの構築
  /// 状態管理：ローディング→プロフィール表示→編集可能状態
  Widget _buildUserCard() {
    // ユーザー情報読み込み中の表示
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
                    'ユーザーID: ${_userInfo['userId'] ?? 'loading...'}',
                    style: TextStyle(
                      fontSize: AppConstants.fontSizeSmall,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // プロフィール編集ボタンを右側に配置
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showProfileEditDialog,
              tooltip: 'プロフィール編集',
              color: AppConstants.primarySkyBlue,
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
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (location != null) ...[
                        Text(
                          '緯度: ${AppConstants.formatCoordinate(location.latitude)}',
                          style: const TextStyle(fontSize: AppConstants.fontSizeMedium),
                        ),
                        Text(
                          '経度: ${AppConstants.formatCoordinate(location.longitude)}',
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
                // 位置情報更新ボタンを気象データ更新ボタンと同じスタイルに
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _updateLocation,
                  tooltip: '位置情報を更新',
                  color: AppConstants.primarySkyBlue,
                ),
              ],
            ),
          ),
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
        if (_weatherData.isNotEmpty) ...[
          // 基本情報カード
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '最終更新: ${_formatDateTime(_lastUpdateTime)}',
                              style: const TextStyle(
                                fontSize: AppConstants.fontSizeMedium,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppConstants.paddingSmall),
                            Text(
                              'データ件数: ${_weatherData.length}方向',
                              style: const TextStyle(fontSize: AppConstants.fontSizeMedium),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppConstants.paddingMedium),

          // 各方角の詳細データ
          ..._buildDirectionalWeatherCards(),
        ] else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isNightMode() ? '夜間モード（20時〜8時）' : '気象データが取得されていません',
                    style: TextStyle(
                      fontSize: AppConstants.fontSizeMedium,
                      color: _isNightMode() ? Colors.blue : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingMedium),
                                      Text(
                      _isNightMode()
                          ? '夜間は入道雲が発生する確率が極めて低いため、気象データの取得を停止しています。8時以降に自動で再開されます。'
                          : 'Firebase Functionsによる自動更新をお待ちください（5分間隔で更新）',
                      style: const TextStyle(
                        fontSize: AppConstants.fontSizeSmall,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 方角別の気象データカードを構築
  List<Widget> _buildDirectionalWeatherCards() {
    const directions = AppConstants.checkDirections;
    final directionNames = {
      'north': '北',
      'south': '南',
      'east': '東',
      'west': '西',
    };

    final availableDirections = directions.where((direction) => _weatherData.containsKey(direction)).toList();

    if (availableDirections.isEmpty) {
      // デバッグ用カードを表示
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'デバッグ情報',
                  style: TextStyle(
                    fontSize: AppConstants.fontSizeMedium,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSmall),
                Text(
                  '気象データのタイプ: ${_weatherData.runtimeType}',
                  style: const TextStyle(fontSize: AppConstants.fontSizeSmall),
                ),
                Text(
                  '利用可能なキー: ${_weatherData.keys.toList()}',
                  style: const TextStyle(fontSize: AppConstants.fontSizeSmall),
                ),
                Text(
                  '最終更新時刻: ${_lastUpdateTime != null ? _formatDateTime(_lastUpdateTime) : "未更新"}',
                  style: const TextStyle(fontSize: AppConstants.fontSizeSmall),
                ),
                const SizedBox(height: AppConstants.paddingSmall),
                const Text(
                  '詳細データ:',
                  style: TextStyle(fontSize: AppConstants.fontSizeSmall, fontWeight: FontWeight.bold),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _weatherData.toString(),
                    style: const TextStyle(fontSize: AppConstants.fontSizeXSmall),
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return availableDirections
        .map((direction) {
          final directionData = _weatherData[direction] as Map<String, dynamic>;
          final bestData = _selectBestDistanceData(direction, directionData);
          return _buildDirectionCard(
            direction,
            directionNames[direction] ?? direction,
            bestData,
          );
        })
        .toList();
  }

  /// 各方向のデータから最適な距離のデータを選択
  Map<String, dynamic> _selectBestDistanceData(String direction, Map<String, dynamic> directionData) {
    // 距離キー（50km、160km、250km）を探す
    final distanceKeys = directionData.keys
        .where((key) => key.contains('km'))
        .toList();

    if (distanceKeys.isEmpty) {
      // 距離キーがない場合は、そのまま返す（既に正しい形式）
      return directionData;
    }

    // 各距離のデータから最高スコアを選択
    Map<String, dynamic>? bestData;
    double bestScore = -1;

    for (final distanceKey in distanceKeys) {
      final distanceData = directionData[distanceKey] as Map<String, dynamic>?;
      if (distanceData != null && distanceData.containsKey('analysis')) {
        final analysis = distanceData['analysis'] as Map<String, dynamic>?;
        if (analysis != null && analysis.containsKey('totalScore')) {
          final score = (analysis['totalScore'] as num?)?.toDouble() ?? 0.0;
          if (score > bestScore) {
            bestScore = score;
            bestData = distanceData;
          }
        }
      }
    }

    if (bestData != null) {
      return bestData;
    }

    // フォールバック: 最初のデータを返す
    final firstKey = distanceKeys.first;
    return directionData[firstKey] as Map<String, dynamic>;
  }

  /// 個別方角のカードを構築
  Widget _buildDirectionCard(String direction, String directionName, Map<String, dynamic> data) {
    final analysis = data['analysis'] as Map<String, dynamic>?;
    final isThunderCloudLikely = analysis?['isLikely'] == true;
    final totalScore = '${((analysis?['totalScore'] ?? 0) * 100).toStringAsFixed(1)}%';

    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      child: ExpansionTile(
        title: Row(
          children: [
            Text(
              '$directionName方向',
              style: const TextStyle(
                fontSize: AppConstants.fontSizeMedium,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (analysis != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingSmall,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: isThunderCloudLikely ? Colors.orange : Colors.green,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                ),
                child: Text(
                  totalScore,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppConstants.fontSizeSmall,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: analysis != null
            ? Text(
                isThunderCloudLikely ? '入道雲の可能性あり' : '入道雲なし',
                style: TextStyle(
                  color: isThunderCloudLikely ? Colors.orange : Colors.green,
                  fontSize: AppConstants.fontSizeSmall,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('分析データなし', style: TextStyle(color: Colors.red)),
                  Text(
                    '利用可能なキー: ${data.keys.toList()}',
                    style: TextStyle(fontSize: AppConstants.fontSizeXSmall, color: Colors.grey[600]),
                  ),
                ],
              ),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 気象データ
                _buildWeatherDataSection(data),

                // 分析結果
                if (analysis != null) ...[
                  const SizedBox(height: AppConstants.paddingMedium),
                  _buildAnalysisSection(analysis),
                ] else ...[
                  const SizedBox(height: AppConstants.paddingMedium),
                  const Text(
                    '分析データが利用できません',
                    style: TextStyle(
                      fontSize: AppConstants.fontSizeSmall,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 気象データセクションを構築
  Widget _buildWeatherDataSection(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '気象データ',
          style: TextStyle(
            fontSize: AppConstants.fontSizeMedium,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        _buildDataRow('CAPE', '${_formatWeatherValue(data['cape'])} J/kg'),
        _buildDataRow('Lifted Index', _formatWeatherValue(data['lifted_index'])),
        _buildDataRow('CIN', '${_formatWeatherValue(data['convective_inhibition'])} J/kg'),
        _buildDataRow('気温', '${_formatWeatherValue(data['temperature'])}°C'),
        _buildDataRow('全雲量', '${_formatWeatherValue(data['cloud_cover'])}%'),
        _buildDataRow('中層雲', '${_formatWeatherValue(data['cloud_cover_mid'])}%'),
        _buildDataRow('高層雲', '${_formatWeatherValue(data['cloud_cover_high'])}%'),
      ],
    );
  }

  /// 分析結果セクションを構築
  Widget _buildAnalysisSection(Map<String, dynamic> analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '入道雲分析結果',
          style: TextStyle(
            fontSize: AppConstants.fontSizeMedium,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        _buildDataRow('総合スコア', '${((analysis['totalScore'] ?? 0) * 100).toStringAsFixed(1)}%'),
        _buildDataRow('リスクレベル', analysis['riskLevel'] ?? 'N/A'),
        const SizedBox(height: AppConstants.paddingSmall),
        const Text(
          '重み',
          style: TextStyle(
            fontSize: AppConstants.fontSizeSmall,
            fontWeight: FontWeight.bold,
          ),
        ),
        _buildDataRow('・CAPE', '0.4', isSubItem: true),
        _buildDataRow('・Lifted Index', '0.3', isSubItem: true),
        _buildDataRow('・CIN', '0.05', isSubItem: true),
        _buildDataRow('・気温', '0.1', isSubItem: true),
        _buildDataRow('・雲量', '0.15', isSubItem: true),
      ],
    );
  }

  /// データ行を構築
  Widget _buildDataRow(String label, String value, {bool isSubItem = false}) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 2,
        left: isSubItem ? AppConstants.paddingSmall : 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isSubItem ? AppConstants.fontSizeXSmall : AppConstants.fontSizeSmall,
              color: isSubItem ? Colors.grey[600] : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isSubItem ? AppConstants.fontSizeXSmall : AppConstants.fontSizeSmall,
              fontWeight: isSubItem ? FontWeight.normal : FontWeight.w500,
              color: isSubItem ? Colors.grey[600] : null,
            ),
          ),
        ],
      ),
    );
  }

  /// 気象値をフォーマット
  String _formatWeatherValue(dynamic value, {int decimals = 1}) {
    if (value == null) return 'N/A';
    if (value is num) {
      return value.toStringAsFixed(decimals);
    }
    return value.toString();
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

  /*
  ================================================================================
                               ヘルパーメソッド
                         エラー表示・メッセージ表示等の補助処理
  ================================================================================
  */

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

  /// 夜間モード（20時〜8時）かどうかを判定
  bool _isNightMode() {
    final now = DateTime.now();
    final hour = now.hour;
    return hour >= 20 || hour < 8;
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
  String? _newAvatarUrl;
  File? _selectedImageFile; // 選択された画像ファイル（アップロード前）
  bool _isUpdatingAvatar = false;
  bool _isSaving = false; // 保存中フラグ

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.currentUserInfo['userName'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// アバター画像を選択（アップロードはしない）
  Future<void> _selectAvatar() async {
    setState(() {
      _isUpdatingAvatar = true;
    });

    try {
      AppLogger.info('アバター画像選択開始', tag: 'ProfileEditDialog');

      // 画像選択
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: AppConstants.imageMaxWidth.toDouble(),
        maxHeight: AppConstants.imageMaxHeight.toDouble(),
        imageQuality: AppConstants.imageQuality,
      );

      if (image == null) {
        AppLogger.info('画像選択がキャンセルされました', tag: 'ProfileEditDialog');
        return;
      }

      // 画像ファイルの存在確認
      final File imageFile = File(image.path);
      if (!await imageFile.exists()) {
        AppLogger.error('選択された画像ファイルが存在しません: ${image.path}', tag: 'ProfileEditDialog');
        _showErrorSnackBar('選択された画像ファイルが見つかりません');
        return;
      }

      // ファイルサイズチェック（5MB制限）
      final int fileSize = await imageFile.length();
      const int maxSize = 5 * 1024 * 1024; // 5MB
      if (fileSize > maxSize) {
        AppLogger.error('画像ファイルサイズが大きすぎます: $fileSize bytes', tag: 'ProfileEditDialog');
        _showErrorSnackBar('画像ファイルサイズが大きすぎます（5MB以下にしてください）');
        return;
      }

      // 選択された画像ファイルを保存（アップロードはしない）
      setState(() {
        _selectedImageFile = imageFile;
      });

      AppLogger.success('アバター画像選択完了: ${imageFile.path}', tag: 'ProfileEditDialog');

    } catch (e) {
      AppLogger.error('アバター画像選択エラー: $e', tag: 'ProfileEditDialog');

      String errorMessage = e.toString().replaceFirst('Exception: ', '');

      // iPadOS 18特有のエラーメッセージを改善
      if (errorMessage.contains('プライバシーとセキュリティ') ||
          errorMessage.contains('permission') ||
          errorMessage.contains('権限')) {
        errorMessage = '写真ライブラリへのアクセスを許可してください。\n設定 > プライバシーとセキュリティ > 写真 > 入道雲サーチ で「すべての写真」または「選択した写真」を選択してください。';
      } else if (errorMessage.contains('デバイスを再起動') ||
                 errorMessage.contains('network') ||
                 errorMessage.contains('connection')) {
        errorMessage = 'ネットワーク接続エラーです。インターネット接続を確認してください。\niPad の場合、まれに画像選択で問題が発生することがあります。デバイスを再起動するか、しばらく時間をおいてからお試しください。';
      } else if (errorMessage.contains('ファイルサイズ')) {
        errorMessage = '画像ファイルサイズが大きすぎます（5MB以下にしてください）';
      } else if (errorMessage.contains('ファイルが見つかりません')) {
        errorMessage = '選択された画像ファイルが見つかりません。別の画像を選択してください。';
      } else if (errorMessage.contains('アップロード権限')) {
        errorMessage = 'アップロード権限がありません。アプリの設定を確認してください。';
      }

      _showErrorSnackBar(errorMessage);
    } finally {
      setState(() {
        _isUpdatingAvatar = false;
      });
    }
  }

  /// アバター画像をアップロード
  Future<String?> _uploadAvatar() async {
    if (_selectedImageFile == null) return null;

    try {
      AppLogger.info('アバター画像アップロード開始', tag: 'ProfileEditDialog');

      // 直接ユーザーIDを取得
      final userId = await AppConstants.getCurrentUserId();

      // 新しいファイルベースのメソッドを使用
      final newAvatarUrl = await UserService.updateUserAvatarWithFile(userId, _selectedImageFile!);

      AppLogger.success('アバター画像アップロード完了: $newAvatarUrl', tag: 'ProfileEditDialog');
      return newAvatarUrl;
    } catch (e) {
      AppLogger.error('アバター画像アップロードエラー: $e', tag: 'ProfileEditDialog');
      rethrow;
    }
  }

  /// エラーメッセージを表示
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

  /// 保存処理
  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });

    try {
      String? finalAvatarUrl = widget.currentUserInfo['avatarUrl'] as String?;

      // 新しい画像が選択されている場合はアップロード
      if (_selectedImageFile != null) {
        finalAvatarUrl = await _uploadAvatar();
        finalAvatarUrl ??= widget.currentUserInfo['avatarUrl'] as String?;
      }

      final updatedInfo = {
        'userName': _nameController.text.trim(),
        'avatarUrl': finalAvatarUrl,
      };

      // mountedチェックを追加してBuildContextの安全性を確保
      if (mounted) {
        Navigator.of(context).pop(updatedInfo);
      }
    } catch (e) {
      AppLogger.error('保存エラー: $e', tag: 'ProfileEditDialog');
      if (mounted) {
        _showErrorSnackBar('保存に失敗しました: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('プロフィール編集'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatarSection(),
            const SizedBox(height: AppConstants.paddingLarge),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'ユーザー名',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _isUpdatingAvatar || _isSaving ? null : _save,
          child: _isSaving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('保存'),
        ),
      ],
    );
  }

  /// アバター画像を表示
  Widget _buildAvatarSection() {
    final currentAvatarUrl = _newAvatarUrl ?? (widget.currentUserInfo['avatarUrl'] as String?);

    return Column(
      children: [
        const Text(
          'アバター画像',
          style: TextStyle(
            fontSize: AppConstants.fontSizeMedium,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        GestureDetector(
          onTap: _isUpdatingAvatar ? null : _selectAvatar,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: _selectedImageFile != null
                    ? FileImage(_selectedImageFile!) // 選択された画像ファイルを優先表示
                    : (currentAvatarUrl != null && currentAvatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(currentAvatarUrl)
                        : null),
                child: _selectedImageFile == null && (currentAvatarUrl == null || currentAvatarUrl.isEmpty)
                    ? const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.grey,
                      )
                    : null,
              ),
              if (_isUpdatingAvatar)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
                ),
              if (!_isUpdatingAvatar)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppConstants.primarySkyBlue,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        Text(
          _selectedImageFile != null
              ? '新しい画像を選択済み（保存ボタンで確定）'
              : 'タップして画像を選択',
          style: TextStyle(
            fontSize: AppConstants.fontSizeSmall,
            color: _selectedImageFile != null
                ? AppConstants.primarySkyBlue
                : Colors.grey[600],
            fontWeight: _selectedImageFile != null
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
