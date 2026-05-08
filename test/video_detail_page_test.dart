import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/features/home/domain/home_models.dart';
import 'package:meow_media/features/video_detail/video_detail_page.dart';

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
}
