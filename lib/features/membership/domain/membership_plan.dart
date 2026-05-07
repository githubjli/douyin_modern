class MembershipPlan {
  const MembershipPlan({
    required this.title,
    required this.price,
    required this.perks,
    this.id,
  });

  final String title;
  final String price;
  final String perks;
  final String? id;
}
