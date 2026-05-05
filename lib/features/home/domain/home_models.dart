class HomeVideoItem {
  const HomeVideoItem({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}

class HomeDramaItem {
  const HomeDramaItem({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}

class HomeLiveItem {
  const HomeLiveItem({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}

class HomePortalData {
  const HomePortalData({
    required this.featured,
    required this.latestVideos,
    required this.shortDrama,
    required this.liveNow,
    required this.recommended,
  });

  final List<HomeVideoItem> featured;
  final List<HomeVideoItem> latestVideos;
  final List<HomeDramaItem> shortDrama;
  final List<HomeLiveItem> liveNow;
  final List<HomeVideoItem> recommended;
}
