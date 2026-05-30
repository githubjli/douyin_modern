class HomeVideoItem {
  const HomeVideoItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.thumbnailUrl,
    this.videoUrl,
    this.description,
    this.ownerName,
    this.ownerAvatarUrl,
    this.viewCount,
    this.category,
    this.categoryName,
    this.createdAt,
    this.accessType,
    this.previewSeconds,
    this.canWatch,
    this.isLocked,
    this.lockReason,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? description;
  final String? ownerName;
  final String? ownerAvatarUrl;
  final int? viewCount;
  final String? category;
  final String? categoryName;
  final String? createdAt;
  final String? accessType;
  final int? previewSeconds;
  final bool? canWatch;
  final bool? isLocked;
  final String? lockReason;

  bool get isMembershipVideo =>
      accessType?.trim().toLowerCase() == 'membership';

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (videoUrl != null) 'videoUrl': videoUrl,
        if (description != null) 'description': description,
        if (ownerName != null) 'ownerName': ownerName,
        if (ownerAvatarUrl != null) 'ownerAvatarUrl': ownerAvatarUrl,
        if (viewCount != null) 'viewCount': viewCount,
        if (category != null) 'category': category,
        if (categoryName != null) 'categoryName': categoryName,
        if (createdAt != null) 'createdAt': createdAt,
        if (accessType != null) 'accessType': accessType,
        if (previewSeconds != null) 'previewSeconds': previewSeconds,
        if (canWatch != null) 'canWatch': canWatch,
        if (isLocked != null) 'isLocked': isLocked,
        if (lockReason != null) 'lockReason': lockReason,
      };

  factory HomeVideoItem.fromJson(Map<String, dynamic> j) => HomeVideoItem(
        id: j['id'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        thumbnailUrl: j['thumbnailUrl'] as String?,
        videoUrl: j['videoUrl'] as String?,
        description: j['description'] as String?,
        ownerName: j['ownerName'] as String?,
        ownerAvatarUrl: j['ownerAvatarUrl'] as String?,
        viewCount: j['viewCount'] as int?,
        category: j['category'] as String?,
        categoryName: j['categoryName'] as String?,
        createdAt: j['createdAt'] as String?,
        accessType: j['accessType'] as String?,
        previewSeconds: j['previewSeconds'] as int?,
        canWatch: j['canWatch'] as bool?,
        isLocked: j['isLocked'] as bool?,
        lockReason: j['lockReason'] as String?,
      );
}

class HomeVideoPage {
  const HomeVideoPage({
    required this.items,
    this.count,
    this.nextUrl,
    this.previousUrl,
  });

  final List<HomeVideoItem> items;
  final int? count;
  final String? nextUrl;
  final String? previousUrl;
}

class HomeDramaItem {
  const HomeDramaItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.coverUrl,
    this.thumbnailUrl,
    this.totalEpisodes,
    this.freeEpisodeCount,
    this.lockedEpisodeCount,
    this.isCompleted,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? coverUrl;
  final String? thumbnailUrl;
  final int? totalEpisodes;
  final int? freeEpisodeCount;
  final int? lockedEpisodeCount;
  final bool? isCompleted;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (totalEpisodes != null) 'totalEpisodes': totalEpisodes,
        if (freeEpisodeCount != null) 'freeEpisodeCount': freeEpisodeCount,
        if (lockedEpisodeCount != null) 'lockedEpisodeCount': lockedEpisodeCount,
        if (isCompleted != null) 'isCompleted': isCompleted,
      };

  factory HomeDramaItem.fromJson(Map<String, dynamic> j) => HomeDramaItem(
        id: j['id'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        coverUrl: j['coverUrl'] as String?,
        thumbnailUrl: j['thumbnailUrl'] as String?,
        totalEpisodes: j['totalEpisodes'] as int?,
        freeEpisodeCount: j['freeEpisodeCount'] as int?,
        lockedEpisodeCount: j['lockedEpisodeCount'] as int?,
        isCompleted: j['isCompleted'] as bool?,
      );
}

class HomeLiveItem {
  const HomeLiveItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.ownerId,
    this.ownerName,
    this.ownerAvatarUrl,
    this.status,
    this.effectiveStatus,
    this.djangoStatus,
    this.viewerCount,
    this.category,
    this.categoryName,
    this.thumbnailUrl,
    this.playbackUrl,
    this.watchUrl,
    this.createdAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final int? ownerId;
  final String? ownerName;
  final String? ownerAvatarUrl;
  final String? status;
  final String? effectiveStatus;
  final String? djangoStatus;
  final int? viewerCount;
  final String? category;
  final String? categoryName;
  final String? thumbnailUrl;
  final String? playbackUrl;
  final String? watchUrl;
  final String? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        if (ownerId != null) 'ownerId': ownerId,
        if (ownerName != null) 'ownerName': ownerName,
        if (ownerAvatarUrl != null) 'ownerAvatarUrl': ownerAvatarUrl,
        if (status != null) 'status': status,
        if (effectiveStatus != null) 'effectiveStatus': effectiveStatus,
        if (djangoStatus != null) 'djangoStatus': djangoStatus,
        if (viewerCount != null) 'viewerCount': viewerCount,
        if (category != null) 'category': category,
        if (categoryName != null) 'categoryName': categoryName,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (playbackUrl != null) 'playbackUrl': playbackUrl,
        if (watchUrl != null) 'watchUrl': watchUrl,
        if (createdAt != null) 'createdAt': createdAt,
      };

  factory HomeLiveItem.fromJson(Map<String, dynamic> j) => HomeLiveItem(
        id: j['id'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        ownerId: j['ownerId'] as int?,
        ownerName: j['ownerName'] as String?,
        ownerAvatarUrl: j['ownerAvatarUrl'] as String?,
        status: j['status'] as String?,
        effectiveStatus: j['effectiveStatus'] as String?,
        djangoStatus: j['djangoStatus'] as String?,
        viewerCount: j['viewerCount'] as int?,
        category: j['category'] as String?,
        categoryName: j['categoryName'] as String?,
        thumbnailUrl: j['thumbnailUrl'] as String?,
        playbackUrl: j['playbackUrl'] as String?,
        watchUrl: j['watchUrl'] as String?,
        createdAt: j['createdAt'] as String?,
      );
}

class HomePortalData {
  const HomePortalData({
    required this.featured,
    required this.latestVideos,
    required this.shortDrama,
    required this.liveNow,
    required this.recommended,
    this.videosCount,
    this.videosNextUrl,
    this.videosPreviousUrl,
    this.dramasNextUrl,
    this.liveNextUrl,
  });

  final List<HomeVideoItem> featured;
  final List<HomeVideoItem> latestVideos;
  final List<HomeDramaItem> shortDrama;
  final List<HomeLiveItem> liveNow;
  final List<HomeVideoItem> recommended;
  final int? videosCount;
  final String? videosNextUrl;
  final String? videosPreviousUrl;
  final String? dramasNextUrl;
  final String? liveNextUrl;

  Map<String, dynamic> toJson() => {
        'featured': featured.map((e) => e.toJson()).toList(),
        'latestVideos': latestVideos.map((e) => e.toJson()).toList(),
        'shortDrama': shortDrama.map((e) => e.toJson()).toList(),
        'liveNow': liveNow.map((e) => e.toJson()).toList(),
        'recommended': recommended.map((e) => e.toJson()).toList(),
        if (videosCount != null) 'videosCount': videosCount,
        if (videosNextUrl != null) 'videosNextUrl': videosNextUrl,
        if (videosPreviousUrl != null) 'videosPreviousUrl': videosPreviousUrl,
        if (dramasNextUrl != null) 'dramasNextUrl': dramasNextUrl,
        if (liveNextUrl != null) 'liveNextUrl': liveNextUrl,
      };

  factory HomePortalData.fromJson(Map<String, dynamic> j) => HomePortalData(
        featured: _list(j['featured'], HomeVideoItem.fromJson),
        latestVideos: _list(j['latestVideos'], HomeVideoItem.fromJson),
        shortDrama: _list(j['shortDrama'], HomeDramaItem.fromJson),
        liveNow: _list(j['liveNow'], HomeLiveItem.fromJson),
        recommended: _list(j['recommended'], HomeVideoItem.fromJson),
        videosCount: j['videosCount'] as int?,
        videosNextUrl: j['videosNextUrl'] as String?,
        videosPreviousUrl: j['videosPreviousUrl'] as String?,
        dramasNextUrl: j['dramasNextUrl'] as String?,
        liveNextUrl: j['liveNextUrl'] as String?,
      );

  static List<T> _list<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(fromJson).toList();
  }
}
