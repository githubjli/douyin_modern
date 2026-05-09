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
    expectedAmountLbc: '30.00000000',
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
    return find.byKey(
      const ValueKey<String>('membership-payment-qr-boundary'),
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
    expect(find.text('30.00'), findsOneWidget);
    expect(find.text('30.00000000'), findsNothing);
    expect(find.text('THB-LTT'), findsWidgets);
    expect(find.text('Duration: 30 days'), findsOneWidget);
    expect(find.text('Complete the Payment'), findsOneWidget);
    expect(qrBoundaryFinder(), findsOneWidget);
    expect(find.text('Receiving Address'), findsOneWidget);
    expect(
      find.text('thb-ltt-address-200-long-payment-address'),
      findsOneWidget,
    );
    expect(find.byTooltip('Copy address'), findsOneWidget);
    expect(find.text('Copy amount'), findsNothing);
    expect(find.text('Download QR Code'), findsOneWidget);
    expect(
      find.text(
        'Please transfer funds using THB-LTT only. '
        'Other currencies may be lost.',
      ),
      findsOneWidget,
    );
    expect(find.text('Transaction Hash (Confirmation)'), findsOneWidget);
    expect(
      find.text('Eg, b10608a77dd4bbe597a15803c3e96...'),
      findsOneWidget,
    );
    expect(find.text('Submit Transaction Hash'), findsOneWidget);
    expect(find.text('Basic Monthly (basic-monthly)'), findsNothing);
    expect(find.text('Order: order-200'), findsNothing);
    expect(find.text('Status: pending'), findsNothing);
    expect(find.text('Expires: 2026-06-01T00:00:00Z'), findsNothing);
    expect(find.text('Purchase Membership'), findsNothing);
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

  testWidgets('empty transaction hash shows validation message',
      (WidgetTester tester) async {
    await pumpPaymentPage(tester);

    await tapPaymentAction(tester, 'Submit Transaction Hash');

    expect(find.text('Please enter transaction hash.'), findsOneWidget);
  });

  testWidgets('non-empty transaction hash saves locally without activation',
      (WidgetTester tester) async {
    await pumpPaymentPage(tester);

    await tester.enterText(
      find.byType(TextField),
      'b10608a77dd4bbe597a15803c3e96abc',
    );
    await tapPaymentAction(tester, 'Submit Transaction Hash');

    expect(find.text('Transaction hash saved locally'), findsOneWidget);
    expect(find.text('Member'), findsNothing);
  });

  testWidgets('copies address with confirmation', (WidgetTester tester) async {
    await pumpPaymentPage(tester);

    final Finder copyAddress = find.byTooltip('Copy address');
    await tester.ensureVisible(copyAddress);
    await tester.pumpAndSettle();
    await tester.tap(copyAddress);
    await tester.pumpAndSettle();

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
