import 'package:cloud_firestore/cloud_firestore.dart';

/// 写真データモデル
class Photo {
  final String id;
  final String userId;
  final String userName;
  final String imageUrl;
  final String thumbnailUrl;
  final double latitude;
  final double longitude;
  final String locationName;
  final DateTime timestamp;
  final Map<String, dynamic> weatherData;
  final int likes;
  final bool isPublic;
  final List<String> tags;
  final List<String> likedBy; // 新規追加：いいねしたユーザーのリスト

  Photo({
    required this.id,
    required this.userId,
    required this.userName,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.timestamp,
    required this.weatherData,
    this.likes = 0,
    this.isPublic = true,
    this.tags = const [],
    this.likedBy = const [], // 新規追加
  });

  /// Firestoreドキュメントから写真オブジェクトを作成
  factory Photo.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Photo(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      latitude: (data['location'] as GeoPoint?)?.latitude ?? 0.0,
      longitude: (data['location'] as GeoPoint?)?.longitude ?? 0.0,
      locationName: data['locationName'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      weatherData: data['weatherData'] ?? {},
      likes: data['likes'] ?? 0,
      isPublic: data['isPublic'] ?? true,
      tags: List<String>.from(data['tags'] ?? []),
      likedBy: List<String>.from(data['likedBy'] ?? []), // 新規追加
    );
  }

  /// Mapから写真オブジェクトを作成（ローカルストレージ用）
  factory Photo.fromMap(Map<String, dynamic> map) {
    return Photo(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      locationName: map['locationName'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
      weatherData: Map<String, dynamic>.from(map['weatherData'] ?? {}),
      likes: map['likes'] ?? 0,
      isPublic: map['isPublic'] ?? true,
      tags: List<String>.from(map['tags'] ?? []),
      likedBy: List<String>.from(map['likedBy'] ?? []), // 新規追加
    );
  }

  /// FirestoreドキュメントへのMap変換
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'location': GeoPoint(latitude, longitude),
      'locationName': locationName,
      'timestamp': Timestamp.fromDate(timestamp),
      'weatherData': weatherData,
      'likes': likes,
      'isPublic': isPublic,
      'tags': tags,
      'likedBy': likedBy, // 新規追加
    };
  }

  /// ローカルストレージ用のMap変換
  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'weatherData': weatherData,
      'likes': likes,
      'isPublic': isPublic,
      'tags': tags,
      'likedBy': likedBy, // 新規追加
    };
  }

  /// 写真のコピーを作成（一部フィールドを更新）
  Photo copyWith({
    String? id,
    String? userId,
    String? userName,
    String? imageUrl,
    String? thumbnailUrl,
    double? latitude,
    double? longitude,
    String? locationName,
    DateTime? timestamp,
    Map<String, dynamic>? weatherData,
    int? likes,
    bool? isPublic,
    List<String>? tags,
    List<String>? likedBy, // 新規追加
  }) {
    return Photo(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      timestamp: timestamp ?? this.timestamp,
      weatherData: weatherData ?? this.weatherData,
      likes: likes ?? this.likes,
      isPublic: isPublic ?? this.isPublic,
      tags: tags ?? this.tags,
      likedBy: likedBy ?? this.likedBy, // 新規追加
    );
  }

  /// 指定されたユーザーがいいねしているかチェック
  bool isLikedByUser(String userId) {
    return likedBy.contains(userId);
  }
}

/// いいねデータモデル
class PhotoLike {
  final String id;
  final String photoId;
  final String userId;
  final DateTime timestamp;

  PhotoLike({
    required this.id,
    required this.photoId,
    required this.userId,
    required this.timestamp,
  });

  factory PhotoLike.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PhotoLike(
      id: doc.id,
      photoId: data['photoId'] ?? '',
      userId: data['userId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'photoId': photoId,
      'userId': userId,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}