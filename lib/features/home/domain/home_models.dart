class HomeVideoItem {
  const HomeVideoItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.thumbnailUrl,
    this.videoUrl,
    this.description,
    this.ownerName,
    this.viewCount,
    this.category,
    this.categoryName,
    this.createdAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? description;
  final String? ownerName;
  final int? viewCount;
  final String? category;
  final String? categoryName;
  final String? createdAt;
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
}

class HomeLiveItem {
  const HomeLiveItem({
    required this.id,
    required this.title,
    required this.subtitle,
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
}
