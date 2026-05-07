import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/features/home/data/mock_home_repository.dart';
import 'package:meow_media/features/home/domain/home_models.dart';
import 'package:meow_media/features/home/domain/home_repository.dart';
import 'package:meow_media/features/home/home_page.dart';

void main() {
  testWidgets('HomePage falls back to mock content when remote portal is empty',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomePage(
            remoteRepository: _EmptyHomeRepository(),
            mockRepository: MockHomeRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Showing local content.'), findsOneWidget);
    expect(find.text('Crimson Oath'), findsWidgets);
    expect(find.text('Creator Spotlight'), findsWidgets);
    expect(find.text('Street Food Guide'), findsWidgets);
    expect(find.text('Finance Live Desk'), findsWidgets);
  });

  testWidgets('HomePage falls back to mock content when remote portal throws',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomePage(
            remoteRepository: _ThrowingHomeRepository(),
            mockRepository: MockHomeRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Network unavailable. Showing local content.'),
      findsOneWidget,
    );
    expect(find.text('Crimson Oath'), findsWidgets);
    expect(find.text('Creator Spotlight'), findsWidgets);
    expect(find.text('Street Food Guide'), findsWidgets);
    expect(find.text('Finance Live Desk'), findsWidgets);
  });

  testWidgets('News tab uses mock news content after empty remote fallback',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomePage(
            remoteRepository: _EmptyHomeRepository(),
            mockRepository: MockHomeRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('News'));
    await tester.pumpAndSettle();

    expect(find.text('Street Food Guide'), findsWidgets);
    expect(find.text('Finance Live Desk'), findsWidgets);
    expect(find.text('No news content yet'), findsNothing);
    expect(find.text('Showing locally loaded news videos.'), findsNothing);
  });
}

class _EmptyHomeRepository implements HomeRepository {
  const _EmptyHomeRepository();

  @override
  Future<HomePortalData> getHomePortalData() async {
    return const HomePortalData(
      featured: <HomeVideoItem>[],
      latestVideos: <HomeVideoItem>[],
      shortDrama: <HomeDramaItem>[],
      liveNow: <HomeLiveItem>[],
      recommended: <HomeVideoItem>[],
    );
  }
}

class _ThrowingHomeRepository implements HomeRepository {
  const _ThrowingHomeRepository();

  @override
  Future<HomePortalData> getHomePortalData() async {
    throw Exception('remote unavailable');
  }
}
