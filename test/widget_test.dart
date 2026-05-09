import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meow_media/app/app.dart';
import 'package:meow_media/features/home/domain/home_models.dart';
import 'package:meow_media/features/home/domain/home_repository.dart';
import 'package:meow_media/features/video_detail/video_detail_page.dart';
import 'package:meow_media/shared/main_shell.dart';
import 'package:meow_media/features/auth/application/auth_providers.dart';
import 'package:meow_media/features/auth/domain/auth_repository.dart';
import 'package:meow_media/features/auth/domain/auth_session.dart';

void main() {
  testWidgets('app shell renders polished bottom navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MeowMediaApp(
          enableFeedVideo: false,
          enableRemoteFeed: false,
          enableRemoteHome: false,
          enableRemoteMembership: false,
        ),
      ),
    );

    final Finder bottomNav = find.byType(BottomNavigationBar);
    expect(bottomNav, findsOneWidget);

    expect(find.descendant(of: bottomNav, matching: find.text('Home')),
        findsOneWidget);
    expect(find.descendant(of: bottomNav, matching: find.text('Shorts')),
        findsOneWidget);
    expect(find.descendant(of: bottomNav, matching: find.text('Member')),
        findsOneWidget);
    expect(find.descendant(of: bottomNav, matching: find.text('Profile')),
        findsOneWidget);

    expect(
      find.descendant(of: bottomNav, matching: find.byIcon(Icons.home_rounded)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bottomNav,
        matching: find.byIcon(Icons.play_circle_outline_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bottomNav, matching: find.byIcon(Icons.add_circle)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bottomNav,
        matching: find.byIcon(Icons.star_border_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bottomNav,
        matching: find.byIcon(Icons.person_outline_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Membership guest Sign in switches to Profile tab',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(_SignedOutAuthRepository()),
        ],
        child: const MeowMediaApp(
          enableFeedVideo: false,
          enableRemoteFeed: false,
          enableRemoteHome: false,
          enableRemoteMembership: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Member'));
    await tester.pumpAndSettle();

    expect(find.text('Guest'), findsOneWidget);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    final BottomNavigationBar bottomNav = tester.widget(
      find.byType(BottomNavigationBar),
    );
    expect(bottomNav.currentIndex, 4);
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('Home locked VIP Sign in switches to Profile tab',
      (WidgetTester tester) async {
    const HomePortalData portal = HomePortalData(
      featured: <HomeVideoItem>[],
      latestVideos: <HomeVideoItem>[
        HomeVideoItem(
          id: 'shell-home-locked-vip',
          title: 'Shell Home Locked VIP',
          subtitle: 'VIP Studio • 120 views',
          accessType: 'membership',
          canWatch: false,
          isLocked: true,
        ),
      ],
      shortDrama: <HomeDramaItem>[],
      liveNow: <HomeLiveItem>[],
      recommended: <HomeVideoItem>[],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(_SignedOutAuthRepository()),
        ],
        child: const MaterialApp(
          home: MainShell(
            enableFeedVideo: false,
            enableRemoteFeed: false,
            enableRemoteMembership: false,
            homeRepository: _HomeRepositoryFake(portal),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder titleFinder = find.text('Shell Home Locked VIP').first;
    await tester.ensureVisible(titleFinder);
    await tester.pumpAndSettle();

    final Finder visibleTitleFinder =
        find.text('Shell Home Locked VIP').hitTestable().first;
    await tester.tap(visibleTitleFinder);
    await tester.pumpAndSettle();

    expect(find.byType(VideoDetailPage), findsOneWidget);
    expect(find.text('VIP video locked'), findsOneWidget);

    final Finder signInFinder = find.text('Sign in').first;
    await tester.ensureVisible(signInFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in').hitTestable().first);
    await tester.pumpAndSettle();

    final BottomNavigationBar bottomNav = tester.widget(
      find.byType(BottomNavigationBar),
    );
    expect(bottomNav.currentIndex, 4);
    expect(find.text('Sign in to continue'), findsOneWidget);
  });
}

class _SignedOutAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> getCurrentSession() async {
    return const AuthSession(
      isSignedIn: false,
      userId: null,
      displayName: 'Guest',
    );
  }

  @override
  Future<AuthSession> login({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession> refreshSession() => getCurrentSession();

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    throw UnimplementedError();
  }
}


class _HomeRepositoryFake implements HomeRepository {
  const _HomeRepositoryFake(this.portal);

  final HomePortalData portal;

  @override
  Future<HomePortalData> getHomePortalData({bool authenticated = false}) async {
    return portal;
  }
}
