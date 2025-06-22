import 'package:cloud_firestore/cloud_firestore.dart';

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
  final int comments;
  final bool isPublic;
  final List<String> tags;

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
    this.comments = 0,
    this.isPublic = true,
    this.tags = const [],
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
      comments: data['comments'] ?? 0,
      isPublic: data['isPublic'] ?? true,
      tags: List<String>.from(data['tags'] ?? []),
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
      comments: map['comments'] ?? 0,
      isPublic: map['isPublic'] ?? true,
      tags: List<String>.from(map['tags'] ?? []),
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
      'comments': comments,
      'isPublic': isPublic,
      'tags': tags,
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
      'comments': comments,
      'isPublic': isPublic,
      'tags': tags,
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
    int? comments,
    bool? isPublic,
    List<String>? tags,
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
      comments: comments ?? this.comments,
      isPublic: isPublic ?? this.isPublic,
      tags: tags ?? this.tags,
    );
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

/// コメントデータモデル
class PhotoComment {
  final String id;
  final String photoId;
  final String userId;
  final String userName;
  final String text;
  final DateTime timestamp;

  PhotoComment({
    required this.id,
    required this.photoId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.timestamp,
  });

  factory PhotoComment.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PhotoComment(
      id: doc.id,
      photoId: data['photoId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'photoId': photoId,
      'userId': userId,
      'userName': userName,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}