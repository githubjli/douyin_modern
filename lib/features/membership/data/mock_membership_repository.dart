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
  Future<MembershipOrder> createOrder({required String planCode}) {
    throw UnimplementedError('Mock membership orders are not available.');
  }

  @override
  Future<MembershipOrder> getOrder(String orderNo) {
    throw UnimplementedError('Mock membership orders are not available.');
  }

  @override
  Future<MembershipOrder> submitTxHint({
    required String orderNo,
    required String txid,
  }) {
    throw UnimplementedError('Mock membership orders are not available.');
  }

  @override
  Future<MembershipOrder> verifyNow(String orderNo) {
    throw UnimplementedError('Mock membership orders are not available.');
  }
}
