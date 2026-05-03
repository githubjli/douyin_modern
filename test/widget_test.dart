import 'package:meow_media/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shell renders bottom tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const DouyinModernApp(enableFeedVideo: false));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Publish'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
