import 'membership_models.dart';

abstract class MembershipRepository {
  Future<List<MembershipPlan>> getPlans();
}

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
}
