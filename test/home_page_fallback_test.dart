import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/features/home/data/mock_home_repository.dart';
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
  Future<HomePortalData> getHomePortalData() => _load();
}
