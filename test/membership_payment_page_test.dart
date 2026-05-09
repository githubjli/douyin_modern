import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/features/membership/domain/membership_order.dart';
import 'package:meow_media/features/membership/membership_payment_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  const MembershipOrder payableOrder = MembershipOrder(
    orderNo: 'order-qr',
    status: 'pending',
    planCode: 'monthly',
    planTitle: 'Monthly',
    expectedAmountLbc: '30.00000000',
    currency: 'THB-LTT',
    payToAddress: 'ltt-pay-address',
    expiresAt: '2026-06-01T00:00:00Z',
  );

  final List<MethodCall> platformCalls = <MethodCall>[];

  setUp(() {
    platformCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        platformCalls.add(call);
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpPaymentPage(
    WidgetTester tester, {
    MembershipOrder order = payableOrder,
    Future<void> Function()? saveQrOverride,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MembershipPaymentPage(
            order: order,
            saveQrOverride: saveQrOverride,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAction(WidgetTester tester, String label) async {
    final Finder action = find.text(label).first;
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action.hitTestable().first);
    await tester.pumpAndSettle();
  }

  testWidgets('shows QR area when payment address is available',
      (WidgetTester tester) async {
    await pumpPaymentPage(tester);

    expect(find.text('Complete payment'), findsOneWidget);
    expect(find.byKey(MembershipPaymentPage.qrSectionKey), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Scan or copy the address to pay'), findsOneWidget);
    expect(find.text('ltt-pay-address'), findsOneWidget);
    expect(find.text('Save QR'), findsOneWidget);
  });

  testWidgets('uses payment uri before qr payload and address for QR data',
      (WidgetTester tester) async {
    await pumpPaymentPage(
      tester,
      order: const MembershipOrder(
        orderNo: 'order-uri',
        status: 'pending',
        expectedAmountLbc: '30.00000000',
        payToAddress: 'address-data',
        qrPayload: 'qr-payload-data',
        paymentUri: 'payment-uri-data',
      ),
    );

    final QrImageView qr = tester.widget<QrImageView>(
      find.byType(QrImageView),
    );

    expect(qr.data, 'payment-uri-data');
  });

  testWidgets('hides QR when payment address is unavailable',
      (WidgetTester tester) async {
    await pumpPaymentPage(
      tester,
      order: const MembershipOrder(
        orderNo: 'order-empty',
        status: 'pending',
        expectedAmountLbc: '30.00000000',
      ),
    );

    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Payment address unavailable'), findsWidgets);
    expect(find.text('Save QR'), findsOneWidget);
  });

  testWidgets('copy address shows confirmation', (WidgetTester tester) async {
    await pumpPaymentPage(tester);

    await tapAction(tester, 'Copy address');

    expect(find.text('Address copied'), findsOneWidget);
    expect(platformCalls.last.method, 'Clipboard.setData');
    expect(
      platformCalls.last.arguments,
      <String, dynamic>{'text': 'ltt-pay-address'},
    );
  });

  testWidgets('copy amount shows confirmation and copies raw amount',
      (WidgetTester tester) async {
    await pumpPaymentPage(tester);

    await tapAction(tester, 'Copy amount');

    expect(find.text('Amount copied'), findsOneWidget);
    expect(platformCalls.last.method, 'Clipboard.setData');
    expect(
      platformCalls.last.arguments,
      <String, dynamic>{'text': '30.00000000'},
    );
  });

  testWidgets('save QR success shows confirmation', (WidgetTester tester) async {
    bool saved = false;
    await pumpPaymentPage(
      tester,
      saveQrOverride: () async {
        saved = true;
      },
    );

    await tapAction(tester, 'Save QR');

    expect(saved, isTrue);
    expect(find.text('QR saved'), findsOneWidget);
  });

  testWidgets('save QR failure shows error', (WidgetTester tester) async {
    await pumpPaymentPage(
      tester,
      saveQrOverride: () async {
        throw Exception('disk full');
      },
    );

    await tapAction(tester, 'Save QR');

    expect(
      find.text('Unable to save QR. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('QR repaint boundary includes white quiet zone padding',
      (WidgetTester tester) async {
    await pumpPaymentPage(tester);

    final Finder boundaryContainer = find.byKey(
      MembershipPaymentPage.qrBoundaryKey,
    );
    final Container container = tester.widget<Container>(boundaryContainer);

    expect(
      find.ancestor(
        of: boundaryContainer,
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
    expect(container.color, Colors.white);
    expect(container.padding, const EdgeInsets.all(24));
  });
}
