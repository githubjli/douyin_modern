import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../domain/home_models.dart';
import '../domain/home_repository.dart';

class RemoteHomeRepository implements HomeRepository {
  RemoteHomeRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  static const int defaultVideoPageSize = 30;

  final ApiClient _apiClient;

  @override
  Future<HomePortalData> getHomePortalData() async {
    List<Map<String, dynamic>> videos = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> dramas = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> live = <Map<String, dynamic>>[];
    int? videosCount;
    String? videosNextUrl;
    String? videosPreviousUrl;
    String? dramasNextUrl;
    String? liveNextUrl;

    try {
      final _HomeVideoRows videosPage = await _fetchVideoRows();
      videos = videosPage.rows;
      videosCount = videosPage.count;
      videosNextUrl = videosPage.nextUrl;
      videosPreviousUrl = videosPage.previousUrl;
    } catch (_) {
      assert(() {
        debugPrint('[Home] videos fetch failed');
        return true;
      }());
    }

    try {
      final dramasResponse = await _apiClient.get<dynamic>(Endpoints.dramas);
      dramas = _rows(dramasResponse.data);
      dramasNextUrl = _next(dramasResponse.data);
    } catch (_) {
      assert(() {
        debugPrint('[Home] dramas fetch failed');
        return true;
      }());
    }

    try {
      final liveResponse = await _apiClient.get<dynamic>('/api/live/');
      live = _rows(liveResponse.data);
      liveNextUrl = _next(liveResponse.data);
    } catch (_) {
      assert(() {
        debugPrint('[Home] live fetch failed');
        return true;
      }());
    }

    assert(() {
      debugPrint('[Home] videos=${videos.length}, dramas=${dramas.length}, live=${live.length}');
      return true;
    }());

    final List<HomeVideoItem> latestVideos = videos.take(30).map(_mapVideo).toList();
    final List<HomeVideoItem> featured = latestVideos.take(2).toList();
    final List<HomeDramaItem> shortDrama = dramas.take(30).map(_mapDrama).toList();
    final List<HomeLiveItem> liveNow = live.take(30).map(_mapLive).toList();

    final List<HomeVideoItem> recommended =
        (videos.skip(2).take(4).map(_mapVideo).toList()) +
            (latestVideos.isEmpty
                ? const <HomeVideoItem>[]
                : <HomeVideoItem>[latestVideos.first]);

    return HomePortalData(
      featured: featured,
      latestVideos: latestVideos,
      shortDrama: shortDrama,
      liveNow: liveNow,
      recommended: recommended,
      videosCount: videosCount,
      videosNextUrl: videosNextUrl,
      videosPreviousUrl: videosPreviousUrl,
      dramasNextUrl: dramasNextUrl,
      liveNextUrl: liveNextUrl,
    );
  }

  Future<HomeVideoPage> getVideoPage({
    String? pageUrl,
    String? category,
    String? accessType,
    int pageSize = defaultVideoPageSize,
  }) async {
    final _HomeVideoRows page = await _fetchVideoRows(
      pageUrl: pageUrl,
      category: category,
      accessType: accessType,
      pageSize: pageSize,
    );
    return HomeVideoPage(
      items: page.rows.map(_mapVideo).toList(),
      count: page.count,
      nextUrl: page.nextUrl,
      previousUrl: page.previousUrl,
    );
  }

  Future<_HomeVideoRows> _fetchVideoRows({
    String? pageUrl,
    String? category,
    String? accessType,
    int pageSize = defaultVideoPageSize,
  }) async {
    final String? trimmedCategory = category?.trim();
    final String? trimmedAccessType = accessType?.trim();
    final Map<String, dynamic> queryParameters = <String, dynamic>{
      'page_size': pageSize,
      if (trimmedCategory != null && trimmedCategory.isNotEmpty)
        'category': trimmedCategory,
      if (trimmedAccessType != null && trimmedAccessType.isNotEmpty)
        'access_type': trimmedAccessType,
    };
    final videoResponse = await _apiClient.get<dynamic>(
      pageUrl ?? Endpoints.publicVideos,
      queryParameters: pageUrl == null ? queryParameters : null,
    );
    return _HomeVideoRows(
      rows: _rows(videoResponse.data),
      count: _count(videoResponse.data),
      nextUrl: _next(videoResponse.data),
      previousUrl: _previous(videoResponse.data),
    );
  }

  List<Map<String, dynamic>> _rows(dynamic data) {
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    if (data is Map<String, dynamic>) {
      final dynamic results = data['results'];
      if (results is List) {
        return results.whereType<Map<String, dynamic>>().toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  int? _count(dynamic data) {
    if (data is Map<String, dynamic>) {
      return _int(data['count']);
    }
    return null;
  }

  String? _next(dynamic data) {
    if (data is Map<String, dynamic>) {
      return _str(data['next']);
    }
    return null;
  }

  String? _previous(dynamic data) {
    if (data is Map<String, dynamic>) {
      return _str(data['previous']);
    }
    return null;
  }

  HomeVideoItem _mapVideo(Map<String, dynamic> m) {
    final String title = _str(m['title']) ?? 'Untitled video';
    final String owner = _videoOwnerName(m) ?? '';
    final String views = _str(m['view_count']) ?? '0';
    return HomeVideoItem(
      id: _str(m['id']) ?? title,
      title: title,
      subtitle: '$owner • $views views',
      thumbnailUrl: _str(m['thumbnail_url']),
      videoUrl: _str(m['video_url']) ?? _str(m['playback_url']) ?? _str(m['file_url']),
      description: _str(m['description']) ?? _str(m['summary']),
      ownerName: owner.isEmpty ? null : owner,
      viewCount: _int(m['view_count']),
      category: _str(m['category']),
      categoryName: _str(m['category_name']),
      createdAt: _str(m['created_at']),
      accessType: _str(m['access_type']),
      previewSeconds: _int(m['preview_seconds']),
      canWatch: _bool(m['can_watch']),
      isLocked: _bool(m['is_locked']),
      lockReason: _str(m['lock_reason']),
    );
  }

  HomeDramaItem _mapDrama(Map<String, dynamic> m) {
    final String title = _str(m['title']) ?? 'Untitled drama';
    final int? total = _int(m['total_episodes']);
    final int? free = _int(m['free_episode_count']);
    final int? locked = _int(m['locked_episode_count']);
    return HomeDramaItem(
      id: _str(m['id']) ?? title,
      title: title,
      subtitle: _dramaMetadata(total: total, free: free, locked: locked),
      coverUrl: _str(m['cover_url']),
      thumbnailUrl: _str(m['thumbnail_url']),
      totalEpisodes: total,
      freeEpisodeCount: free,
      lockedEpisodeCount: locked,
      isCompleted:
          _bool(m['is_completed']) ?? _isCompletedStatus(m['status']),
    );
  }

  HomeLiveItem _mapLive(Map<String, dynamic> m) {
    final String title = _str(m['title']) ?? 'Live stream';
    final String owner = _str(m['owner_name']) ?? 'Host';
    final String viewers = _str(m['viewer_count']) ?? '0';
    final String? thumb = _str(m['thumbnail_url']) ??
        _str(m['preview_image_url']) ??
        _str(m['snapshot_url']);

    return HomeLiveItem(
      id: _str(m['id']) ?? title,
      title: title,
      subtitle: '$owner · $viewers watching',
      ownerName: owner,
      ownerAvatarUrl: _str(m['owner_avatar_url']),
      status: _str(m['status']),
      effectiveStatus: _str(m['effective_status']),
      djangoStatus: _str(m['django_status']),
      viewerCount: _int(m['viewer_count']),
      category: _str(m['category']),
      categoryName: _str(m['category_name']),
      thumbnailUrl: thumb,
      playbackUrl: _str(m['playback_url']),
      watchUrl: _str(m['watch_url']),
      createdAt: _str(m['created_at']),
    );
  }

  String? _videoOwnerName(Map<String, dynamic> m) {
    return _str(m['owner_name']) ??
        _nestedStr(m['owner'], 'username') ??
        _nestedStr(m['owner'], 'email') ??
        _nestedStr(m['creator'], 'name');
  }

  String _dramaMetadata({int? total, int? free, int? locked}) {
    return '${total ?? 0} episodes • Free ${free ?? 0} • '
        'Locked ${locked ?? 0}';
  }

  bool? _isCompletedStatus(dynamic value) {
    final String? status = _str(value)?.toLowerCase().trim();
    if (status == null || status.isEmpty) return null;
    return status == 'completed' ||
        status == 'complete' ||
        status == 'finished';
  }

  String? _nestedStr(dynamic value, String key) {
    if (value is Map<String, dynamic>) {
      return _str(value[key]);
    }
    return null;
  }

  String? _str(dynamic v) {
    if (v is String) return v;
    if (v is num) return v.toString();
    return null;
  }

  int? _int(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  bool? _bool(dynamic v) {
    if (v is bool) return v;
    if (v is String) {
      final String normalized = v.toLowerCase().trim();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return null;
  }
}

class _HomeVideoRows {
  const _HomeVideoRows({
    required this.rows,
    this.count,
    this.nextUrl,
    this.previousUrl,
  });

  final List<Map<String, dynamic>> rows;
  final int? count;
  final String? nextUrl;
  final String? previousUrl;
}
