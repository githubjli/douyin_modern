import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../domain/home_models.dart';
import '../domain/home_repository.dart';

class RemoteHomeRepository implements HomeRepository {
  RemoteHomeRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<HomePortalData> getHomePortalData() async {
    final videosResponse = await _apiClient.get<dynamic>(Endpoints.publicVideos);
    final dramasResponse = await _apiClient.get<dynamic>(Endpoints.dramas);
    final liveResponse = await _apiClient.get<dynamic>('/api/live/');

    final List<Map<String, dynamic>> videos = _rows(videosResponse.data);
    final List<Map<String, dynamic>> dramas = _rows(dramasResponse.data);
    final List<Map<String, dynamic>> live = _rows(liveResponse.data);

    final List<HomeVideoItem> latestVideos = videos.take(6).map(_mapVideo).toList();
    final List<HomeVideoItem> featured = latestVideos.take(2).toList();
    final List<HomeDramaItem> shortDrama = dramas.take(6).map(_mapDrama).toList();
    final List<HomeLiveItem> liveNow = live.take(6).map(_mapLive).toList();

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
    );
  }

  List<Map<String, dynamic>> _rows(dynamic data) {
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    if (data is Map<String, dynamic>) {
      final dynamic results = data['results'];
      if (results is List) return results.whereType<Map<String, dynamic>>().toList();
    }
    return <Map<String, dynamic>>[];
  }

  HomeVideoItem _mapVideo(Map<String, dynamic> m) {
    final String title = _str(m['title']) ?? 'Untitled video';
    final String owner = _str(m['owner_name']) ?? 'Creator';
    final String views = _str(m['view_count']) ?? '0';
    return HomeVideoItem(id: _str(m['id']) ?? title, title: title, subtitle: '$owner • $views views');
  }

  HomeDramaItem _mapDrama(Map<String, dynamic> m) {
    final String title = _str(m['title']) ?? 'Untitled drama';
    final String total = _str(m['total_episodes']) ?? '0';
    final String free = _str(m['free_episode_count']) ?? '0';
    final String locked = _str(m['locked_episode_count']) ?? '0';
    return HomeDramaItem(id: _str(m['id']) ?? title, title: title, subtitle: '$total episodes • Free $free • Locked $locked');
  }

  HomeLiveItem _mapLive(Map<String, dynamic> m) {
    final String title = _str(m['title']) ?? 'Live stream';
    final String owner = _str(m['owner_name']) ?? 'Host';
    final String viewers = _str(m['viewer_count']) ?? '0';
    return HomeLiveItem(id: _str(m['id']) ?? title, title: title, subtitle: '$owner • $viewers watching');
  }

  String? _str(dynamic v) {
    if (v is String) return v;
    if (v is num) return v.toString();
    return null;
  }
}
