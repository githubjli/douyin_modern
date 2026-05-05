import 'membership_plan.dart';

abstract class MembershipRepository {
  Future<List<MembershipPlan>> getPlans();
}
