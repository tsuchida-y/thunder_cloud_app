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
  final bool _isNearbyMode = false;
  final String _currentUserId = 'user_001'; // 現在のユーザーID
  LatLng? _currentLocation;
  DateTime? _selectedDate;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  final bool _isDownloadingPhoto = false;
  bool _isDeletingPhoto = false;

  // いいね状態を管理するマップ
  Map<String, bool> _likeStatus = {};

  // ユーザー情報キャッシュ
  final Map<String, Map<String, dynamic>> _userInfoCache = {};

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

  /// 外部から呼び出し可能なデータ再読み込みメソッド
  void refreshData() {
    print('🔄 コミュニティデータ再読み込み開始');
    _userInfoCache.clear(); // キャッシュをクリア
    _loadPhotos();
  }

  /// ユーザー情報を取得（キャッシュ機能付き）
  Future<Map<String, dynamic>> _getUserInfo(String userId) async {
    // キャッシュから取得を試行
    if (_userInfoCache.containsKey(userId)) {
      return _userInfoCache[userId]!;
    }

    try {
      // UserServiceから最新情報を取得
      final userInfo = await UserService.getUserInfo(userId);
      _userInfoCache[userId] = userInfo; // キャッシュに保存
      return userInfo;
    } catch (e) {
      print('❌ ユーザー情報取得エラー (userId: $userId): $e');
      // デフォルト情報を返す
      final defaultInfo = {
        'userId': userId,
        'userName': 'ユーザー',
        'avatarUrl': '',
      };
      _userInfoCache[userId] = defaultInfo;
      return defaultInfo;
    }
  }

  /// 複数のユーザー情報を事前読み込み
  Future<void> _preloadUserInfos(List<String> userIds) async {
    print('👤 ユーザー情報事前読み込み開始: ${userIds.length}件');

    // キャッシュにないユーザーIDのみを対象にする
    final uncachedUserIds = userIds.where((id) => !_userInfoCache.containsKey(id)).toList();
    if (uncachedUserIds.isEmpty) {
      print('✅ 全てキャッシュ済み');
      return;
    }

    print('📋 新規読み込み対象: ${uncachedUserIds.length}件');

    // 並列でユーザー情報を取得
    await Future.wait(uncachedUserIds.map((userId) => _getUserInfo(userId)));
    print('✅ ユーザー情報事前読み込み完了');
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

      // Firebaseの接続状態をチェック
      try {
        final testQuery = await FirebaseFirestore.instance.collection('photos').limit(1).get();
        print('🔥 Firebase接続確認: ${testQuery.docs.length}件のドキュメント取得可能');
      } catch (e) {
        print('❌ Firebase接続エラー: $e');
      }

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

      // いいね状態を取得
      if (photos.isNotEmpty) {
        print('👍 いいね状態取得開始: ${photos.length}件の写真');
        final photoIds = photos.map((photo) => photo.id).toList();
        print('📋 写真ID一覧: ${photoIds.take(3).join(', ')}...');

        final likeStatus = await PhotoService.getPhotosLikeStatus(photoIds, _currentUserId);
        print('📊 取得したいいね状態: ${likeStatus.length}件');

        // デバッグ: 最初の3件のいいね状態を表示
        for (int i = 0; i < photoIds.length && i < 3; i++) {
          final photoId = photoIds[i];
          final isLiked = likeStatus[photoId] ?? false;
          print('   $photoId: $isLiked');
        }

        setState(() {
          _likeStatus = likeStatus;
        });
        print('✅ いいね状態設定完了: ${_likeStatus.length}件');
      }

      // 写真が見つからない場合のデバッグ
      if (photos.isEmpty) {
        print('⚠️ 公開写真が見つかりません。全写真を確認中...');
        try {
          final allPhotos = await FirebaseFirestore.instance.collection('photos').get();
          print('📈 データベース内の全写真数: ${allPhotos.docs.length}');

          for (var doc in allPhotos.docs.take(5)) {
            final data = doc.data();
            print('📋 写真データ例: ${doc.id}');
            print('   - userId: ${data['userId']}');
            print('   - userName: ${data['userName']}');
            print('   - isPublic: ${data['isPublic']}');
            print('   - timestamp: ${data['timestamp']}');
          }
        } catch (e) {
          print('❌ 全写真確認エラー: $e');
        }
      } else {
        for (int i = 0; i < photos.length && i < 3; i++) {
          print('📸 写真${i + 1}: ${photos[i].id} - ${photos[i].userName} - ${photos[i].timestamp}');
        }
      }

      // ユーザー情報を事前読み込み（ちらつき防止）
      if (photos.isNotEmpty) {
        final uniqueUserIds = photos.map((photo) => photo.userId).toSet().toList();
        await _preloadUserInfos(uniqueUserIds);
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

      // 追加された写真のいいね状態を取得
      if (photos.isNotEmpty) {
        final photoIds = photos.map((photo) => photo.id).toList();
        final likeStatus = await PhotoService.getPhotosLikeStatus(photoIds, _currentUserId);
        setState(() {
          _likeStatus.addAll(likeStatus);
        });
      }

      // ユーザー情報を事前読み込み（ちらつき防止）
      final uniqueUserIds = photos.map((photo) => photo.userId).toSet().toList();
      await _preloadUserInfos(uniqueUserIds);

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

  Future<void> _toggleLike(Photo photo) async {
    try {
      final isCurrentlyLiked = _likeStatus[photo.id] ?? false;
      print('🔄 いいね切り替え開始: ${photo.id}, 現在の状態: $isCurrentlyLiked');

      bool success;
      if (isCurrentlyLiked) {
        // いいねを取り消す
        success = await PhotoService.unlikePhoto(photo.id, _currentUserId);
        if (success) {
          setState(() {
            _likeStatus[photo.id] = false;
            final index = _photos.indexWhere((p) => p.id == photo.id);
            if (index != -1) {
              _photos[index] = photo.copyWith(likes: photo.likes - 1);
            }
          });
          print('✅ いいね取り消し成功: ${photo.id}');
        } else {
          print('❌ いいね取り消し失敗: ${photo.id}');
        }
      } else {
        // いいねを追加
        success = await PhotoService.likePhoto(photo.id, _currentUserId);
        if (success) {
          setState(() {
            _likeStatus[photo.id] = true;
            final index = _photos.indexWhere((p) => p.id == photo.id);
            if (index != -1) {
              _photos[index] = photo.copyWith(likes: photo.likes + 1);
            }
          });
          print('✅ いいね追加成功: ${photo.id}');
        } else {
          print('❌ いいね追加失敗（既にいいね済み）: ${photo.id}');
        }
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
            const SnackBar(content: Text('写真をダウンロードしました')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ダウンロードに失敗しました')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // エラー時もダイアログを閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ダウンロードエラー: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmDialog(Photo photo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 28,
              ),
              SizedBox(width: 8),
              Text(
                '写真を削除',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'この写真を完全に削除しますか？',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.red,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'この操作は取り消せません',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                'キャンセル',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deletePhoto(photo.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete, size: 16),
                  SizedBox(width: 4),
                  Text(
                    '削除する',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
            SnackBar(
              content: const Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '写真を削除しました',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
          // 写真リストを更新
          _loadPhotos();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '写真の削除に失敗しました',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 削除中ダイアログを閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '削除エラー: $e',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
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
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
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
    return RefreshIndicator(
      onRefresh: _refreshPhotos,
      child: _isLoading && _photos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: const Center(
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
                            'まだ写真が投稿されていません',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'カメラで入道雲を撮影して投稿してみましょう！',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            '画面を下に引っ張って更新',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _photos.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _photos.length) {
                      // ローディングインジケーター
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final photo = _photos[index];
                    return _buildPhotoCard(photo);
                  },
                ),
    );
  }

  /// プルトゥリフレッシュ用の更新メソッド
  Future<void> _refreshPhotos() async {
    print('🔄 プルトゥリフレッシュによる写真更新開始');
    await _loadPhotos();
  }

  Widget _buildPhotoCard(Photo photo) {
    final isLiked = _likeStatus[photo.id] ?? false;
    print('🎨 写真カード表示: ${photo.id}, いいね状態: $isLiked, いいね数: ${photo.likes}');
    print('🗑️ 削除ボタン表示判定: photo.userId="${photo.userId}", _currentUserId="$_currentUserId", 表示=${photo.userId == _currentUserId}');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ユーザー情報ヘッダー
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildUserHeader(photo),
          ),

          // 写真画像
          CachedNetworkImage(
            imageUrl: photo.imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 300,
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

          // アクションボタン
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // いいねボタン
                GestureDetector(
                  onTap: () => _toggleLike(photo),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        photo.likes.toString(),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // ダウンロードボタン
                GestureDetector(
                  onTap: _isDownloadingPhoto ? null : () => _downloadPhoto(photo),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.download,
                        color: Colors.blue,
                        size: 24,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'ダウンロード',
                        style: TextStyle(fontSize: 14, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ユーザー情報ヘッダーを構築（同期的表示でちらつき防止）
  Widget _buildUserHeader(Photo photo) {
    // キャッシュからユーザー情報を取得（事前読み込み済み）
    final userInfo = _userInfoCache[photo.userId] ?? {
      'userName': photo.userName,
      'avatarUrl': '',
    };
    final avatarUrl = userInfo['avatarUrl'] as String? ?? '';
    final userName = userInfo['userName'] as String? ?? photo.userName;

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color.fromRGBO(135, 206, 250, 1.0),
          backgroundImage: avatarUrl.isNotEmpty
              ? CachedNetworkImageProvider(avatarUrl)
              : null,
          child: avatarUrl.isEmpty
              ? Text(
                  userName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                _formatDateTime(photo.timestamp),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        // 削除ボタン（自分の投稿のみ表示）
        if (photo.userId == _currentUserId)
          GestureDetector(
            onTap: _isDeletingPhoto ? null : () => _showDeleteConfirmDialog(photo),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 18,
              ),
            ),
          ),
      ],
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            constraints: BoxConstraints(
              maxWidth: 350,
              maxHeight: MediaQuery.of(context).size.height -
                         MediaQuery.of(context).viewInsets.bottom - 100,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // タイトル
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: const Text(
                      'プロフィール編集',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // コンテンツ
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // アバター画像
                          GestureDetector(
                            onTap: _isUpdating ? null : _updateAvatar,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 35,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: _currentAvatarUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(_currentAvatarUrl)
                                      : null,
                                  child: _currentAvatarUrl.isEmpty
                                      ? const Icon(Icons.person, size: 35, color: Colors.grey)
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
                                    radius: 10,
                                    backgroundColor: Colors.blue,
                                    child: Icon(Icons.edit, size: 10, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'アバター画像をタップして変更',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),

                          // ユーザー名入力
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'ユーザー名',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_outline),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            enabled: !_isUpdating,
                            maxLength: 20,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  // アクションボタン
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isUpdating ? null : () => Navigator.pop(context),
                          child: const Text('キャンセル'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isUpdating ? null : _updateUserName,
                          child: _isUpdating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('保存'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CommunityScreenのコンテンツ部分のみ（Scaffold不要版）
class CommunityScreenContent extends StatefulWidget {
  const CommunityScreenContent({super.key});

  @override
  State<CommunityScreenContent> createState() => _CommunityScreenContentState();
}

class _CommunityScreenContentState extends State<CommunityScreenContent> {
  List<Photo> _photos = [];
  bool _isLoading = true;
  final bool _isNearbyMode = false;
  final String _currentUserId = 'user_001'; // 現在のユーザーID
  LatLng? _currentLocation;
  DateTime? _selectedDate;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  final bool _isDownloadingPhoto = false;
  bool _isDeletingPhoto = false;

  // いいね状態を管理するマップ
  Map<String, bool> _likeStatus = {};

  // ユーザー情報キャッシュ
  final Map<String, Map<String, dynamic>> _userInfoCache = {};

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

  /// 外部から呼び出し可能なデータ再読み込みメソッド
  void refreshData() {
    print('🔄 コミュニティデータ再読み込み開始');
    _userInfoCache.clear(); // キャッシュをクリア
    _loadPhotos();
  }

  /// ユーザー情報を取得（キャッシュ機能付き）
  Future<Map<String, dynamic>> _getUserInfo(String userId) async {
    // キャッシュから取得を試行
    if (_userInfoCache.containsKey(userId)) {
      return _userInfoCache[userId]!;
    }

    try {
      // UserServiceから最新情報を取得
      final userInfo = await UserService.getUserInfo(userId);
      _userInfoCache[userId] = userInfo; // キャッシュに保存
      return userInfo;
    } catch (e) {
      print('❌ ユーザー情報取得エラー (userId: $userId): $e');
      // デフォルト情報を返す
      final defaultInfo = {
        'userId': userId,
        'userName': 'ユーザー',
        'avatarUrl': '',
      };
      _userInfoCache[userId] = defaultInfo;
      return defaultInfo;
    }
  }

  /// 複数のユーザー情報を事前読み込み
  Future<void> _preloadUserInfos(List<String> userIds) async {
    print('👤 ユーザー情報事前読み込み開始: ${userIds.length}件');

    // キャッシュにないユーザーIDのみを対象にする
    final uncachedUserIds = userIds.where((id) => !_userInfoCache.containsKey(id)).toList();
    if (uncachedUserIds.isEmpty) {
      print('✅ 全てキャッシュ済み');
      return;
    }

    print('📋 新規読み込み対象: ${uncachedUserIds.length}件');

    // 並列でユーザー情報を取得
    await Future.wait(uncachedUserIds.map((userId) => _getUserInfo(userId)));
    print('✅ ユーザー情報事前読み込み完了');
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

      // Firebaseの接続状態をチェック
      try {
        final testQuery = await FirebaseFirestore.instance.collection('photos').limit(1).get();
        print('🔥 Firebase接続確認: ${testQuery.docs.length}件のドキュメント取得可能');
      } catch (e) {
        print('❌ Firebase接続エラー: $e');
      }

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

      // いいね状態を取得
      if (photos.isNotEmpty) {
        print('👍 いいね状態取得開始: ${photos.length}件の写真');
        final photoIds = photos.map((photo) => photo.id).toList();
        print('📋 写真ID一覧: ${photoIds.take(3).join(', ')}...');

        final likeStatus = await PhotoService.getPhotosLikeStatus(photoIds, _currentUserId);
        print('📊 取得したいいね状態: ${likeStatus.length}件');

        // デバッグ: 最初の3件のいいね状態を表示
        for (int i = 0; i < photoIds.length && i < 3; i++) {
          final photoId = photoIds[i];
          final isLiked = likeStatus[photoId] ?? false;
          print('   $photoId: $isLiked');
        }

        setState(() {
          _likeStatus = likeStatus;
        });
        print('✅ いいね状態設定完了: ${_likeStatus.length}件');
      }

      // 写真が見つからない場合のデバッグ
      if (photos.isEmpty) {
        print('⚠️ 公開写真が見つかりません。全写真を確認中...');
        try {
          final allPhotos = await FirebaseFirestore.instance.collection('photos').get();
          print('📈 データベース内の全写真数: ${allPhotos.docs.length}');

          for (var doc in allPhotos.docs.take(5)) {
            final data = doc.data();
            print('📋 写真データ例: ${doc.id}');
            print('   - userId: ${data['userId']}');
            print('   - userName: ${data['userName']}');
            print('   - isPublic: ${data['isPublic']}');
            print('   - timestamp: ${data['timestamp']}');
          }
        } catch (e) {
          print('❌ 全写真確認エラー: $e');
        }
      } else {
        for (int i = 0; i < photos.length && i < 3; i++) {
          print('📸 写真${i + 1}: ${photos[i].id} - ${photos[i].userName} - ${photos[i].timestamp}');
        }
      }

      // ユーザー情報を事前読み込み（ちらつき防止）
      if (photos.isNotEmpty) {
        final uniqueUserIds = photos.map((photo) => photo.userId).toSet().toList();
        await _preloadUserInfos(uniqueUserIds);
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

      // 追加された写真のいいね状態を取得
      if (photos.isNotEmpty) {
        final photoIds = photos.map((photo) => photo.id).toList();
        final likeStatus = await PhotoService.getPhotosLikeStatus(photoIds, _currentUserId);
        setState(() {
          _likeStatus.addAll(likeStatus);
        });
      }

      // ユーザー情報を事前読み込み（ちらつき防止）
      final uniqueUserIds = photos.map((photo) => photo.userId).toSet().toList();
      await _preloadUserInfos(uniqueUserIds);

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

  Future<void> _toggleLike(Photo photo) async {
    try {
      final isCurrentlyLiked = _likeStatus[photo.id] ?? false;
      print('🔄 いいね切り替え開始: ${photo.id}, 現在の状態: $isCurrentlyLiked');

      bool success;
      if (isCurrentlyLiked) {
        // いいねを取り消す
        success = await PhotoService.unlikePhoto(photo.id, _currentUserId);
        if (success) {
          setState(() {
            _likeStatus[photo.id] = false;
            final index = _photos.indexWhere((p) => p.id == photo.id);
            if (index != -1) {
              _photos[index] = photo.copyWith(likes: photo.likes - 1);
            }
          });
          print('✅ いいね取り消し成功: ${photo.id}');
        } else {
          print('❌ いいね取り消し失敗: ${photo.id}');
        }
      } else {
        // いいねを追加
        success = await PhotoService.likePhoto(photo.id, _currentUserId);
        if (success) {
          setState(() {
            _likeStatus[photo.id] = true;
            final index = _photos.indexWhere((p) => p.id == photo.id);
            if (index != -1) {
              _photos[index] = photo.copyWith(likes: photo.likes + 1);
            }
          });
          print('✅ いいね追加成功: ${photo.id}');
        } else {
          print('❌ いいね追加失敗（既にいいね済み）: ${photo.id}');
        }
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
            const SnackBar(content: Text('写真をダウンロードしました')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ダウンロードに失敗しました')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // エラー時もダイアログを閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ダウンロードエラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshPhotos,
      child: _isLoading && _photos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: const Center(
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
                            'まだ写真が投稿されていません',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'カメラで入道雲を撮影して投稿してみましょう！',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            '画面を下に引っ張って更新',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _photos.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _photos.length) {
                      // ローディングインジケーター
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final photo = _photos[index];
                    return _buildPhotoCard(photo);
                  },
                ),
    );
  }

  /// プルトゥリフレッシュ用の更新メソッド
  Future<void> _refreshPhotos() async {
    print('🔄 プルトゥリフレッシュによる写真更新開始');
    await _loadPhotos();
  }

  Widget _buildPhotoCard(Photo photo) {
    final isLiked = _likeStatus[photo.id] ?? false;
    print('🎨 写真カード表示: ${photo.id}, いいね状態: $isLiked, いいね数: ${photo.likes}');
    print('🗑️ 削除ボタン表示判定: photo.userId="${photo.userId}", _currentUserId="$_currentUserId", 表示=${photo.userId == _currentUserId}');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ユーザー情報ヘッダー
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildUserHeader(photo),
          ),

          // 写真画像
          CachedNetworkImage(
            imageUrl: photo.imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 300,
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

          // アクションボタン
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // いいねボタン
                GestureDetector(
                  onTap: () => _toggleLike(photo),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        photo.likes.toString(),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // ダウンロードボタン
                GestureDetector(
                  onTap: _isDownloadingPhoto ? null : () => _downloadPhoto(photo),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.download,
                        color: Colors.blue,
                        size: 24,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'ダウンロード',
                        style: TextStyle(fontSize: 14, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
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

  void _showDeleteConfirmDialog(Photo photo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 28,
              ),
              SizedBox(width: 8),
              Text(
                '写真を削除',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'この写真を完全に削除しますか？',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.red,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'この操作は取り消せません',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                'キャンセル',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deletePhoto(photo.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete, size: 16),
                  SizedBox(width: 4),
                  Text(
                    '削除する',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
            SnackBar(
              content: const Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '写真を削除しました',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
          // 写真リストを更新
          _loadPhotos();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '写真の削除に失敗しました',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 削除中ダイアログを閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '削除エラー: $e',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      setState(() {
        _isDeletingPhoto = false;
      });
    }
  }

  /// ユーザー情報ヘッダーを構築（同期的表示でちらつき防止）
  Widget _buildUserHeader(Photo photo) {
    // キャッシュからユーザー情報を取得（事前読み込み済み）
    final userInfo = _userInfoCache[photo.userId] ?? {
      'userName': photo.userName,
      'avatarUrl': '',
    };
    final avatarUrl = userInfo['avatarUrl'] as String? ?? '';
    final userName = userInfo['userName'] as String? ?? photo.userName;

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color.fromRGBO(135, 206, 250, 1.0),
          backgroundImage: avatarUrl.isNotEmpty
              ? CachedNetworkImageProvider(avatarUrl)
              : null,
          child: avatarUrl.isEmpty
              ? Text(
                  userName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                _formatDateTime(photo.timestamp),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        // 削除ボタン（自分の投稿のみ表示）
        if (photo.userId == _currentUserId)
          GestureDetector(
            onTap: _isDeletingPhoto ? null : () => _showDeleteConfirmDialog(photo),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 18,
              ),
            ),
          ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
