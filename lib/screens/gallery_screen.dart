import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/photo.dart';
import '../services/photo/local_photo_service.dart';
import '../services/photo/photo_service.dart';
import '../services/photo/user_service.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> with SingleTickerProviderStateMixin {
  List<Photo> _photos = [];
  List<Map<String, dynamic>> _downloadedPhotos = [];
  bool _isLoading = true;
  bool _isLoadingDownloaded = true;
  bool _isGridView = true;
  final Set<String> _selectedPhotos = {};
  final Set<String> _selectedDownloaded = {};
  bool _isSelectionMode = false;
  final String _currentUserId = 'user_001'; // カメラ画面と同じユーザーID

  // ユーザー情報
  Map<String, dynamic> _userInfo = {};
  bool _isLoadingUserInfo = true;

  // タブ機能
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadUserInfo();
    _loadPhotos();
    _loadDownloadedPhotos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 外部から呼び出し可能なデータ再読み込みメソッド
  void refreshData() {
    print('🔄 ギャラリーデータ再読み込み開始');
    _loadUserInfo();
    _loadPhotos();
    _loadDownloadedPhotos();
  }

  void _onTabChanged() {
    setState(() {
      _currentTabIndex = _tabController.index;
      _isSelectionMode = false;
      _selectedPhotos.clear();
      _selectedDownloaded.clear();
    });
  }

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

  Future<void> _loadPhotos() async {
    try {
      print('📱 ローカルギャラリー写真読み込み開始 - ユーザーID: $_currentUserId');
      setState(() {
        _isLoading = true;
      });

      // ローカルストレージから写真を取得
      final photos = await LocalPhotoService.getUserLocalPhotos(_currentUserId);
      print('📊 取得したローカル写真数: ${photos.length}');

      setState(() {
        _photos = photos;
        _isLoading = false;
      });
      print('✅ ローカルギャラリー写真読み込み完了: ${photos.length}件');
    } catch (e) {
      print('❌ ローカル写真読み込みエラー: $e');
      print('❌ エラータイプ: ${e.runtimeType}');
      print('❌ スタックトレース: ${StackTrace.current}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDownloadedPhotos() async {
    try {
      print('📥 ダウンロード済み写真読み込み開始 - ユーザーID: $_currentUserId');
      setState(() {
        _isLoadingDownloaded = true;
      });

      final downloadedPhotos = await PhotoService.getDownloadedPhotos(_currentUserId);
      print('📊 取得したダウンロード済み写真数: ${downloadedPhotos.length}');

      setState(() {
        _downloadedPhotos = downloadedPhotos;
        _isLoadingDownloaded = false;
      });
      print('✅ ダウンロード済み写真読み込み完了: ${downloadedPhotos.length}件');
    } catch (e) {
      print('❌ ダウンロード済み写真読み込みエラー: $e');
      setState(() {
        _isLoadingDownloaded = false;
      });
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedPhotos.clear();
        _selectedDownloaded.clear();
      }
    });
  }

  Future<void> _deleteSelectedPhotos() async {
    try {
      for (String photoId in _selectedPhotos) {
        await LocalPhotoService.deleteLocalPhoto(photoId, _currentUserId);
      }

      setState(() {
        _photos.removeWhere((photo) => _selectedPhotos.contains(photo.id));
        _selectedPhotos.clear();
        _isSelectionMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('選択した写真を削除しました')),
        );
      }
    } catch (e) {
      print('❌ 写真削除エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _deleteSelectedDownloadedPhotos() async {
    try {
      for (String downloadId in _selectedDownloaded) {
        await PhotoService.deleteDownloadedPhoto(downloadId, _currentUserId);
      }

      setState(() {
        _downloadedPhotos.removeWhere((photo) => _selectedDownloaded.contains(photo['id']));
        _selectedDownloaded.clear();
        _isSelectionMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('選択したダウンロード済み写真を削除しました')),
        );
      }
    } catch (e) {
      print('❌ ダウンロード済み写真削除エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _sharePhoto(Photo photo) async {
    try {
      await Share.share(
        '入道雲を撮影しました！\n'
        '撮影日時: ${_formatDateTime(photo.timestamp)}\n'
        '画像: ${photo.imageUrl}',
        subject: '入道雲写真',
      );
    } catch (e) {
      print('❌ 共有エラー: $e');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 写真の表示ウィジェットを構築（ローカル/ネットワーク対応）
  Widget _buildPhotoImage(Photo photo) {
    // ローカルファイルかどうかを判定（パスが'/'で始まる場合はローカル）
    final isLocalFile = photo.imageUrl.startsWith('/');

    if (isLocalFile) {
      // ローカルファイルの場合
      final file = File(photo.imageUrl);
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(Icons.error),
          );
        },
      );
    } else {
      // ネットワーク画像の場合
      return CachedNetworkImage(
        imageUrl: photo.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: const Icon(Icons.error),
        ),
      );
    }
  }

  Widget _buildDownloadedPhotoImage(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => Container(
        color: Colors.grey[300],
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[300],
        child: const Icon(Icons.error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ギャラリー',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 135, 206, 250),
        foregroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black54,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'マイ写真'),
            Tab(text: 'ダウンロード済み'),
          ],
        ),
        actions: [
          if (_currentTabIndex == 0 && _photos.isNotEmpty) ...[ // マイ写真タブのみ
            IconButton(
              icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
              onPressed: () {
                setState(() {
                  _isGridView = !_isGridView;
                });
              },
            ),
            IconButton(
              icon: Icon(_isSelectionMode ? Icons.close : Icons.select_all),
              onPressed: _toggleSelectionMode,
            ),
          ],
          if (_currentTabIndex == 1 && _downloadedPhotos.isNotEmpty) ...[ // ダウンロード済みタブのみ
            IconButton(
              icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
              onPressed: () {
                setState(() {
                  _isGridView = !_isGridView;
                });
              },
            ),
            IconButton(
              icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist),
              onPressed: _toggleSelectionMode,
              tooltip: _isSelectionMode ? '選択を終了' : '写真を選択',
            ),
          ],
          if (_isSelectionMode && ((_currentTabIndex == 0 && _selectedPhotos.isNotEmpty) || (_currentTabIndex == 1 && _selectedDownloaded.isNotEmpty)))
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('削除確認'),
                    content: Text(
                      _currentTabIndex == 0
                        ? '選択した${_selectedPhotos.length}枚の写真を削除しますか？'
                        : '選択した${_selectedDownloaded.length}枚のダウンロード済み写真を削除しますか？'
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('キャンセル'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (_currentTabIndex == 0) {
                            _deleteSelectedPhotos();
                          } else {
                            _deleteSelectedDownloadedPhotos();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('削除'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyPhotosTab(),
          _buildDownloadedPhotosTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildMyPhotosTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_photos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '写真がありません',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'カメラで写真を撮影してみましょう',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return _isGridView ? _buildGridView(_photos, true) : _buildListView(_photos, true);
  }

  Widget _buildDownloadedPhotosTab() {
    if (_isLoadingDownloaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_downloadedPhotos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'ダウンロード済み写真がありません',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'コミュニティから写真をダウンロードしてみましょう',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return _isGridView ? _buildDownloadedGridView() : _buildDownloadedListView();
  }

  Widget _buildGridView(List<Photo> photos, bool isMyPhotos) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        final isSelected = isMyPhotos ? _selectedPhotos.contains(photo.id) : false;

        return GestureDetector(
          onTap: () {
            if (_isSelectionMode) {
              setState(() {
                if (isSelected) {
                  _selectedPhotos.remove(photo.id);
                } else {
                  _selectedPhotos.add(photo.id);
                }
              });
            } else {
              _showPhotoDetail(photo);
            }
          },
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: isSelected
                    ? Border.all(color: Colors.blue, width: 3)
                    : null,
                ),
                child: _buildPhotoImage(photo),
              ),
              if (_isSelectionMode)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isSelected ? Icons.check : null,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListView(List<Photo> photos, bool isMyPhotos) {
    return ListView.builder(
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        final isSelected = isMyPhotos ? _selectedPhotos.contains(photo.id) : false;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    border: isSelected
                      ? Border.all(color: Colors.blue, width: 2)
                      : null,
                  ),
                  child: _buildPhotoImage(photo),
                ),
                if (_isSelectionMode)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey),
                      ),
                      child: Icon(
                        isSelected ? Icons.check : null,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
            title: const Text('撮影地点'),
            subtitle: Text(
              '${photo.timestamp.year}/${photo.timestamp.month}/${photo.timestamp.day} '
              '${photo.timestamp.hour.toString().padLeft(2, '0')}:'
              '${photo.timestamp.minute.toString().padLeft(2, '0')}',
            ),
            onTap: () {
              if (_isSelectionMode) {
                setState(() {
                  if (isSelected) {
                    _selectedPhotos.remove(photo.id);
                  } else {
                    _selectedPhotos.add(photo.id);
                  }
                });
              } else {
                _showPhotoDetail(photo);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildDownloadedGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _downloadedPhotos.length,
      itemBuilder: (context, index) {
        final photoData = _downloadedPhotos[index];
        final photoId = photoData['photoId'] as String;
        final isSelected = _selectedDownloaded.contains(photoId);

        return GestureDetector(
          onTap: () {
            if (_isSelectionMode) {
              setState(() {
                if (isSelected) {
                  _selectedDownloaded.remove(photoId);
                } else {
                  _selectedDownloaded.add(photoId);
                }
              });
            } else {
              _showDownloadedPhotoDetail(photoData);
            }
          },
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: isSelected
                    ? Border.all(color: Colors.blue, width: 3)
                    : null,
                ),
                child: _buildDownloadedPhotoImage(photoData['imageUrl'] as String),
              ),
              if (_isSelectionMode)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isSelected ? Icons.check : null,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDownloadedListView() {
    return ListView.builder(
      itemCount: _downloadedPhotos.length,
      itemBuilder: (context, index) {
        final photoData = _downloadedPhotos[index];
        final photoId = photoData['photoId'] as String;
        final isSelected = _selectedDownloaded.contains(photoId);
        final timestamp = (photoData['timestamp'] as Timestamp).toDate();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    border: isSelected
                      ? Border.all(color: Colors.blue, width: 2)
                      : null,
                  ),
                  child: _buildDownloadedPhotoImage(photoData['imageUrl'] as String),
                ),
                if (_isSelectionMode)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isSelected ? Icons.check : null,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
            title: Text('${photoData['userName']} の写真'),
            subtitle: Text(
              '${timestamp.year}/${timestamp.month}/${timestamp.day} '
              '${timestamp.hour.toString().padLeft(2, '0')}:'
              '${timestamp.minute.toString().padLeft(2, '0')}',
            ),
            onTap: () {
              if (_isSelectionMode) {
                setState(() {
                  if (isSelected) {
                    _selectedDownloaded.remove(photoId);
                  } else {
                    _selectedDownloaded.add(photoId);
                  }
                });
              } else {
                _showDownloadedPhotoDetail(photoData);
              }
            },
          ),
        );
      },
    );
  }

  void _showPhotoDetail(Photo photo) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('写真詳細画面は準備中です')),
    );
  }

  void _showDownloadedPhotoDetail(Map<String, dynamic> photoData) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ダウンロード済み写真詳細画面は準備中です')),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(135, 206, 250, 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavButton(
                context,
                icon: Icons.map,
                label: '地図',
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/weather');
                },
              ),
              _buildNavButton(
                context,
                icon: Icons.photo_library,
                label: 'ギャラリー',
                onTap: () {
                  // 現在のページなので何もしない
                },
                isActive: true,
              ),
              _buildNavButton(
                context,
                icon: Icons.people,
                label: 'コミュニティ',
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/community');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// GalleryScreenのコンテンツ部分のみ（Scaffold不要版）
class GalleryScreenContent extends StatefulWidget {
  const GalleryScreenContent({super.key});

  @override
  State<GalleryScreenContent> createState() => _GalleryScreenContentState();
}

class _GalleryScreenContentState extends State<GalleryScreenContent> with SingleTickerProviderStateMixin {
  List<Photo> _photos = [];
  List<Map<String, dynamic>> _downloadedPhotos = [];
  bool _isLoading = true;
  bool _isLoadingDownloaded = true;
  bool _isGridView = true;
  final Set<String> _selectedPhotos = {};
  final Set<String> _selectedDownloaded = {};
  bool _isSelectionMode = false;
  final String _currentUserId = 'user_001'; // カメラ画面と同じユーザーID

  // ユーザー情報
  Map<String, dynamic> _userInfo = {};
  bool _isLoadingUserInfo = true;

  // タブ機能
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadUserInfo();
    _loadPhotos();
    _loadDownloadedPhotos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 外部から呼び出し可能なデータ再読み込みメソッド
  void refreshData() {
    print('🔄 ギャラリーデータ再読み込み開始');
    _loadUserInfo(); // ユーザー情報を再読み込み（アバター更新反映のため）
    _loadPhotos();
    _loadDownloadedPhotos();
  }

  void _onTabChanged() {
    setState(() {
      _currentTabIndex = _tabController.index;
      _isSelectionMode = false;
      _selectedPhotos.clear();
      _selectedDownloaded.clear();
    });
  }

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

  Future<void> _loadPhotos() async {
    try {
      print('📱 ローカルギャラリー写真読み込み開始 - ユーザーID: $_currentUserId');
      setState(() {
        _isLoading = true;
      });

      // ローカルストレージから写真を取得
      final photos = await LocalPhotoService.getUserLocalPhotos(_currentUserId);
      print('📊 取得したローカル写真数: ${photos.length}');

      setState(() {
        _photos = photos;
        _isLoading = false;
      });
      print('✅ ローカルギャラリー写真読み込み完了: ${photos.length}件');
    } catch (e) {
      print('❌ ローカル写真読み込みエラー: $e');
      print('❌ エラータイプ: ${e.runtimeType}');
      print('❌ スタックトレース: ${StackTrace.current}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDownloadedPhotos() async {
    try {
      print('📥 ダウンロード済み写真読み込み開始 - ユーザーID: $_currentUserId');
      setState(() {
        _isLoadingDownloaded = true;
      });

      final downloadedPhotos = await PhotoService.getDownloadedPhotos(_currentUserId);
      print('📊 取得したダウンロード済み写真数: ${downloadedPhotos.length}');

      setState(() {
        _downloadedPhotos = downloadedPhotos;
        _isLoadingDownloaded = false;
      });
      print('✅ ダウンロード済み写真読み込み完了: ${downloadedPhotos.length}件');
    } catch (e) {
      print('❌ ダウンロード済み写真読み込みエラー: $e');
      setState(() {
        _isLoadingDownloaded = false;
      });
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedPhotos.clear();
        _selectedDownloaded.clear();
      }
    });
  }

  Future<void> _deleteSelectedPhotos() async {
    try {
      for (String photoId in _selectedPhotos) {
        await LocalPhotoService.deleteLocalPhoto(photoId, _currentUserId);
      }

      setState(() {
        _photos.removeWhere((photo) => _selectedPhotos.contains(photo.id));
        _selectedPhotos.clear();
        _isSelectionMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('選択した写真を削除しました')),
        );
      }
    } catch (e) {
      print('❌ 写真削除エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _deleteSelectedDownloadedPhotos() async {
    try {
      for (String downloadId in _selectedDownloaded) {
        await PhotoService.deleteDownloadedPhoto(downloadId, _currentUserId);
      }

      setState(() {
        _downloadedPhotos.removeWhere((photo) => _selectedDownloaded.contains(photo['id']));
        _selectedDownloaded.clear();
        _isSelectionMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('選択したダウンロード済み写真を削除しました')),
        );
      }
    } catch (e) {
      print('❌ ダウンロード済み写真削除エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _sharePhoto(Photo photo) async {
    try {
      await Share.share(
        '入道雲を撮影しました！\n'
        '撮影日時: ${_formatDateTime(photo.timestamp)}\n'
        '画像: ${photo.imageUrl}',
        subject: '入道雲写真',
      );
    } catch (e) {
      print('❌ 共有エラー: $e');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 写真の表示ウィジェットを構築（ローカル/ネットワーク対応）
  Widget _buildPhotoImage(Photo photo) {
    // ローカルファイルかどうかを判定（パスが'/'で始まる場合はローカル）
    final isLocalFile = photo.imageUrl.startsWith('/');

    if (isLocalFile) {
      // ローカルファイルの場合
      final file = File(photo.imageUrl);
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(Icons.error),
          );
        },
      );
    } else {
      // ネットワーク画像の場合
      return CachedNetworkImage(
        imageUrl: photo.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: const Icon(Icons.error),
        ),
      );
    }
  }

  Widget _buildDownloadedPhotoImage(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => Container(
        color: Colors.grey[300],
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[300],
        child: const Icon(Icons.error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ユーザー情報ヘッダー
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(135, 206, 250, 0.1),
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: _isLoadingUserInfo
              ? const Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('ユーザー情報を読み込み中...'),
                  ],
                )
              : Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: const Color.fromRGBO(135, 206, 250, 1.0),
                      backgroundImage: _userInfo['avatarUrl'] != null && _userInfo['avatarUrl'].isNotEmpty
                          ? CachedNetworkImageProvider(_userInfo['avatarUrl'])
                          : null,
                      child: _userInfo['avatarUrl'] == null || _userInfo['avatarUrl'].isEmpty
                          ? Text(
                              _userInfo['userName']?.substring(0, 1).toUpperCase() ?? 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userInfo['userName'] ?? 'ユーザー',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '写真: ${_photos.length}枚 | ダウンロード: ${_downloadedPhotos.length}枚',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),

        // タブバー
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'マイ写真', icon: Icon(Icons.photo_library)),
            Tab(text: 'ダウンロード', icon: Icon(Icons.download)),
          ],
          labelColor: const Color.fromRGBO(135, 206, 250, 1.0),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color.fromRGBO(135, 206, 250, 1.0),
        ),

        // コンテンツ
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMyPhotosTab(),
              _buildDownloadedPhotosTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyPhotosTab() {
    return Column(
      children: [
        // ツールバー
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                '${_photos.length}枚の写真',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_isSelectionMode) ...[
                TextButton(
                  onPressed: _selectedPhotos.isEmpty ? null : _deleteSelectedPhotos,
                  child: Text(
                    '削除 (${_selectedPhotos.length})',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _toggleSelectionMode,
                  child: const Text('キャンセル'),
                ),
              ] else ...[
                IconButton(
                  icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
                  onPressed: () {
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
                ),
                IconButton(
                  icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist),
                  onPressed: _photos.isEmpty ? null : _toggleSelectionMode,
                  tooltip: _isSelectionMode ? '選択を終了' : '写真を選択',
                ),
              ],
            ],
          ),
        ),

        // 写真リスト
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _photos.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'まだ写真がありません',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'カメラで入道雲を撮影してみましょう！',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _isGridView
                      ? _buildPhotosGridView()
                      : _buildPhotosListView(),
        ),
      ],
    );
  }

  Widget _buildDownloadedPhotosTab() {
    return Column(
      children: [
        // ツールバー
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                '${_downloadedPhotos.length}枚のダウンロード済み写真',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_isSelectionMode) ...[
                TextButton(
                  onPressed: _selectedDownloaded.isEmpty ? null : _deleteSelectedDownloadedPhotos,
                  child: Text(
                    '削除 (${_selectedDownloaded.length})',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _toggleSelectionMode,
                  child: const Text('キャンセル'),
                ),
              ] else ...[
                IconButton(
                  icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist),
                  onPressed: _downloadedPhotos.isEmpty ? null : _toggleSelectionMode,
                  tooltip: _isSelectionMode ? '選択を終了' : '写真を選択',
                ),
              ],
            ],
          ),
        ),

        // ダウンロード済み写真リスト
        Expanded(
          child: _isLoadingDownloaded
              ? const Center(child: CircularProgressIndicator())
              : _downloadedPhotos.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.download_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'ダウンロード済み写真がありません',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'コミュニティから写真をダウンロードしてみましょう！',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildDownloadedListView(),
        ),
      ],
    );
  }

  Widget _buildPhotosGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        final photo = _photos[index];
        final isSelected = _selectedPhotos.contains(photo.id);

        return GestureDetector(
          onTap: () {
            if (_isSelectionMode) {
              setState(() {
                if (isSelected) {
                  _selectedPhotos.remove(photo.id);
                } else {
                  _selectedPhotos.add(photo.id);
                }
              });
            } else {
              _showPhotoDetail(photo);
            }
          },
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: isSelected
                    ? Border.all(color: Colors.blue, width: 3)
                    : null,
                ),
                child: _buildPhotoImage(photo),
              ),
              if (_isSelectionMode)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isSelected ? Icons.check : null,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotosListView() {
    return ListView.builder(
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        final photo = _photos[index];
        final isSelected = _selectedPhotos.contains(photo.id);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    border: isSelected
                      ? Border.all(color: Colors.blue, width: 2)
                      : null,
                  ),
                  child: _buildPhotoImage(photo),
                ),
                if (_isSelectionMode)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isSelected ? Icons.check : null,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(_formatDateTime(photo.timestamp)),
                         subtitle: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text('いいね: ${photo.likes}'),
                 if (photo.weatherData.isNotEmpty)
                   Text('天気データ: ${photo.weatherData.keys.join(', ')}'),
               ],
             ),
            trailing: _isSelectionMode
                ? null
                : PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'share':
                          _sharePhoto(photo);
                          break;
                        case 'delete':
                          _deletePhoto(photo);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share),
                            SizedBox(width: 8),
                            Text('共有'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('削除', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
            onTap: () {
              if (_isSelectionMode) {
                setState(() {
                  if (isSelected) {
                    _selectedPhotos.remove(photo.id);
                  } else {
                    _selectedPhotos.add(photo.id);
                  }
                });
              } else {
                _showPhotoDetail(photo);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildDownloadedListView() {
    return ListView.builder(
      itemCount: _downloadedPhotos.length,
      itemBuilder: (context, index) {
        final photoData = _downloadedPhotos[index];
        final photoId = photoData['photoId'] as String;
        final isSelected = _selectedDownloaded.contains(photoId);
        final timestamp = (photoData['timestamp'] as Timestamp).toDate();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    border: isSelected
                      ? Border.all(color: Colors.blue, width: 2)
                      : null,
                  ),
                  child: _buildDownloadedPhotoImage(photoData['imageUrl'] as String),
                ),
                if (_isSelectionMode)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isSelected ? Icons.check : null,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
            title: Text('${photoData['userName']} の写真'),
            subtitle: Text(
              '${timestamp.year}/${timestamp.month}/${timestamp.day} '
              '${timestamp.hour.toString().padLeft(2, '0')}:'
              '${timestamp.minute.toString().padLeft(2, '0')}',
            ),
            onTap: () {
              if (_isSelectionMode) {
                setState(() {
                  if (isSelected) {
                    _selectedDownloaded.remove(photoId);
                  } else {
                    _selectedDownloaded.add(photoId);
                  }
                });
              } else {
                _showDownloadedPhotoDetail(photoData);
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _deletePhoto(Photo photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('写真を削除'),
        content: const Text('この写真を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await LocalPhotoService.deleteLocalPhoto(photo.id, _currentUserId);
        setState(() {
          _photos.removeWhere((p) => p.id == photo.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('写真を削除しました')),
          );
        }
      } catch (e) {
        print('❌ 写真削除エラー: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('削除に失敗しました: $e')),
          );
        }
      }
    }
  }

  void _showPhotoDetail(Photo photo) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('写真詳細画面は準備中です')),
    );
  }

  void _showDownloadedPhotoDetail(Map<String, dynamic> photoData) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ダウンロード済み写真詳細画面は準備中です')),
    );
  }
}