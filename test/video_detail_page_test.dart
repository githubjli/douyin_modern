import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/core/network/api_client.dart';
import 'package:meow_media/core/network/api_error.dart';
import 'package:meow_media/core/network/endpoints.dart';
import 'package:meow_media/features/auth/application/auth_providers.dart';
import 'package:meow_media/features/auth/domain/auth_repository.dart';
import 'package:meow_media/features/auth/domain/auth_session.dart';
import 'package:meow_media/features/home/domain/home_models.dart';
import 'package:meow_media/features/video_detail/video_detail_page.dart';
import 'package:video_player/video_player.dart';

void main() {
  Future<ProviderContainer> pumpVideoDetail(
    WidgetTester tester, {
    required HomeVideoItem video,
    bool isSignedIn = true,
    ApiClient? apiClient,
    bool loadRemoteDetail = false,
    Key? key,
    ProviderContainer? container,
    AuthRepository? authRepository,
    bool settle = true,
    VoidCallback? onSignInPressed,
    VoidCallback? onSubscribePressed,
  }) async {
    final ProviderContainer effectiveContainer = container ??
        ProviderContainer(
          overrides: <Override>[
            authRepositoryProvider.overrideWithValue(
              authRepository ?? _FakeAuthRepository(isSignedIn: isSignedIn),
            ),
          ],
        );
    if (container == null) addTearDown(effectiveContainer.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: effectiveContainer,
        child: MaterialApp(
          home: VideoDetailPage(
            key: key,
            video: video,
            apiClient: apiClient,
            loadRemoteDetail: loadRemoteDetail,
            onSignInPressed: onSignInPressed,
            onSubscribePressed: onSubscribePressed,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return effectiveContainer;
  }

  testWidgets('locked VIP signed-out Sign in CTA triggers callback',
      (WidgetTester tester) async {
    bool signInPressed = false;

    await pumpVideoDetail(
      tester,
      isSignedIn: false,
      onSignInPressed: () {
        signInPressed = true;
      },
      video: const HomeVideoItem(
        id: 'vip-locked-sign-in-callback',
        title: 'Locked VIP Preview',
        subtitle: 'VIP Studio • 120 views',
        accessType: 'membership',
        canWatch: false,
        isLocked: true,
      ),
    );

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(signInPressed, isTrue);
  });

  testWidgets('locked VIP signed-in Subscribe CTA triggers callback',
      (WidgetTester tester) async {
    bool subscribePressed = false;

    await pumpVideoDetail(
      tester,
      onSubscribePressed: () {
        subscribePressed = true;
      },
      video: const HomeVideoItem(
        id: 'vip-locked-subscribe-callback',
        title: 'Members Locked Cut',
        subtitle: 'VIP Studio • 120 views',
        accessType: 'membership',
        canWatch: false,
        isLocked: true,
        videoUrl: 'https://example.com/vip.mp4',
      ),
    );

    await tester.tap(find.text('Subscribe'));
    await tester.pump();

    expect(subscribePressed, isTrue);
  });

  testWidgets('auth checking does not show Sign in on locked VIP',
      (WidgetTester tester) async {
    await pumpVideoDetail(
      tester,
      authRepository: _NeverCompletingAuthRepository(),
      settle: false,
      video: const HomeVideoItem(
        id: 'vip-locked-checking',
        title: 'Checking Locked Cut',
        subtitle: 'VIP Studio • 120 views',
        accessType: 'membership',
        canWatch: false,
        isLocked: true,
      ),
    );

    expect(find.text('VIP video locked'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('loads remote detail with authenticated request',
      (WidgetTester tester) async {
    final _FakeApiClient apiClient = _FakeApiClient(<String, dynamic>{
      'id': 42,
      'title': 'Unlocked Remote VIP',
      'access_type': 'membership',
      'can_watch': true,
      'is_locked': false,
      'file_url': 'https://example.com/member.mp4',
    });

    await pumpVideoDetail(
      tester,
      video: const HomeVideoItem(
        id: '42',
        title: 'Local VIP',
        subtitle: 'VIP Studio • 120 views',
        accessType: 'membership',
        canWatch: false,
        isLocked: true,
      ),
      apiClient: apiClient,
      loadRemoteDetail: true,
    );

    expect(apiClient.requestedPath, Endpoints.publicVideoDetail(42));
    expect(apiClient.requestedAuthenticated, isTrue);
    expect(find.text('Playback preview'), findsOneWidget);
    expect(find.text('VIP video locked'), findsNothing);
  });

  testWidgets(
    'unlocked VIP remains playable when remote detail has transient failure',
    (WidgetTester tester) async {
      final _FakeApiClient apiClient = _FakeApiClient.error(
        const ApiError(message: 'Network unavailable'),
      );

      await pumpVideoDetail(
        tester,
        video: const HomeVideoItem(
          id: '99',
          title: 'Unlocked Local VIP',
          subtitle: 'VIP Studio • 120 views',
          accessType: 'membership',
          canWatch: true,
          isLocked: false,
          videoUrl: 'https://example.com/member.mp4',
        ),
        apiClient: apiClient,
        loadRemoteDetail: true,
      );

      expect(apiClient.requestedAuthenticated, isTrue);
      expect(find.text('Playback preview'), findsOneWidget);
      expect(find.text('VIP video locked'), findsNothing);
      expect(find.text('Subscribe'), findsNothing);
      expect(find.text('Sign in'), findsNothing);
    },
  );

  testWidgets(
    'unlocked VIP state survives later transient detail failure',
    (WidgetTester tester) async {
      const Key detailKey = ValueKey<String>('vip-detail');
      const HomeVideoItem lockedListVideo = HomeVideoItem(
        id: '100',
        title: 'Locked Local VIP',
        subtitle: 'VIP Studio • 120 views',
        accessType: 'membership',
        canWatch: false,
        isLocked: true,
      );
      final _FakeApiClient successClient = _FakeApiClient(<String, dynamic>{
        'id': 100,
        'title': 'Unlocked Remote VIP',
        'access_type': 'membership',
        'can_watch': true,
        'is_locked': false,
        'file_url': 'https://example.com/member.mp4',
      });

      final ProviderContainer container = await pumpVideoDetail(
        tester,
        key: detailKey,
        video: lockedListVideo,
        apiClient: successClient,
        loadRemoteDetail: true,
      );

      expect(find.text('Playback preview'), findsOneWidget);
      expect(find.text('VIP video locked'), findsNothing);

      final _FakeApiClient failureClient = _FakeApiClient.error(
        const ApiError(message: 'Server error', statusCode: 500),
      );

      await pumpVideoDetail(
        tester,
        key: detailKey,
        video: lockedListVideo,
        apiClient: failureClient,
        loadRemoteDetail: true,
        container: container,
      );

      expect(failureClient.requestedAuthenticated, isTrue);
      expect(find.text('Playback preview'), findsOneWidget);
      expect(find.text('VIP video locked'), findsNothing);
      expect(find.text('Subscribe'), findsNothing);
      expect(find.text('Sign in'), findsNothing);
    },
  );

  testWidgets(
    'partial remote detail does not relock previously unlocked VIP state',
    (WidgetTester tester) async {
      const Key detailKey = ValueKey<String>('vip-detail-partial');
      const HomeVideoItem lockedListVideo = HomeVideoItem(
        id: '103',
        title: 'Locked Local VIP',
        subtitle: 'VIP Studio • 120 views',
        accessType: 'membership',
        canWatch: false,
        isLocked: true,
      );
      final _FakeApiClient unlockClient = _FakeApiClient(<String, dynamic>{
        'id': 103,
        'title': 'Unlocked Remote VIP',
        'access_type': 'membership',
        'can_watch': true,
        'is_locked': false,
        'file_url': 'https://example.com/member.mp4',
      });

      final ProviderContainer container = await pumpVideoDetail(
        tester,
        key: detailKey,
        video: lockedListVideo,
        apiClient: unlockClient,
        loadRemoteDetail: true,
      );

      expect(find.text('Playback preview'), findsOneWidget);
      expect(find.text('VIP video locked'), findsNothing);

      final _FakeApiClient partialClient = _FakeApiClient(<String, dynamic>{
        'id': 103,
        'title': 'Partial Remote VIP',
        'access_type': 'membership',
      });

      await pumpVideoDetail(
        tester,
        key: detailKey,
        video: lockedListVideo,
        apiClient: partialClient,
        loadRemoteDetail: true,
        container: container,
      );

      expect(partialClient.requestedAuthenticated, isTrue);
      expect(find.text('Playback preview'), findsOneWidget);
      expect(find.text('VIP video locked'), findsNothing);
      expect(find.text('Subscribe'), findsNothing);
      expect(find.text('Sign in'), findsNothing);
    },
  );

  testWidgets(
    'explicit locked remote detail response keeps VIP locked for signed-in user',
    (WidgetTester tester) async {
      final _FakeApiClient apiClient = _FakeApiClient(<String, dynamic>{
        'id': 101,
        'title': 'Locked Remote VIP',
        'access_type': 'membership',
        'can_watch': false,
        'is_locked': true,
        'lock_reason': 'membership_required',
        'file_url': 'https://example.com/member.mp4',
      });

      await pumpVideoDetail(
        tester,
        video: const HomeVideoItem(
          id: '101',
          title: 'Unlocked Local VIP',
          subtitle: 'VIP Studio • 120 views',
          accessType: 'membership',
          canWatch: true,
          isLocked: false,
          videoUrl: 'https://example.com/member.mp4',
        ),
        apiClient: apiClient,
        loadRemoteDetail: true,
      );

      expect(find.text('VIP video locked'), findsOneWidget);
      expect(find.text('Subscribe'), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
      expect(find.text('Playback preview'), findsNothing);
      expect(find.byType(VideoPlayer), findsNothing);
    },
  );

  for (final int statusCode in <int>[401, 403]) {
    testWidgets(
      'auth denied $statusCode remote detail uses current signed-out CTA',
      (WidgetTester tester) async {
        final _FakeApiClient apiClient = _FakeApiClient.error(
          ApiError(message: 'Auth denied', statusCode: statusCode),
        );

        await pumpVideoDetail(
          tester,
          isSignedIn: false,
          video: const HomeVideoItem(
            id: '102',
            title: 'Unlocked Local VIP',
            subtitle: 'VIP Studio • 120 views',
            accessType: 'membership',
            canWatch: true,
            isLocked: false,
            videoUrl: 'https://example.com/member.mp4',
          ),
          apiClient: apiClient,
          loadRemoteDetail: true,
        );

        expect(find.text('VIP video locked'), findsOneWidget);
        expect(find.text('Sign in'), findsOneWidget);
        expect(find.text('Subscribe'), findsNothing);
        expect(find.text('Playback preview'), findsNothing);
        expect(find.byType(VideoPlayer), findsNothing);
      },
    );
  }

  testWidgets('auth denied remote detail uses signed-in Subscribe CTA',
      (WidgetTester tester) async {
    final _FakeApiClient apiClient = _FakeApiClient.error(
      const ApiError(message: 'Auth denied', statusCode: 401),
    );

    await pumpVideoDetail(
      tester,
      video: const HomeVideoItem(
        id: '104',
        title: 'Unlocked Local VIP',
        subtitle: 'VIP Studio • 120 views',
        accessType: 'membership',
        canWatch: true,
        isLocked: false,
        videoUrl: 'https://example.com/member.mp4',
      ),
      apiClient: apiClient,
      loadRemoteDetail: true,
    );

    expect(find.text('VIP video locked'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('locked VIP detail for anonymous user shows Sign in',
      (WidgetTester tester) async {
    await pumpVideoDetail(
      tester,
      isSignedIn: false,
      video: const HomeVideoItem(
        id: 'vip-locked-anonymous',
        title: 'Locked VIP Preview',
        subtitle: 'VIP Studio • 120 views',
        accessType: 'membership',
        canWatch: false,
        isLocked: true,
      ),
    );

    expect(find.text('VIP video locked'), findsOneWidget);
    expect(find.text('VIP locked'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Subscribe'), findsNothing);
    expect(find.text('Playback preview'), findsNothing);
    expect(find.byType(VideoPlayer), findsNothing);
  });

  testWidgets('locked VIP detail for signed-in non-member shows Subscribe',
      (WidgetTester tester) async {
    await pumpVideoDetail(
      tester,
      video: const HomeVideoItem(
        id: 'vip-locked-signed-in',
        title: 'Members Locked Cut',
        subtitle: 'VIP Studio • 120 views',
        accessType: 'membership',
        canWatch: false,
        isLocked: true,
        videoUrl: 'https://example.com/vip.mp4',
      ),
    );

    expect(find.text('VIP video locked'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('Playback preview'), findsNothing);
    expect(find.byType(VideoPlayer), findsNothing);
  });

  testWidgets('logout changes locked VIP CTA from Subscribe to Sign in',
      (WidgetTester tester) async {
    final _FakeAuthRepository authRepository = _FakeAuthRepository(
      isSignedIn: true,
    );
    final ProviderContainer container = await pumpVideoDetail(
      tester,
      authRepository: authRepository,
      loadRemoteDetail: false,
      video: const HomeVideoItem(
        id: 'vip-locked-logout',
        title: 'Logout Locked VIP Cut',
        subtitle: 'VIP Studio • 120 views',
        accessType: 'membership',
        isLocked: true,
        canWatch: false,
      ),
    );

    expect(find.text('Subscribe'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);

    await container.read(authControllerProvider.notifier).logout();
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Subscribe'), findsNothing);
  });

  testWidgets(
    'auth error with previous signed-in session shows Subscribe not Sign in',
    (WidgetTester tester) async {
      final _FakeAuthRepository authRepository = _FakeAuthRepository(
        isSignedIn: true,
      );

      final ProviderContainer container = await pumpVideoDetail(
        tester,
        authRepository: authRepository,
        video: const HomeVideoItem(
          id: 'vip-locked-auth-error',
          title: 'Members Locked Cut',
          subtitle: 'VIP Studio • 120 views',
          accessType: 'membership',
          canWatch: false,
          isLocked: true,
          videoUrl: 'https://example.com/vip.mp4',
        ),
      );

      authRepository.currentSessionError = Exception('offline');
      await container.read(authControllerProvider.notifier).refreshSession();
      await tester.pumpAndSettle();

      expect(find.text('VIP video locked'), findsOneWidget);
      expect(find.text('Subscribe'), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
    },
  );

  testWidgets('unlocked VIP detail for member keeps playable preview',
      (WidgetTester tester) async {
    await pumpVideoDetail(
      tester,
      video: const HomeVideoItem(
        id: 'vip-unlocked-member',
        title: 'Unlocked Member Cut',
        subtitle: 'VIP Studio • 120 views',
        accessType: 'membership',
        canWatch: true,
        isLocked: false,
        videoUrl: 'https://example.com/vip.mp4',
      ),
    );

    expect(find.text('Playback preview'), findsOneWidget);
    expect(find.text('VIP video locked'), findsNothing);
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('Subscribe'), findsNothing);
  });

  testWidgets('playable public video keeps tappable playback header',
      (WidgetTester tester) async {
    await pumpVideoDetail(
      tester,
      isSignedIn: false,
      video: const HomeVideoItem(
        id: 'public-playable',
        title: 'Playable Public Clip',
        subtitle: 'Meow Studio • 12 views',
        videoUrl: 'https://example.com/public.mp4',
      ),
    );

    expect(find.text('Playback preview'), findsOneWidget);
    expect(find.text('VIP video locked'), findsNothing);
    await tester.tap(find.byType(AspectRatio).first);
    await tester.pump();
    expect(find.text('Playback preview'), findsOneWidget);
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.data) : error = null;

  _FakeApiClient.error(this.error) : data = null;

  final dynamic data;
  final Object? error;
  String? requestedPath;
  bool? requestedAuthenticated;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
  }) async {
    requestedPath = path;
    requestedAuthenticated = authenticated;
    final Object? requestError = error;
    if (requestError != null) throw requestError;
    return Response<T>(
      data: data as T,
      requestOptions: RequestOptions(path: path),
    );
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.isSignedIn});

  bool isSignedIn;
  Object? currentSessionError;

  @override
  Future<AuthSession> getCurrentSession() async {
    final Object? error = currentSessionError;
    if (error != null) throw error;
    return AuthSession(
      isSignedIn: isSignedIn,
      userId: isSignedIn ? 'user-1' : null,
      displayName: isSignedIn ? 'Meow User' : 'Guest',
    );
  }

  @override
  Future<AuthSession> login({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {
    isSignedIn = false;
  }

  @override
  Future<AuthSession> refreshSession() => getCurrentSession();

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    String? username,
    String? firstName,
    String? lastName,
  }) {
    throw UnimplementedError();
  }
}

class _NeverCompletingAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> getCurrentSession() => Completer<AuthSession>().future;

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
    String? username,
    String? firstName,
    String? lastName,
  }) {
    throw UnimplementedError();
  }
}
