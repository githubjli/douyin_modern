import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../domain/feed_item.dart';
import '../domain/feed_repository.dart';

class RemoteFeedRepository implements FeedRepository {
  RemoteFeedRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<FeedItem>> getShortsFeed() async {
    final response = await _apiClient.get<dynamic>(Endpoints.publicVideos);
    final List<dynamic> rows = _extractRows(response.data);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(_mapVideo)
        .toList(growable: false);
  }

  List<dynamic> _extractRows(dynamic data) {
    if (data is List<dynamic>) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final dynamic results = data['results'];
      if (results is List<dynamic>) {
        return results;
      }
    }
    return const <dynamic>[];
  }

  FeedItem _mapVideo(Map<String, dynamic> raw) {
    final int likes = _readInt(raw['like_count']);
    final int comments = _readInt(raw['comment_count']);
    final int views = _readInt(raw['view_count']);
    final String ownerName = _readString(raw['owner_name']) ?? 'creator';

    return FeedItem(
      username: '@$ownerName',
      description: _readString(raw['description']) ?? _readString(raw['title']) ?? '',
      music: _readString(raw['category_name']) ?? 'Original Sound',
      likes: likes.toString(),
      comments: comments.toString(),
      shares: views.toString(),
      videoUrl: _readString(raw['file_url']) ?? '',
      placeholderGradient: const <Color>[Color(0xFF111111), Color(0xFF2C2C2C)],
      id: _readString(raw['id']),
      title: _readString(raw['title']),
      thumbnailUrl: _readString(raw['thumbnail_url']),
      ownerId: _readString(raw['owner_id']),
      ownerName: _readString(raw['owner_name']),
      ownerAvatarUrl: _readString(raw['owner_avatar_url']),
      category: _readString(raw['category']),
      categoryName: _readString(raw['category_name']),
      categorySlug: _readString(raw['category_slug']),
      accessType: _readString(raw['access_type']),
      previewSeconds: _readNullableInt(raw['preview_seconds']),
      canWatch: _readBool(raw['can_watch']),
      isLocked: _readBool(raw['is_locked']),
      lockReason: _readString(raw['lock_reason']),
      likeCount: likes,
      commentCount: comments,
      viewCount: views,
      isLiked: _readBool(raw['is_liked']),
      createdAt: _readString(raw['created_at']),
    );
  }

  String? _readString(dynamic value) {
    if (value is String) return value;
    if (value is num) return value.toString();
    return null;
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  int? _readNullableInt(dynamic value) {
    if (value == null) return null;
    return _readInt(value);
  }

  bool? _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return null;
  }
}
