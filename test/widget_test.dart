import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/app/app.dart';

void main() {
  testWidgets('app shell renders polished bottom navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MeowMediaApp(
      enableFeedVideo: false,
      enableRemoteFeed: false,
      enableRemoteHome: false,
    ));

    final Finder bottomNav = find.byType(BottomNavigationBar);
    expect(bottomNav, findsOneWidget);

    expect(find.descendant(of: bottomNav, matching: find.text('Home')),
        findsOneWidget);
    expect(find.descendant(of: bottomNav, matching: find.text('Short')),
        findsOneWidget);
    expect(find.descendant(of: bottomNav, matching: find.text('Member')),
        findsOneWidget);
    expect(find.descendant(of: bottomNav, matching: find.text('Profile')),
        findsOneWidget);

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
  });
}
