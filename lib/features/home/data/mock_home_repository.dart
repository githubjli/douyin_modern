import '../domain/home_models.dart';
import '../domain/home_repository.dart';

class MockHomeRepository implements HomeRepository {
  const MockHomeRepository();

  @override
  Future<HomePortalData> getHomePortalData() async {
    return const HomePortalData(
      featured: <HomeVideoItem>[
        HomeVideoItem(id: 'f1', title: 'Midnight Casebook', subtitle: 'Top drama this week'),
        HomeVideoItem(id: 'f2', title: 'City Live Report', subtitle: 'Breaking scenes now'),
      ],
      latestVideos: <HomeVideoItem>[
        HomeVideoItem(id: 'v1', title: 'Street Food Guide', subtitle: '12m • 48K views'),
        HomeVideoItem(id: 'v2', title: 'Morning Fitness', subtitle: '9m • 21K views'),
      ],
      shortDrama: <HomeDramaItem>[
        HomeDramaItem(id: 'd1', title: 'Crimson Oath', subtitle: 'EP 12 • Free 3'),
        HomeDramaItem(id: 'd2', title: 'Silent Signal', subtitle: 'EP 8 • 2 points'),
      ],
      liveNow: <HomeLiveItem>[
        HomeLiveItem(id: 'l1', title: 'Finance Live Desk', subtitle: '1.2K watching'),
        HomeLiveItem(id: 'l2', title: 'Travel Street Cam', subtitle: '890 watching'),
      ],
      recommended: <HomeVideoItem>[
        HomeVideoItem(id: 'r1', title: 'Creator Spotlight', subtitle: 'Weekly editorial pick'),
        HomeVideoItem(id: 'r2', title: 'Weekend Watchlist', subtitle: 'Drama + video mix'),
        HomeVideoItem(id: 'r3', title: 'Local Trend Radar', subtitle: 'Top rising topics'),
        HomeVideoItem(id: 'r4', title: 'New Voices', subtitle: 'Fresh creators to follow'),
      ],
    );
  }

  Future<HomeVideoPage> getVideoPage({String? pageUrl, String? category}) async {
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
