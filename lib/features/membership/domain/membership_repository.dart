import 'membership_order.dart';
import 'membership_plan.dart';
import 'membership_status.dart';

abstract class MembershipRepository {
  Future<List<MembershipPlan>> getPlans();

  Future<MembershipStatus?> getCurrentStatus();

  Future<MembershipOrder> createOrder({required String planCode});

  Future<MembershipOrder> getOrder(String orderNo);

  Future<MembershipOrder> submitTxHint({
    required String orderNo,
    required String txid,
  });

  Future<MembershipOrder> verifyNow(String orderNo);
}
