class MembershipPlan {
  const MembershipPlan({
    required this.title,
    required this.price,
    required this.perks,
    this.id,
    this.code,
  });

  final String title;
  final String price;
  final String perks;
  final String? id;
  final String? code;
}
