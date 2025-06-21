import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/weather/weather_data_service.dart';

class SettingsScreen extends StatefulWidget {
  final LatLng? currentLocation;

  const SettingsScreen({super.key, this.currentLocation});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final WeatherDataService _weatherService = WeatherDataService.instance;
  Timer? _updateTimer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startAutoUpdate();
    // WeatherDataServiceの変更を監視
    _weatherService.addListener(_onWeatherDataChanged);
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _weatherService.removeListener(_onWeatherDataChanged);
    super.dispose();
  }

  /// WeatherDataServiceの変更を監視するリスナー
  void _onWeatherDataChanged() {
    if (mounted) {
      setState(() {
        // UIを更新
      });
    }
  }

  /// 自動更新を開始
  void _startAutoUpdate() {
    // 30秒ごとに気象データを更新
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && widget.currentLocation != null) {
        _autoRefreshWeatherData();
      }
    });
  }

  /// 自動で気象データを更新（ユーザー操作不可）
  Future<void> _autoRefreshWeatherData() async {
    if (widget.currentLocation == null || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _weatherService.fetchAndStoreWeatherData(widget.currentLocation!);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("❌ 気象データ自動更新エラー: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.yellow;
      default:
        return Colors.grey;
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
    final weatherData = _weatherService.lastWeatherData;
    final lastUpdate = _weatherService.lastUpdateTime;
    final lastLocation = _weatherService.lastLocation;

    return Column(
      children: [
        // ヘッダー情報
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: const Color.fromARGB(255, 240, 248, 255), // より薄い空色
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                            '監視地点: ${lastLocation.latitude.toStringAsFixed(4)}, ${lastLocation.longitude.toStringAsFixed(4)}',
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
                      'データは30秒ごとに自動更新されます（手動更新不可）',
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
                        'しばらくお待ちください',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: weatherData.length,
                  itemBuilder: (context, index) {
                    final direction = weatherData.keys.elementAt(index);
                    final data = weatherData[direction]!;
                    return _buildWeatherCard(direction, data);
                  },
                ),
        ),
      ],
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
                    analysis['riskLevel'],
                    style: const TextStyle(
                      color: Colors.white,
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
              '座標: ${coordinates['lat'].toStringAsFixed(4)}, ${coordinates['lon'].toStringAsFixed(4)}',
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
                  'スコア: ${(analysis['totalScore'] * 100).toStringAsFixed(1)}%',
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
            _buildDataItem('CAPE', '${data['cape'].toStringAsFixed(1)} J/kg'),
            _buildDataItem('温度', '${data['temperature'].toStringAsFixed(1)}°C'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildDataItem('LI', data['lifted_index'].toStringAsFixed(1)),
            _buildDataItem('CIN', '${data['convective_inhibition'].toStringAsFixed(1)} J/kg'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildDataItem('全雲量', '${data['cloud_cover'].toStringAsFixed(1)}%'),
            _buildDataItem('中層雲', '${data['cloud_cover_mid'].toStringAsFixed(1)}%'),
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