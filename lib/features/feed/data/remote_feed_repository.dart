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
    final List<FeedItem> items = <FeedItem>[];

    // Shorts tab is drama-only by product decision.
    // TODO(meow-media): public videos will be consumed by Home/Browse later.

    final dramasResponse = await _apiClient.get<dynamic>(Endpoints.dramas);
    final List<dynamic> dramaRows = _extractRows(dramasResponse.data);

    assert(() {
      debugPrint('[ShortFeed] drama series count: ${dramaRows.length}');
      return true;
    }());

    for (final dynamic drama in dramaRows) {
      if (drama is! Map<String, dynamic>) continue;
      final int? dramaId = _readIntOrNull(drama['id']);
      if (dramaId == null) continue;

      final episodeResponse = await _apiClient.get<dynamic>(
        Endpoints.dramaEpisodes(dramaId),
      );
      final List<dynamic> episodeRows = _extractEpisodeRows(episodeResponse.data);
      for (final dynamic episode in episodeRows) {
        if (episode is! Map<String, dynamic>) continue;
        final FeedItem? item = _mapDramaEpisode(drama, episode);
        if (item != null) items.add(item);
      }
    }

    assert(() {
      debugPrint('[ShortFeed] playable drama episodes: ${items.length}');
      return true;
    }());

    return items;
  }

  List<dynamic> _extractRows(dynamic data) {
    if (data is List<dynamic>) return data;
    if (data is Map<String, dynamic>) {
      final dynamic results = data['results'];
      if (results is List<dynamic>) return results;
    }
    return const <dynamic>[];
  }

  List<dynamic> _extractEpisodeRows(dynamic data) {
    if (data is List<dynamic>) return data;
    if (data is Map<String, dynamic>) {
      final dynamic episodes = data['episodes'];
      if (episodes is List<dynamic>) return episodes;
      final dynamic results = data['results'];
      if (results is List<dynamic>) return results;
    }
    return const <dynamic>[];
  }

  FeedItem? _mapDramaEpisode(Map<String, dynamic> drama, Map<String, dynamic> episode) {
    final bool canWatch = _readBool(episode['can_watch']) ?? false;
    final bool isLocked = _readBool(episode['is_locked']) ?? false;
    final String? videoUrl = _pickPlayableUrl(episode);
    if (!canWatch || isLocked || videoUrl == null || videoUrl.isEmpty) {
      return null;
    }

    final String dramaName =
        _readString(drama['title']) ?? _readString(drama['name']) ?? 'Drama';
    final String episodeTitle =
        _readString(episode['title']) ?? 'Episode ${_readString(episode['episode_no']) ?? ''}'.trim();

    return FeedItem(
      username: '@$dramaName',
      description: _readString(episode['description']) ?? episodeTitle,
      music: 'Original Sound',
      likes: _readInt(episode['like_count']).toString(),
      comments: _readInt(episode['comment_count']).toString(),
      shares: _readInt(episode['view_count']).toString(),
      videoUrl: videoUrl,
      placeholderGradient: const <Color>[Color(0xFF0A0A0A), Color(0xFF1B2F45)],
      id: _readString(episode['id']),
      title: episodeTitle,
      thumbnailUrl: _readString(episode['thumbnail_url']),
      ownerName: dramaName,
      categoryName: _readString(drama['category_name']),
      accessType: _readString(episode['access_type']),
      previewSeconds: _readIntOrNull(episode['preview_seconds']),
      canWatch: canWatch,
      isLocked: isLocked,
      lockReason: _readString(episode['lock_reason']),
      likeCount: _readIntOrNull(episode['like_count']),
      commentCount: _readIntOrNull(episode['comment_count']),
      viewCount: _readIntOrNull(episode['view_count']),
      isLiked: _readBool(episode['is_liked']),
      createdAt: _readString(episode['created_at']),
      seriesId: _readIntOrNull(drama['id']),
      seriesTitle: dramaName,
      episodeId: _readIntOrNull(episode['id']),
      episodeNo: _readIntOrNull(episode['episode_no']),
      durationSeconds: _readIntOrNull(episode['duration_seconds']),
      unlockType: _readString(episode['unlock_type']),
      pointsPrice: _readIntOrNull(episode['points_price']),
    );
  }

  String? _pickPlayableUrl(Map<String, dynamic> data) {
    return _readString(data['playback_url']) ??
        _readString(data['video_url']) ??
        _readString(data['hls_url']) ??
        _readString(data['file_url']);
  }

  String? _readString(dynamic value) {
    if (value is String) return value;
    if (value is num) return value.toString();
    return null;
  }

  int _readInt(dynamic value) {
    return _readIntOrNull(value) ?? 0;
  }

  int? _readIntOrNull(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  bool? _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final String normalized = value.toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return null;
  }
}
