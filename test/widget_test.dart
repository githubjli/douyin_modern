import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/app/app.dart';

void main() {
  testWidgets('app shell renders updated bottom tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MeowMediaApp(
      enableFeedVideo: false,
      enableRemoteFeed: false,
    ));

    final Finder bottomNav = find.byType(BottomNavigationBar);
    expect(bottomNav, findsOneWidget);

    expect(find.descendant(of: bottomNav, matching: find.text('Home')),
        findsOneWidget);
    expect(find.descendant(of: bottomNav, matching: find.text('Shorts')),
        findsOneWidget);
    expect(find.descendant(of: bottomNav, matching: find.text('Membership')),
        findsOneWidget);
    expect(find.descendant(of: bottomNav, matching: find.text('Profile')),
        findsOneWidget);
  });
}
