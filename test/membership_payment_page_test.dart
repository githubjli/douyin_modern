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

  Future<void> pumpPaymentPage(
    WidgetTester tester, {
    MembershipOrder order = const MembershipOrder(
      orderNo: 'order-200',
      status: 'pending',
      planCode: 'monthly',
      planTitle: 'Monthly',
      expectedAmountLbc: '12.5',
      currency: 'LBC',
      payToAddress: 'lbc-address-200-long-payment-address',
      expiresAt: '2026-06-01T00:00:00Z',
    ),
    MembershipPlan? plan,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MembershipPaymentPage(
          order: order,
          plan: plan,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapPaymentAction(WidgetTester tester, String label) async {
    final Finder action = find.text(label).first;
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action.hitTestable().first);
    await tester.pumpAndSettle();
  }

  testWidgets('shows payment order details without future payment controls',
      (WidgetTester tester) async {
    await pumpPaymentPage(tester);

    expect(find.text('Complete payment'), findsWidgets);
    expect(find.text('Monthly (monthly)'), findsWidgets);
    expect(find.text('order-200'), findsOneWidget);
    expect(find.text('pending'), findsOneWidget);
    expect(find.text('12.5 LBC'), findsOneWidget);
    expect(find.text('LBC'), findsOneWidget);
    expect(find.text('lbc-address-200-long-payment-address'), findsOneWidget);
    expect(find.text('2026-06-01T00:00:00Z'), findsOneWidget);
    expect(find.text('Copy amount'), findsOneWidget);
    expect(find.text('Copy address'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('QR'), findsNothing);
    expect(find.text('Txid'), findsNothing);
    expect(find.text('TXID'), findsNothing);
    expect(find.text('Verify now'), findsNothing);
    expect(find.text('Polling'), findsNothing);
  });

  testWidgets('copies amount and address with confirmations',
      (WidgetTester tester) async {
    await pumpPaymentPage(tester);

    await tapPaymentAction(tester, 'Copy amount');
    expect(find.text('Amount copied'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tapPaymentAction(tester, 'Copy address');
    expect(find.text('Address copied'), findsOneWidget);
  });

  testWidgets('falls back to plan token symbol for currency',
      (WidgetTester tester) async {
    await pumpPaymentPage(
      tester,
      order: const MembershipOrder(
        orderNo: 'order-token',
        status: 'pending',
        planCode: 'gold',
        expectedAmountLbc: '9.75',
        payToAddress: 'token-address',
        expiresAt: '2026-07-01T00:00:00Z',
      ),
      plan: const MembershipPlan(
        code: 'gold',
        title: 'Gold Monthly',
        price: 'USD 19.99 / month',
        perks: 'Gold perks',
        settlementTokenSymbol: 'MEOW',
      ),
    );

    expect(find.text('Gold Monthly (gold)'), findsWidgets);
    expect(find.text('9.75 MEOW'), findsOneWidget);
    expect(find.text('MEOW'), findsOneWidget);
  });
}
