import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/features/membership/domain/membership_order.dart';
import 'package:meow_media/features/membership/domain/membership_plan.dart';
import 'package:meow_media/features/membership/domain/membership_repository.dart';
import 'package:meow_media/features/membership/domain/membership_status.dart';
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
    MembershipPlan selectedPlan = basicPlan,
    MembershipRepository? repository,
    QrCodeSaver? qrCodeSaver,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MembershipPaymentPage(
            order: order,
            selectedPlan: selectedPlan,
            repository: repository ?? _PaymentMembershipRepository(),
            qrCodeSaver: qrCodeSaver,
          ),
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
    expect(find.text('Submit'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
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

  testWidgets('uses selected monthly plan duration', (WidgetTester tester) async {
    await pumpPaymentPage(
      tester,
      selectedPlan: const MembershipPlan(
        code: 'monthly',
        title: 'Monthly Membership',
        price: '30.00 THB-LTT / 30 days',
        perks: 'Monthly access',
        durationDays: 30,
        settlementTokenSymbol: 'THB-LTT',
      ),
    );

    expect(find.text('Monthly Membership'), findsOneWidget);
    expect(find.text('30.00'), findsOneWidget);
    expect(find.text('Duration: 30 days'), findsOneWidget);
  });

  testWidgets('uses selected quarterly plan duration',
      (WidgetTester tester) async {
    await pumpPaymentPage(
      tester,
      selectedPlan: const MembershipPlan(
        code: 'quarterly',
        title: 'Quarterly Membership',
        price: '80.00 THB-LTT / 90 days',
        perks: 'Quarterly access',
        durationDays: 90,
        settlementTokenSymbol: 'THB-LTT',
      ),
      order: const MembershipOrder(
        orderNo: 'order-quarterly',
        status: 'pending',
        planCode: 'monthly',
        planTitle: 'Wrong order plan',
        expectedAmountLbc: '999.00000000',
        payToAddress: 'quarterly-order-address',
      ),
    );

    expect(find.text('Quarterly Membership'), findsOneWidget);
    expect(find.text('80.00'), findsOneWidget);
    expect(find.text('Duration: 90 days'), findsOneWidget);
    expect(find.text('Duration: 30 days'), findsNothing);
    expect(find.text('Duration: 365 days'), findsNothing);
    expect(find.text('quarterly-order-address'), findsOneWidget);
  });

  testWidgets('uses selected yearly plan duration', (WidgetTester tester) async {
    await pumpPaymentPage(
      tester,
      selectedPlan: const MembershipPlan(
        code: 'yearly',
        title: 'Yearly Membership',
        price: '300.00 THB-LTT / 365 days',
        perks: 'Yearly access',
        durationDays: 365,
        settlementTokenSymbol: 'THB-LTT',
      ),
    );

    expect(find.text('Yearly Membership'), findsOneWidget);
    expect(find.text('300.00'), findsOneWidget);
    expect(find.text('Duration: 365 days'), findsOneWidget);
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
    final _PaymentMembershipRepository repository =
        _PaymentMembershipRepository();
    await pumpPaymentPage(tester, repository: repository);

    await tapPaymentAction(tester, 'Submit');

    expect(find.text('Please enter transaction hash.'), findsOneWidget);
    expect(repository.submittedOrderNo, isNull);
    expect(repository.submittedTxid, isNull);
  });

  testWidgets('non-empty transaction hash submits tx hint without activation',
      (WidgetTester tester) async {
    final _PaymentMembershipRepository repository =
        _PaymentMembershipRepository();
    await pumpPaymentPage(tester, repository: repository);

    await tester.enterText(
      find.byType(TextField),
      'b10608a77dd4bbe597a15803c3e96abc',
    );
    await tapPaymentAction(tester, 'Submit');

    expect(repository.submittedOrderNo, 'order-200');
    expect(repository.submittedTxid, 'b10608a77dd4bbe597a15803c3e96abc');
    expect(
      find.text('Transaction hash submitted. Awaiting confirmation.'),
      findsOneWidget,
    );
    expect(find.text('Member'), findsNothing);
  });

  testWidgets('transaction hash submit failure shows error',
      (WidgetTester tester) async {
    await pumpPaymentPage(
      tester,
      repository: _PaymentMembershipRepository(
        submitError: Exception('network failed'),
      ),
    );

    await tester.enterText(find.byType(TextField), 'tx-failure');
    await tapPaymentAction(tester, 'Submit');

    expect(
      find.text('Unable to submit transaction hash. Please try again.'),
      findsOneWidget,
    );
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

class _PaymentMembershipRepository implements MembershipRepository {
  _PaymentMembershipRepository({this.submitError});

  Object? submitError;
  String? submittedOrderNo;
  String? submittedTxid;

  @override
  Future<MembershipStatus?> getCurrentStatus() {
    throw UnimplementedError();
  }

  @override
  Future<List<MembershipPlan>> getPlans() {
    throw UnimplementedError();
  }

  @override
  Future<MembershipOrder> createOrder({required String planCode}) {
    throw UnimplementedError();
  }

  @override
  Future<MembershipOrder> getOrder(String orderNo) {
    throw UnimplementedError();
  }

  @override
  Future<MembershipOrder> submitTxHint({
    required String orderNo,
    required String txid,
  }) async {
    final Object? error = submitError;
    if (error != null) throw error;
    submittedOrderNo = orderNo;
    submittedTxid = txid;
    return MembershipOrder(
      orderNo: orderNo,
      status: 'pending',
      txid: txid,
    );
  }

  @override
  Future<MembershipOrder> verifyNow(String orderNo) {
    throw UnimplementedError();
  }
}
