import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/core/network/api_client.dart';
import 'package:meow_media/core/network/api_error.dart';
import 'package:meow_media/core/network/endpoints.dart';
import 'package:meow_media/features/home/domain/home_models.dart';
import 'package:meow_media/features/video_detail/video_detail_page.dart';
import 'package:video_player/video_player.dart';

void main() {
  Future<void> pumpVideoDetail(
    WidgetTester tester, {
    required HomeVideoItem video,
    required bool isSignedIn,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VideoDetailPage(
          video: video,
          loadRemoteDetail: false,
          signedInFuture: Future<bool>.value(isSignedIn),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

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

    await tester.pumpWidget(
      MaterialApp(
        home: VideoDetailPage(
          video: const HomeVideoItem(
            id: '42',
            title: 'Local VIP',
            subtitle: 'VIP Studio • 120 views',
            accessType: 'membership',
            canWatch: false,
            isLocked: true,
          ),
          apiClient: apiClient,
          signedInFuture: Future<bool>.value(true),
        ),
      ),
    );
    await tester.pumpAndSettle();

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

      await tester.pumpWidget(
        MaterialApp(
          home: VideoDetailPage(
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
            signedInFuture: Future<bool>.value(true),
          ),
        ),
      );
      await tester.pumpAndSettle();

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

      await tester.pumpWidget(
        MaterialApp(
          home: VideoDetailPage(
            key: detailKey,
            video: lockedListVideo,
            apiClient: successClient,
            signedInFuture: Future<bool>.value(true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Playback preview'), findsOneWidget);
      expect(find.text('VIP video locked'), findsNothing);

      final _FakeApiClient failureClient = _FakeApiClient.error(
        const ApiError(message: 'Server error', statusCode: 500),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: VideoDetailPage(
            key: detailKey,
            video: lockedListVideo,
            apiClient: failureClient,
            signedInFuture: Future<bool>.value(true),
          ),
        ),
      );
      await tester.pumpAndSettle();

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

      await tester.pumpWidget(
        MaterialApp(
          home: VideoDetailPage(
            key: detailKey,
            video: lockedListVideo,
            apiClient: unlockClient,
            signedInFuture: Future<bool>.value(true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Playback preview'), findsOneWidget);
      expect(find.text('VIP video locked'), findsNothing);

      final _FakeApiClient partialClient = _FakeApiClient(<String, dynamic>{
        'id': 103,
        'title': 'Partial Remote VIP',
        'access_type': 'membership',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: VideoDetailPage(
            key: detailKey,
            video: lockedListVideo,
            apiClient: partialClient,
            signedInFuture: Future<bool>.value(true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(partialClient.requestedAuthenticated, isTrue);
      expect(find.text('Playback preview'), findsOneWidget);
      expect(find.text('VIP video locked'), findsNothing);
      expect(find.text('Subscribe'), findsNothing);
      expect(find.text('Sign in'), findsNothing);
    },
  );

  testWidgets(
    'explicit locked remote detail response keeps VIP locked',
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

      await tester.pumpWidget(
        MaterialApp(
          home: VideoDetailPage(
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
            signedInFuture: Future<bool>.value(true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('VIP video locked'), findsOneWidget);
      expect(find.text('Subscribe'), findsOneWidget);
      expect(find.text('Playback preview'), findsNothing);
      expect(find.byType(VideoPlayer), findsNothing);
    },
  );

  for (final int statusCode in <int>[401, 403]) {
    testWidgets(
      'auth denied $statusCode remote detail locks VIP with Sign in CTA',
      (WidgetTester tester) async {
        final _FakeApiClient apiClient = _FakeApiClient.error(
          ApiError(message: 'Auth denied', statusCode: statusCode),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: VideoDetailPage(
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
              signedInFuture: Future<bool>.value(true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('VIP video locked'), findsOneWidget);
        expect(find.text('Sign in'), findsOneWidget);
        expect(find.text('Subscribe'), findsNothing);
        expect(find.text('Playback preview'), findsNothing);
        expect(find.byType(VideoPlayer), findsNothing);
      },
    );
  }

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
      isSignedIn: true,
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

  testWidgets('unlocked VIP detail for member keeps playable preview',
      (WidgetTester tester) async {
    await pumpVideoDetail(
      tester,
      isSignedIn: true,
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
