import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/app/app.dart';

void main() {
  testWidgets('app shell renders bottom tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const DouyinModernApp(enableFeedVideo: false));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Shorts'), findsOneWidget);
    expect(find.text('+'), findsOneWidget);
    expect(find.text('Membership'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
