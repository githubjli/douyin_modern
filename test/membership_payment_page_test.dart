import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/features/membership/domain/membership_order.dart';
import 'package:meow_media/features/membership/domain/membership_plan.dart';
import 'package:meow_media/features/membership/membership_payment_page.dart';

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  const MembershipPlan basicPlan = MembershipPlan(
    code: 'basic-monthly',
    title: 'Basic Monthly',
    price: 'THB 30 / month',
    perks: 'Basic perks',
    durationDays: 30,
    settlementTokenSymbol: 'THB-LTT',
  );

  const MembershipOrder basicOrder = MembershipOrder(
    orderNo: 'order-200',
    status: 'pending',
    planCode: 'basic-monthly',
    planTitle: 'Basic Monthly',
    expectedAmountLbc: '30',
    payToAddress: 'thb-ltt-address-200-long-payment-address',
    expiresAt: '2026-06-01T00:00:00Z',
  );

  Future<void> pumpPaymentPage(
    WidgetTester tester, {
    MembershipOrder order = basicOrder,
    MembershipPlan? plan = basicPlan,
    QrCodeSaver? qrCodeSaver,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MembershipPaymentPage(
          order: order,
          plan: plan,
          qrCodeSaver: qrCodeSaver,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder qrBoundaryFinder() {
    return find.byWidgetPredicate(
      (Widget widget) => widget is RepaintBoundary && widget.key != null,
    );
  }

  Future<void> tapPaymentAction(WidgetTester tester, String label) async {
    final Finder action = find.text(label).first;
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action.hitTestable().first);
    await tester.pumpAndSettle();
  }

  testWidgets('shows purchase layout with QR and token fallback',
      (WidgetTester tester) async {
    await pumpPaymentPage(tester);

    expect(find.text('Membership Purchase'), findsOneWidget);
    expect(find.text('Selected Plan'), findsOneWidget);
    expect(find.text('Basic Monthly'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('THB-LTT'), findsWidgets);
    expect(find.text('Duration: 30 days'), findsOneWidget);
    expect(find.text('Complete the Payment'), findsOneWidget);
    expect(qrBoundaryFinder(), findsOneWidget);
    expect(find.text('Receiving Address'), findsOneWidget);
    expect(
      find.text('thb-ltt-address-200-long-payment-address'),
      findsOneWidget,
    );
    expect(find.text('Copy address'), findsOneWidget);
    expect(find.text('Download QR Code'), findsOneWidget);
    expect(
      find.text('Please transfer funds using THB-LTT only.'),
      findsOneWidget,
    );
    expect(find.text('Transaction Hash'), findsNothing);
    expect(find.text('Txid'), findsNothing);
    expect(find.text('TXID'), findsNothing);
    expect(find.text('Verify now'), findsNothing);
    expect(find.text('Polling'), findsNothing);
    expect(find.text('LBC'), findsNothing);
  });

  testWidgets('shows unavailable state when payment address is missing',
      (WidgetTester tester) async {
    await pumpPaymentPage(
      tester,
      order: const MembershipOrder(
        orderNo: 'order-missing-address',
        status: 'pending',
        planTitle: 'Basic Monthly',
        expectedAmountLbc: '30',
      ),
    );

    expect(find.text('Payment address unavailable'), findsWidgets);
    expect(qrBoundaryFinder(), findsNothing);
    expect(find.text('Download QR Code'), findsOneWidget);
  });

  testWidgets('copies address with confirmation', (WidgetTester tester) async {
    await pumpPaymentPage(tester);

    await tapPaymentAction(tester, 'Copy address');

    expect(find.text('Address copied'), findsOneWidget);
  });

  testWidgets('saves QR code with confirmation', (WidgetTester tester) async {
    bool saveCalled = false;
    await pumpPaymentPage(
      tester,
      qrCodeSaver: (GlobalKey qrKey) async {
        saveCalled = qrKey.currentContext != null;
        return true;
      },
    );

    await tapPaymentAction(tester, 'Download QR Code');

    expect(saveCalled, isTrue);
    expect(find.text('QR saved'), findsOneWidget);
  });

  testWidgets('uses order qr payload before payment address',
      (WidgetTester tester) async {
    GlobalKey? savedKey;
    await pumpPaymentPage(
      tester,
      order: const MembershipOrder(
        orderNo: 'order-payload',
        status: 'pending',
        planTitle: 'Basic Monthly',
        expectedAmountLbc: '30',
        qrPayload: 'qr-payload-value',
        payToAddress: 'address-fallback-value',
      ),
      qrCodeSaver: (GlobalKey qrKey) async {
        savedKey = qrKey;
        return true;
      },
    );

    expect(qrBoundaryFinder(), findsOneWidget);
    await tapPaymentAction(tester, 'Download QR Code');
    expect(savedKey, isNotNull);
  });
}
