import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/core/network/api_client.dart';
import 'package:meow_media/features/home/data/mock_home_repository.dart';
import 'package:meow_media/features/home/data/remote_home_repository.dart';
import 'package:meow_media/features/home/domain/home_models.dart';
import 'package:meow_media/features/home/domain/home_repository.dart';
import 'package:meow_media/features/home/home_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const HomePortalData emptyPortal = HomePortalData(
    featured: <HomeVideoItem>[],
    latestVideos: <HomeVideoItem>[],
    shortDrama: <HomeDramaItem>[],
    liveNow: <HomeLiveItem>[],
    recommended: <HomeVideoItem>[],
  );

  Future<void> pumpHomePage(
    WidgetTester tester, {
    required HomeRepository remoteRepository,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePage(
            remoteRepository: remoteRepository,
            mockRepository: const MockHomeRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty remote portal falls back to mock Home content',
      (WidgetTester tester) async {
    await pumpHomePage(
      tester,
      remoteRepository: _HomePortalRepository.value(emptyPortal),
    );

    expect(find.text('Showing local content.'), findsOneWidget);
    expect(find.text('Crimson Oath'), findsWidgets);
    expect(find.text('Street Food Guide'), findsWidgets);
    expect(find.text('Creator Spotlight'), findsWidgets);
  });

  testWidgets('thrown remote request falls back to mock Home content',
      (WidgetTester tester) async {
    await pumpHomePage(
      tester,
      remoteRepository: _HomePortalRepository.error(Exception('offline')),
    );

    expect(
      find.text('Network unavailable. Showing local content.'),
      findsOneWidget,
    );
    expect(find.text('Crimson Oath'), findsWidgets);
    expect(find.text('Street Food Guide'), findsWidgets);
    expect(find.text('Creator Spotlight'), findsWidgets);
  });

  testWidgets('News tab after fallback shows mock News video/live content',
      (WidgetTester tester) async {
    await pumpHomePage(
      tester,
      remoteRepository: _HomePortalRepository.value(emptyPortal),
    );

    await tester.tap(find.text('News'));
    await tester.pumpAndSettle();

    expect(find.text('Street Food Guide'), findsWidgets);
    expect(find.text('Finance Live Desk'), findsWidgets);
  });

  testWidgets('Home video cards show VIP badge for membership videos',
      (WidgetTester tester) async {
    const HomePortalData vipPortal = HomePortalData(
      featured: <HomeVideoItem>[],
      latestVideos: <HomeVideoItem>[
        HomeVideoItem(
          id: 'vip-video',
          title: 'Members Preview',
          subtitle: 'VIP Studio • 120 views',
          accessType: 'membership',
        ),
      ],
      shortDrama: <HomeDramaItem>[],
      liveNow: <HomeLiveItem>[],
      recommended: <HomeVideoItem>[],
    );

    await pumpHomePage(
      tester,
      remoteRepository: _HomePortalRepository.value(vipPortal),
    );

    expect(find.text('Members Preview'), findsWidgets);
    expect(find.text('VIP'), findsWidgets);
  });

  testWidgets('remote Home portal load requests videos with authentication',
      (WidgetTester tester) async {
    final _AuthenticatedHomeRepository remoteRepository =
        _AuthenticatedHomeRepository(portal: emptyPortal);

    await pumpHomePage(tester, remoteRepository: remoteRepository);

    expect(remoteRepository.portalAuthenticated, isTrue);
  });

  testWidgets('remote News category request uses authentication',
      (WidgetTester tester) async {
    final _TrackingRemoteHomeRepository remoteRepository =
        _TrackingRemoteHomeRepository(portal: _portalWithPaging());

    await pumpHomePage(tester, remoteRepository: remoteRepository);

    expect(remoteRepository.videoCalls, isNotEmpty);
    expect(remoteRepository.videoCalls.first.category, 'news');
    expect(remoteRepository.videoCalls.first.authenticated, isTrue);
  });

  testWidgets('remote Video category and load more requests use authentication',
      (WidgetTester tester) async {
    final _TrackingRemoteHomeRepository remoteRepository =
        _TrackingRemoteHomeRepository(portal: _portalWithPaging());

    await pumpHomePage(tester, remoteRepository: remoteRepository);

    await tester.tap(find.text('Videos'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sports'));
    await tester.pumpAndSettle();

    expect(
      remoteRepository.videoCalls.any(
        (_VideoPageCall call) =>
            call.category == 'sports' && call.authenticated == true,
      ),
      isTrue,
    );

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(
      remoteRepository.videoCalls.any(
        (_VideoPageCall call) =>
            call.pageUrl == 'https://example.com/videos-next' &&
            call.authenticated == true,
      ),
      isTrue,
    );
  });

  testWidgets('remote News load more request uses authentication',
      (WidgetTester tester) async {
    final _TrackingRemoteHomeRepository remoteRepository =
        _TrackingRemoteHomeRepository(portal: _portalWithPaging());

    await pumpHomePage(tester, remoteRepository: remoteRepository);

    await tester.tap(find.text('News'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(
      remoteRepository.videoCalls.any(
        (_VideoPageCall call) =>
            call.pageUrl == 'https://example.com/news-next' &&
            call.authenticated == true,
      ),
      isTrue,
    );
  });

  testWidgets(
      'contradictory fallback/empty messages are absent when mock News content exists',
      (WidgetTester tester) async {
    await pumpHomePage(
      tester,
      remoteRepository: _HomePortalRepository.value(emptyPortal),
    );

    await tester.tap(find.text('News'));
    await tester.pumpAndSettle();

    expect(find.text('Street Food Guide'), findsWidgets);
    expect(find.text('Finance Live Desk'), findsWidgets);
    expect(find.text('No news content yet'), findsNothing);
    expect(find.text('Showing locally loaded news videos.'), findsNothing);
  });
}

class _HomePortalRepository implements HomeRepository {
  const _HomePortalRepository._(this._load);

  factory _HomePortalRepository.value(HomePortalData data) {
    return _HomePortalRepository._(() async => data);
  }

  factory _HomePortalRepository.error(Object error) {
    return _HomePortalRepository._(() => Future<HomePortalData>.error(error));
  }

  final Future<HomePortalData> Function() _load;

  @override
  Future<HomePortalData> getHomePortalData({bool authenticated = false}) =>
      _load();
}

class _AuthenticatedHomeRepository implements HomeRepository {
  _AuthenticatedHomeRepository({required this.portal});

  final HomePortalData portal;
  bool? portalAuthenticated;

  @override
  Future<HomePortalData> getHomePortalData({bool authenticated = false}) async {
    portalAuthenticated = authenticated;
    return portal;
  }
}

class _TrackingRemoteHomeRepository extends RemoteHomeRepository {
  _TrackingRemoteHomeRepository({required this.portal})
      : super(apiClient: ApiClient());

  final HomePortalData portal;
  final List<_VideoPageCall> videoCalls = <_VideoPageCall>[];

  @override
  Future<HomePortalData> getHomePortalData({bool authenticated = false}) async {
    return portal;
  }

  @override
  Future<HomeVideoPage> getVideoPage({
    String? pageUrl,
    String? category,
    String? accessType,
    int pageSize = RemoteHomeRepository.defaultVideoPageSize,
    bool authenticated = false,
  }) async {
    videoCalls.add(
      _VideoPageCall(
        pageUrl: pageUrl,
        category: category,
        authenticated: authenticated,
      ),
    );
    if (pageUrl == 'https://example.com/videos-next') {
      return const HomeVideoPage(
        items: <HomeVideoItem>[
          HomeVideoItem(
            id: 'video-next',
            title: 'Next Video',
            subtitle: 'Remote • 3 views',
          ),
        ],
      );
    }
    if (pageUrl == 'https://example.com/news-next') {
      return const HomeVideoPage(
        items: <HomeVideoItem>[
          HomeVideoItem(
            id: 'news-next',
            title: 'Next News',
            subtitle: 'Remote • 4 views',
            category: 'news',
            categoryName: 'News',
          ),
        ],
      );
    }
    if (category == 'news') {
      return const HomeVideoPage(
        items: <HomeVideoItem>[
          HomeVideoItem(
            id: 'news-remote',
            title: 'Remote News',
            subtitle: 'Remote • 1 view',
            category: 'news',
            categoryName: 'News',
          ),
        ],
        nextUrl: 'https://example.com/news-next',
      );
    }
    if (category == 'sports') {
      return const HomeVideoPage(
        items: <HomeVideoItem>[
          HomeVideoItem(
            id: 'sports-remote',
            title: 'Remote Sports',
            subtitle: 'Remote • 2 views',
            category: 'sports',
            categoryName: 'Sports',
          ),
        ],
      );
    }
    return const HomeVideoPage(items: <HomeVideoItem>[]);
  }
}

class _VideoPageCall {
  const _VideoPageCall({
    required this.pageUrl,
    required this.category,
    required this.authenticated,
  });

  final String? pageUrl;
  final String? category;
  final bool authenticated;
}

HomePortalData _portalWithPaging() {
  return const HomePortalData(
    featured: <HomeVideoItem>[],
    latestVideos: <HomeVideoItem>[
      HomeVideoItem(
        id: 'news-local',
        title: 'Local News',
        subtitle: 'Remote • 1 view',
        category: 'news',
        categoryName: 'News',
      ),
      HomeVideoItem(
        id: 'sports-local',
        title: 'Local Sports',
        subtitle: 'Remote • 2 views',
        category: 'sports',
        categoryName: 'Sports',
      ),
    ],
    shortDrama: <HomeDramaItem>[],
    liveNow: <HomeLiveItem>[],
    recommended: <HomeVideoItem>[],
    videosNextUrl: 'https://example.com/videos-next',
  );
}
