import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/location/location_service.dart';
import '../services/photo/user_service.dart';
import '../services/weather/weather_cache_service.dart';

class SettingsScreen extends StatefulWidget {
  final LatLng? currentLocation;

  const SettingsScreen({
    super.key,
    this.currentLocation,
  });

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  final WeatherCacheService _cacheService = WeatherCacheService();
  Map<String, dynamic> _weatherData = {};
  LatLng? _currentLocation;
  bool _isLoading = false;
  bool _isLoadingUserInfo = true;
  DateTime? _lastUpdateTime;
  Timer? _updateTimer;
  StreamSubscription? _realtimeSubscription;

  // ユーザー情報
  final String _currentUserId = 'user_001';
  Map<String, dynamic> _userInfo = {};

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _loadUserInfo();
    _startPeriodicMonitoring(); // 定期監視を開始
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _realtimeSubscription?.cancel(); // リアルタイム監視を停止
    super.dispose();
  }

  /// 定期的な監視を開始
  void _startPeriodicMonitoring() {
    print("🔄 定期的なFirestore監視を開始（30秒間隔）");

    _updateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_currentLocation != null && mounted) {
        print("⏰ 定期チェック実行中...");
        _fetchWeatherData(isPeriodicCheck: true);
      }
    });
  }

  /// リアルタイム監視を開始
  void _startRealtimeMonitoring() {
    if (_currentLocation == null) return;

    print("📡 Firestoreリアルタイム監視を開始");

    _realtimeSubscription = _cacheService.watchWeatherData(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
    ).listen(
      (weatherData) {
        if (weatherData != null && mounted) {
          print("🔄 リアルタイム更新: データを受信");
          setState(() {
            _weatherData = weatherData;
            _lastUpdateTime = DateTime.now();
          });
        }
      },
      onError: (error) {
        print("❌ リアルタイム監視エラー: $error");
      },
    );
  }

  /// 位置情報を初期化
  Future<void> _initializeLocation() async {
    try {
      if (widget.currentLocation != null) {
        _currentLocation = widget.currentLocation;
      } else {
        final location = await LocationService.getCurrentLocationAsLatLng();
        if (location != null) {
          _currentLocation = location;
        }
      }

      if (_currentLocation != null) {
        await _fetchWeatherData();
        _startRealtimeMonitoring(); // リアルタイム監視を開始
      }
    } catch (e) {
      print("❌ 位置情報初期化エラー: $e");
    }
  }

  /// Firestoreから気象データを取得
  Future<void> _fetchWeatherData({bool isPeriodicCheck = false}) async {
    if (_currentLocation == null) return;

    // 定期チェックの場合はローディング表示しない
    if (!isPeriodicCheck && !_isLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      if (isPeriodicCheck) {
        print("🌐 定期チェック: Firestoreから気象データ取得");
      } else {
        print("🌐 Firestoreから気象データ取得開始");
      }

      final weatherData = await _cacheService.getWeatherDataWithCache(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );

      if (weatherData != null && mounted) {
        setState(() {
          _weatherData = weatherData;
          _lastUpdateTime = DateTime.now();
          if (!isPeriodicCheck) _isLoading = false;
        });
        print("✅ 気象データ取得成功");
      } else {
        print("⚠️ Firestoreにデータが見つかりません。Firebase Functionsに新規取得をリクエスト中...");
        await _requestNewDataFromFunctions();
      }
    } catch (e) {
      print("❌ 気象データ取得エラー: $e");
      if (mounted && !isPeriodicCheck) {
        setState(() {
          _isLoading = false;
        });

        // エラーメッセージを表示（定期チェックの場合は表示しない）
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('気象データの取得に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Firebase Functionsに新しい位置の気象データをリクエスト
  Future<void> _requestNewDataFromFunctions() async {
    if (_currentLocation == null) return;

    try {
      print("🌐 Firebase Functionsに新規データをリクエスト中...");

      // Firebase FunctionsのgetWeatherData APIを呼び出し
      final uri = Uri.parse(
        'https://us-central1-thunder-cloud-app-292e6.cloudfunctions.net/getWeatherData'
        '?latitude=${_currentLocation!.latitude}&longitude=${_currentLocation!.longitude}'
      );

      final response = await HttpClient().getUrl(uri).then((request) => request.close());

      if (response.statusCode == 200) {
        print("✅ Firebase Functionsから新規データ取得成功");

        // 少し待ってから再度Firestoreをチェック
        await Future.delayed(const Duration(seconds: 2));

        final weatherData = await _cacheService.getWeatherDataWithCache(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
        );

        if (weatherData != null && mounted) {
          setState(() {
            _weatherData = weatherData;
            _lastUpdateTime = DateTime.now();
          });
          print("✅ 新規データをFirestoreから取得完了");
        }
      } else {
        print("❌ Firebase Functions呼び出し失敗: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Firebase Functions呼び出しエラー: $e");
    }
  }

  /// ユーザー情報を読み込み
  Future<void> _loadUserInfo() async {
    try {
      print('👤 ユーザー情報読み込み開始 - ユーザーID: $_currentUserId');
      final userInfo = await UserService.getUserInfo(_currentUserId);
      setState(() {
        _userInfo = userInfo;
        _isLoadingUserInfo = false;
      });
      print('✅ ユーザー情報読み込み完了: ${userInfo['userName']}');
    } catch (e) {
      print('❌ ユーザー情報読み込みエラー: $e');
      setState(() {
        _isLoadingUserInfo = false;
      });
    }
  }

  /// プロフィール編集ダイアログを表示
  void _showProfileEditDialog() async {
    try {
      // 最新のユーザー情報を取得
      final userInfo = await UserService.getUserInfo(_currentUserId);

      if (mounted) {
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => ProfileEditDialog(
            currentUserInfo: userInfo,
            userId: _currentUserId,
            onProfileUpdated: () {
              _loadUserInfo(); // ユーザー情報を再読み込み
            },
          ),
        );

        // プロフィールが更新された場合、設定画面を閉じて更新を通知
        if (result == true && mounted) {
          Navigator.pop(context, true); // 設定画面を閉じて更新を通知
        }
      }
    } catch (e) {
      print('❌ ユーザー情報取得エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ユーザー情報の取得に失敗しました')),
        );
      }
    }
  }

  /// 方向名を日本語に変換
  String _getDirectionName(String direction) {
    switch (direction) {
      case 'north':
        return '北';
      case 'south':
        return '南';
      case 'east':
        return '東';
      case 'west':
        return '西';
      default:
        return direction;
    }
  }

  /// リスクレベルに応じた色を取得
  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green.shade400;
      case 'none':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  /// リスクレベルに応じた文字色を取得
  Color _getRiskTextColor(String riskLevel) {
    switch (riskLevel) {
      case 'high':
        return Colors.white;
      case 'medium':
        return Colors.white;
      case 'low':
        return Colors.white;
      case 'none':
        return Colors.white;
      default:
        return Colors.white;
    }
  }

  /// リスクレベルを日本語に変換
  String _getRiskLevelText(String riskLevel) {
    switch (riskLevel) {
      case 'high':
        return '高い';
      case 'medium':
        return '中程度';
      case 'low':
        return '低い';
      case 'none':
        return '極めて低い';
      default:
        return riskLevel;
    }
  }

  /// 最終更新時刻をフォーマット
  String _formatUpdateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.analytics_outlined,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              '気象データ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 135, 206, 250), // 空色（Sky Blue）
        foregroundColor: Colors.white, // アイコンと戻るボタンも白色に
        elevation: 3,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final weatherData = _weatherData;
    final lastUpdate = _lastUpdateTime;
    final lastLocation = _currentLocation;

    return Column(
      children: [
        // プロフィールセクション
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 20,
                    color: Color.fromRGBO(135, 206, 250, 1.0),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'プロフィール',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _isLoadingUserInfo
                  ? const Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('ユーザー情報読み込み中...'),
                      ],
                    )
                  : Row(
                      children: [
                        // アバター画像
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: const Color.fromRGBO(135, 206, 250, 1.0),
                          backgroundImage: _userInfo['avatarUrl'] != null && _userInfo['avatarUrl'].isNotEmpty
                              ? CachedNetworkImageProvider(_userInfo['avatarUrl'])
                              : null,
                          child: _userInfo['avatarUrl'] == null || _userInfo['avatarUrl'].isEmpty
                              ? Text(
                                  _userInfo['userName']?.substring(0, 1).toUpperCase() ?? 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        // ユーザー情報
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userInfo['userName'] ?? 'ユーザー',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ユーザーID: $_currentUserId',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 編集ボタン
                        Column(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _showProfileEditDialog,
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('編集'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromRGBO(135, 206, 250, 1.0),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ],
          ),
        ),

        // 区切り線
        Container(
          height: 1,
          color: Colors.grey[300],
        ),

        // ヘッダー情報
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: const Color.fromARGB(255, 240, 248, 255), // より薄い空色
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 20,
                    color: Color.fromRGBO(135, 206, 250, 1.0),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '気象データ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    _isLoading ? Icons.sync : Icons.location_on,
                    size: 16,
                    color: _isLoading ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: lastLocation != null
                        ? Text(
                  '監視地点: ${lastLocation.latitude.toStringAsFixed(2)}, ${lastLocation.longitude.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                )
                        : const Text(
                  '監視地点: 未設定',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
              if (lastUpdate != null)
                Text(
                  '最終更新: ${_formatUpdateTime(lastUpdate)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                )
              else
                const Text(
                  '最終更新: データなし',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  const Spacer(),
                  if (_isLoading)
                    const Text(
                      '更新中...',
                      style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                ],
                ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.orange,
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'データはFirebase Functionsで自動取得され、Firestoreから読み取られます',
                style: TextStyle(fontSize: 11, color: Colors.orange),
              ),
                  ),
                ],
              ),

            ],
          ),
        ),

        // 気象データ表示
        Expanded(
          child: weatherData.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '気象データがまだ取得されていません',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Firebase Functionsによる自動更新をお待ちください',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : _buildWeatherDataView(weatherData),
        ),
      ],
    );
  }

  Widget _buildWeatherDataView(Map<String, dynamic> weatherData) {
    // 単一地点のデータの場合
    if (weatherData.containsKey('cape') && weatherData.containsKey('analysis')) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _buildSingleWeatherCard(weatherData),
      );
    }

    // 複数方向のデータの場合
    if (weatherData.keys.any((key) => ['north', 'south', 'east', 'west'].contains(key))) {
      return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: weatherData.length,
                  itemBuilder: (context, index) {
                    final direction = weatherData.keys.elementAt(index);
          final data = weatherData[direction] as Map<String, dynamic>;
                    return _buildWeatherCard(direction, data);
                  },
      );
    }

    return const Center(
      child: Text(
        'データ形式が認識できません',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  Widget _buildSingleWeatherCard(Map<String, dynamic> data) {
    final analysis = data['analysis'] as Map<String, dynamic>;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '現在地の気象データ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRiskColor(analysis['riskLevel']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getRiskLevelText(analysis['riskLevel']),
                    style: TextStyle(
                      color: _getRiskTextColor(analysis['riskLevel']),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 分析結果
            Row(
              children: [
                Icon(
                  analysis['isLikely'] ? Icons.warning : Icons.check_circle,
                  color: analysis['isLikely'] ? Colors.orange : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  analysis['isLikely'] ? '入道雲の可能性あり' : '入道雲なし',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: analysis['isLikely'] ? Colors.orange : Colors.green,
                  ),
                ),
                const Spacer(),
                Text(
                  'スコア: ${((analysis['totalScore'] ?? 0) * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 気象データ
            _buildDataGrid(data),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherCard(String direction, Map<String, dynamic> data) {
    final analysis = data['analysis'] as Map<String, dynamic>;
    final coordinates = data['coordinates'] as Map<String, dynamic>;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_getDirectionName(direction)}方向',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRiskColor(analysis['riskLevel']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getRiskLevelText(analysis['riskLevel']),
                    style: TextStyle(
                      color: _getRiskTextColor(analysis['riskLevel']),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 座標情報
            Text(
              '座標: ${coordinates['lat'].toStringAsFixed(2)}, ${coordinates['lon'].toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // 分析結果
            Row(
              children: [
                Icon(
                  analysis['isLikely'] ? Icons.warning : Icons.check_circle,
                  color: analysis['isLikely'] ? Colors.orange : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  analysis['isLikely'] ? '入道雲の可能性あり' : '入道雲なし',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: analysis['isLikely'] ? Colors.orange : Colors.green,
                  ),
                ),
                const Spacer(),
                Text(
                  'スコア: ${((analysis['totalScore'] ?? 0) * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 気象データ
            _buildDataGrid(data),
          ],
        ),
      ),
    );
  }

  Widget _buildDataGrid(Map<String, dynamic> data) {
    return Column(
      children: [
        Row(
          children: [
            _buildDataItem('CAPE', '${(data['cape'] ?? 0).toStringAsFixed(1)} J/kg'),
            _buildDataItem('温度', '${(data['temperature'] ?? 0).toStringAsFixed(1)}°C'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildDataItem('LI', (data['lifted_index'] ?? 0).toStringAsFixed(1)),
            _buildDataItem('CIN', '${(data['convective_inhibition'] ?? 0).toStringAsFixed(1)} J/kg'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildDataItem('全雲量', '${(data['cloud_cover'] ?? 0).toStringAsFixed(1)}%'),
            _buildDataItem('中層雲', '${(data['cloud_cover_mid'] ?? 0).toStringAsFixed(1)}%'),
          ],
        ),
      ],
    );
  }

  Widget _buildDataItem(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

/// プロフィール編集ダイアログ
class ProfileEditDialog extends StatefulWidget {
  final Map<String, dynamic> currentUserInfo;
  final String userId;
  final VoidCallback onProfileUpdated;

  const ProfileEditDialog({
    super.key,
    required this.currentUserInfo,
    required this.userId,
    required this.onProfileUpdated,
  });

  @override
  State<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<ProfileEditDialog> {
  late TextEditingController _nameController;
  bool _isUpdating = false;
  String _currentAvatarUrl = '';
  bool _hasUpdated = false; // プロフィール更新フラグ

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.currentUserInfo['userName'] ?? 'ユーザー',
    );
    _currentAvatarUrl = widget.currentUserInfo['avatarUrl'] ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// アバター画像を更新
  Future<void> _updateAvatar() async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final success = await UserService.updateUserAvatar(widget.userId);
      if (success) {
        // 最新のユーザー情報を取得
        final updatedInfo = await UserService.getUserInfo(widget.userId);
        setState(() {
          _currentAvatarUrl = updatedInfo['avatarUrl'] ?? '';
          _hasUpdated = true; // 更新フラグを設定
        });

        // プロフィール更新通知
        widget.onProfileUpdated();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('アバター画像を更新しました'),
                ],
              ),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('アバター更新エラー: $e')),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  /// ユーザー名を更新
  Future<void> _updateUserName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('名前を入力してください'),
            ],
          ),
          backgroundColor: Colors.orange[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final success = await UserService.updateUserName(widget.userId, newName);
      if (success) {
        widget.onProfileUpdated();
        if (mounted) {
          Navigator.pop(context, true); // 更新成功を通知
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('プロフィールを更新しました'),
                ],
              ),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('プロフィール更新に失敗しました'),
                ],
              ),
              backgroundColor: Colors.red[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('更新エラー: $e')),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasUpdated);
        return false;
      },
      child: AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.edit, color: Color.fromRGBO(135, 206, 250, 1.0), size: 24),
          SizedBox(width: 8),
          Text('プロフィール編集', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // アバター画像
            GestureDetector(
              onTap: _isUpdating ? null : _updateAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color.fromRGBO(135, 206, 250, 1.0),
                    backgroundImage: _currentAvatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(_currentAvatarUrl)
                        : null,
                    child: _currentAvatarUrl.isEmpty
                        ? Text(
                            _nameController.text.isNotEmpty
                                ? _nameController.text.substring(0, 1).toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  if (_isUpdating)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(135, 206, 250, 1.0),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'アバター画像をタップして変更',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // ユーザー名入力
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'ユーザー名',
                hintText: 'ユーザー名を入力してください',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color.fromRGBO(135, 206, 250, 1.0), width: 2),
                ),
              ),
              maxLength: 20,
              enabled: !_isUpdating,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUpdating ? null : () => Navigator.pop(context, _hasUpdated),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _isUpdating ? null : _updateUserName,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(135, 206, 250, 1.0),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isUpdating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    ),
    );
  }
}