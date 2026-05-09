class MembershipPlan {
  const MembershipPlan({
    required this.title,
    required this.price,
    required this.perks,
    this.id,
    this.code,
    this.durationDays,
    this.settlementBlockchain,
    this.settlementTokenName,
    this.settlementTokenSymbol,
    this.settlementTokenPeg,
  });

  final String title;
  final String price;
  final String perks;
  final String? id;
  final String? code;
  final int? durationDays;
  final String? settlementBlockchain;
  final String? settlementTokenName;
  final String? settlementTokenSymbol;
  final String? settlementTokenPeg;
}
