import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/photo.dart';
import '../services/location/location_service.dart';
import '../services/photo/photo_service.dart';
import '../services/photo/user_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  List<Photo> _photos = [];
  bool _isLoading = true;
  bool _isNearbyMode = false;
  final String _currentUserId = 'user_001'; // 現在のユーザーID
  LatLng? _currentLocation;
  DateTime? _selectedDate;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  final bool _isDownloadingPhoto = false;
  bool _isDeletingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    _getCurrentLocation();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent &&
        _hasMore &&
        !_isLoading) {
      _loadMorePhotos();
    }
  }

  Future<void> _loadPhotos() async {
    try {
      print('🚀 コミュニティ写真読み込み開始');
      setState(() {
        _isLoading = true;
      });

      List<Photo> photos;
      if (_isNearbyMode && _currentLocation != null) {
        print('📍 近くの写真を取得中: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
        photos = await PhotoService.getNearbyPhotos(
          center: _currentLocation!,
          radiusKm: 50.0,
          limit: 20,
        );
      } else {
        print('🌐 公開写真を取得中...');
        photos = await PhotoService.getPublicPhotos(limit: 20);
      }

      print('📊 取得した写真数: ${photos.length}');
      for (int i = 0; i < photos.length && i < 3; i++) {
        print('📸 写真${i + 1}: ${photos[i].id} - ${photos[i].userName} - ${photos[i].timestamp}');
      }

      setState(() {
        _photos = photos;
        _isLoading = false;
        _lastDocument = null;
        _hasMore = photos.length == 20;
      });

      print('✅ コミュニティ写真読み込み完了: ${photos.length}件');
    } catch (e) {
      print('❌ 写真読み込みエラー: $e');
      print('❌ エラータイプ: ${e.runtimeType}');
      print('❌ スタックトレース: ${StackTrace.current}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMorePhotos() async {
    if (_isLoading || !_hasMore) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final photos = await PhotoService.getPublicPhotos(
        limit: 20,
        lastDocument: _lastDocument,
      );

      setState(() {
        _photos.addAll(photos);
        _isLoading = false;
        _hasMore = photos.length == 20;
      });
    } catch (e) {
      print('❌ 追加写真読み込みエラー: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final location = await LocationService.getCurrentLocationAsLatLng();
      setState(() {
        _currentLocation = location;
      });
    } catch (e) {
      print('❌ 位置情報取得エラー: $e');
    }
  }

  Future<void> _toggleNearbyMode() async {
    if (!_isNearbyMode && _currentLocation == null) {
      await _getCurrentLocation();
    }

    setState(() {
      _isNearbyMode = !_isNearbyMode;
    });

    await _loadPhotos();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadPhotos();
    }
  }

  Future<void> _toggleLike(Photo photo) async {
    try {
      final success = await PhotoService.likePhoto(photo.id, _currentUserId);
      if (success) {
        setState(() {
          final index = _photos.indexWhere((p) => p.id == photo.id);
          if (index != -1) {
            _photos[index] = photo.copyWith(likes: photo.likes + 1);
          }
        });
      }
    } catch (e) {
      print('❌ いいねエラー: $e');
    }
  }

  Future<void> _downloadPhoto(Photo photo) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('ダウンロード中...'),
            ],
          ),
        ),
      );

      final success = await PhotoService.downloadPhoto(photo, _currentUserId);

      if (mounted) {
        Navigator.pop(context); // ダイアログを閉じる

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('写真をダウンロードしました！'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ダウンロードに失敗しました'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // ダイアログを閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ダウンロードエラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmDialog(Photo photo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('写真を削除'),
          content: const Text('この写真を削除しますか？\nこの操作は取り消せません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deletePhoto(photo.id);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePhoto(String photoId) async {
    setState(() {
      _isDeletingPhoto = true;
    });

    try {
      // 削除中のダイアログを表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('削除中...'),
              ],
            ),
          );
        },
      );

      // 写真を削除
      final success = await PhotoService.deletePhoto(photoId, _currentUserId);

      if (mounted) {
        Navigator.pop(context); // 削除中ダイアログを閉じる

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('写真を削除しました'),
              backgroundColor: Colors.green,
            ),
          );
          // 写真リストを更新
          _loadPhotos();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('写真の削除に失敗しました'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 削除中ダイアログを閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('削除エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isDeletingPhoto = false;
      });
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// プロフィール編集ダイアログを表示
  void _showProfileEditDialog() async {
    try {
      // 現在のユーザー情報を取得
      final userInfo = await UserService.getUserInfo(_currentUserId);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ProfileEditDialog(
            currentUserInfo: userInfo,
            userId: _currentUserId,
            onProfileUpdated: () {
              _loadPhotos(); // 写真リストを再読み込み（ユーザー名更新のため）
            },
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "コミュニティ",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 135, 206, 250),
        foregroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black54,
        automaticallyImplyLeading: false,
        actions: [
          // プロフィール編集ボタン
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _showProfileEditDialog,
            tooltip: 'プロフィール編集',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedDate != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.blue[50],
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 16),
                  const SizedBox(width: 8),
                  Text('フィルター: ${_formatDateTime(_selectedDate!).split(' ')[0]}'),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedDate = null;
                      });
                      _loadPhotos();
                    },
                    child: const Text('クリア'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading && _photos.isEmpty
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
                              '写真がありません',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPhotos,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8),
                          itemCount: _photos.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _photos.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final photo = _photos[index];
                            return _buildPhotoCard(photo);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/camera');
        },
        backgroundColor: const Color.fromRGBO(135, 206, 250, 1.0),
        tooltip: '写真を撮影',
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildPhotoCard(Photo photo) {
    final isOwnPhoto = photo.userId == _currentUserId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー部分
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // ユーザーアバター
                FutureBuilder<Map<String, dynamic>>(
                  future: UserService.getUserInfo(photo.userId),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!['avatarUrl'] != null) {
                      return CircleAvatar(
                        radius: 20,
                        backgroundImage: CachedNetworkImageProvider(snapshot.data!['avatarUrl']),
                      );
                    }
                    return const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white),
                    );
                  },
                ),
                const SizedBox(width: 12),
                // ユーザー名と投稿時間
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        photo.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${photo.timestamp.year}/${photo.timestamp.month}/${photo.timestamp.day} '
                        '${photo.timestamp.hour.toString().padLeft(2, '0')}:'
                        '${photo.timestamp.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // アクションボタン（自分の投稿か他人の投稿かで分岐）
                if (isOwnPhoto)
                  // 自分の投稿: 削除ボタン
                  IconButton(
                    onPressed: _isDeletingPhoto ? null : () => _showDeleteConfirmDialog(photo),
                    icon: _isDeletingPhoto
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete, color: Colors.red),
                    tooltip: '削除',
                  )
                else
                  // 他人の投稿: ダウンロードボタン
                  IconButton(
                    onPressed: _isDownloadingPhoto ? null : () => _downloadPhoto(photo),
                    icon: _isDownloadingPhoto
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download, color: Colors.blue),
                    tooltip: 'ダウンロード',
                  ),
              ],
            ),
          ),
          // 写真画像
          GestureDetector(
            onTap: () => _showPhotoDetail(photo),
            child: CachedNetworkImage(
              imageUrl: photo.imageUrl,
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 300,
                color: Colors.grey[300],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                height: 300,
                color: Colors.grey[300],
                child: const Icon(Icons.error),
              ),
            ),
          ),
          // いいねボタン（準備中）
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('いいね機能は準備中です')),
                    );
                  },
                  icon: const Icon(Icons.favorite_border),
                ),
                const Text('0'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoDetail(Photo photo) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('写真詳細画面は準備中です')),
    );
  }



  String _calculateDistance(Photo photo) {
    if (_currentLocation == null) return '0';

    const double earthRadius = 6371; // 地球の半径（km）

    final double dLat = _degreesToRadians(photo.latitude - _currentLocation!.latitude);
    final double dLon = _degreesToRadians(photo.longitude - _currentLocation!.longitude);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(_currentLocation!.latitude)) *
        math.cos(_degreesToRadians(photo.latitude)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return (earthRadius * c).toStringAsFixed(1);
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// ボトムナビゲーションバー
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
                  Navigator.pushReplacementNamed(context, '/gallery');
                },
              ),
              _buildNavButton(
                context,
                icon: Icons.people,
                label: 'コミュニティ',
                onTap: () {
                  // 現在のページなので何もしない
                },
                isActive: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ナビゲーションボタン
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
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('アバター画像を更新しました')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('アバター更新エラー: $e')),
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
        const SnackBar(content: Text('名前を入力してください')),
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
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('プロフィールを更新しました')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('プロフィール更新に失敗しました')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新エラー: $e')),
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
    return AlertDialog(
      title: const Text('プロフィール編集'),
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
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _currentAvatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(_currentAvatarUrl)
                        : null,
                    child: _currentAvatarUrl.isEmpty
                        ? const Icon(Icons.person, size: 50, color: Colors.grey)
                        : null,
                  ),
                  if (_isUpdating)
                    const Positioned.fill(
                      child: CircularProgressIndicator(),
                    ),
                  const Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.edit, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'アバター画像をタップして変更',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // ユーザー名入力
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'ユーザー名',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              enabled: !_isUpdating,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUpdating ? null : () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _isUpdating ? null : _updateUserName,
          child: _isUpdating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}

