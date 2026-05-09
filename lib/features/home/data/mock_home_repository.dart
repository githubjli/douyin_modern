import '../domain/home_models.dart';
import '../domain/home_repository.dart';

class MockHomeRepository implements HomeRepository {
  const MockHomeRepository();

  @override
  Future<HomePortalData> getHomePortalData({bool authenticated = false}) async {
    return const HomePortalData(
      featured: <HomeVideoItem>[
        HomeVideoItem(id: 'f1', title: 'Midnight Casebook', subtitle: 'Top drama this week'),
        HomeVideoItem(id: 'f2', title: 'City Live Report', subtitle: 'Breaking scenes now'),
      ],
      latestVideos: <HomeVideoItem>[
        HomeVideoItem(
          id: 'v1',
          title: 'Street Food Guide',
          subtitle: 'Meow News · 48K views',
          description: 'A quick public video update from the Meow News desk.',
          ownerName: 'Meow News',
          viewCount: 48000,
          category: 'news',
          categoryName: 'News',
          createdAt: '2026-05-01T12:00:00Z',
        ),
        HomeVideoItem(id: 'v2', title: 'Morning Fitness', subtitle: '9m • 21K views'),
      ],
      shortDrama: <HomeDramaItem>[
        HomeDramaItem(
          id: 'd1',
          title: 'Crimson Oath',
          subtitle: '12 episodes • Free 3 • Locked 9',
          totalEpisodes: 12,
          freeEpisodeCount: 3,
          lockedEpisodeCount: 9,
        ),
        HomeDramaItem(
          id: 'd2',
          title: 'Silent Signal',
          subtitle: '8 episodes • Free 8 • Locked 0',
          totalEpisodes: 8,
          freeEpisodeCount: 8,
          lockedEpisodeCount: 0,
          isCompleted: true,
        ),
      ],
      liveNow: <HomeLiveItem>[
        HomeLiveItem(
          id: 'l1',
          title: 'Finance Live Desk',
          subtitle: 'Finance Live Desk · 1200 watching',
          ownerName: 'Finance Live Desk',
          status: 'live',
          viewerCount: 1200,
          category: 'news',
          categoryName: 'News',
        ),
        HomeLiveItem(
          id: 'l2',
          title: 'Travel Street Cam',
          subtitle: 'Travel Street Cam · 890 watching',
          ownerName: 'Travel Street Cam',
          status: 'ready',
          viewerCount: 890,
          category: 'travel',
          categoryName: 'Travel',
        ),
      ],
      recommended: <HomeVideoItem>[
        HomeVideoItem(id: 'r1', title: 'Creator Spotlight', subtitle: 'Weekly editorial pick'),
        HomeVideoItem(id: 'r2', title: 'Weekend Watchlist', subtitle: 'Drama + video mix'),
        HomeVideoItem(id: 'r3', title: 'Local Trend Radar', subtitle: 'Top rising topics'),
        HomeVideoItem(id: 'r4', title: 'New Voices', subtitle: 'Fresh creators to follow'),
      ],
    );
  }

  Future<HomeVideoPage> getVideoPage({
    String? pageUrl,
    String? category,
    bool authenticated = false,
  }) async {
    final HomePortalData data = await getHomePortalData();
    final String? selectedCategory = category?.trim();
    final List<HomeVideoItem> items = data.latestVideos
        .where(
          (HomeVideoItem item) =>
              selectedCategory == null || selectedCategory.isEmpty
                  ? true
                  : item.category == selectedCategory ||
                      item.categoryName == selectedCategory,
        )
        .toList();
    return HomeVideoPage(items: items, count: items.length);
  }
}
