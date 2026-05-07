import 'membership_plan.dart';
import 'membership_status.dart';

abstract class MembershipRepository {
  Future<List<MembershipPlan>> getPlans();

  Future<MembershipStatus?> getCurrentStatus();
}
