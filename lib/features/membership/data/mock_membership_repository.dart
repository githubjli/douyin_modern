import '../domain/membership_order.dart';
import '../domain/membership_plan.dart';
import '../domain/membership_repository.dart';
import '../domain/membership_status.dart';

class MockMembershipRepository implements MembershipRepository {
  const MockMembershipRepository();

  @override
  Future<List<MembershipPlan>> getPlans() async {
    return const <MembershipPlan>[
      MembershipPlan(
        title: 'Monthly',
        price: '¥5 / month',
        perks: 'Creator boosts, profile badge',
      ),
      MembershipPlan(
        title: 'Yearly',
        price: '¥50 / year',
        perks: 'Best value + seasonal gifts',
      ),
    ];
  }

  @override
  Future<MembershipStatus?> getCurrentStatus() async => null;

  @override
  Future<MembershipOrder> createOrder({required String planCode}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return MembershipOrder(
      orderNo: 'mock-order-${DateTime.now().millisecondsSinceEpoch}',
      status: 'pending',
      planCode: planCode,
      planTitle: _planTitle(planCode),
      expectedAmountLbc: _planAmount(planCode),
      currency: 'THB',
      tokenSymbol: 'THB-LTT',
      payToAddress: 'mock-thb-ltt-address-0x1234567890abcdef',
      qrPayload: 'mock-thb-ltt-address-0x1234567890abcdef',
      expiresAt: DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
    );
  }

  @override
  Future<MembershipOrder> getOrder(String orderNo) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return MembershipOrder(
      orderNo: orderNo,
      status: 'pending',
      payToAddress: 'mock-thb-ltt-address-0x1234567890abcdef',
    );
  }

  @override
  Future<MembershipOrder> submitTxHint({
    required String orderNo,
    required String txid,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return MembershipOrder(
      orderNo: orderNo,
      status: 'pending',
      txid: txid,
      payToAddress: 'mock-thb-ltt-address-0x1234567890abcdef',
    );
  }

  @override
  Future<MembershipOrder> verifyNow(String orderNo) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return MembershipOrder(
      orderNo: orderNo,
      status: 'pending',
      payToAddress: 'mock-thb-ltt-address-0x1234567890abcdef',
    );
  }

  static String _planTitle(String planCode) {
    return switch (planCode) {
      'monthly' => 'Monthly',
      'quarterly' => 'Quarterly',
      'yearly' => 'Yearly',
      _ => 'Membership',
    };
  }

  static String _planAmount(String planCode) {
    return switch (planCode) {
      'monthly' => '99.00',
      'quarterly' => '259.00',
      'yearly' => '899.00',
      _ => '99.00',
    };
  }
}
