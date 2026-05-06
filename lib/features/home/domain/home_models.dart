class HomeVideoItem {
  const HomeVideoItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.thumbnailUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? thumbnailUrl;
}

class HomeDramaItem {
  const HomeDramaItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.coverUrl,
    this.thumbnailUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? coverUrl;
  final String? thumbnailUrl;
}

class HomeLiveItem {
  const HomeLiveItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.ownerName,
    this.ownerAvatarUrl,
    this.status,
    this.viewerCount,
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
  final int? viewerCount;
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
    this.videosNextUrl,
    this.dramasNextUrl,
    this.liveNextUrl,
  });

  final List<HomeVideoItem> featured;
  final List<HomeVideoItem> latestVideos;
  final List<HomeDramaItem> shortDrama;
  final List<HomeLiveItem> liveNow;
  final List<HomeVideoItem> recommended;
  final String? videosNextUrl;
  final String? dramasNextUrl;
  final String? liveNextUrl;
}
