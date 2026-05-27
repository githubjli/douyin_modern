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
    this.supportedPaymentAssets,
    this.basePriceAmount,
    this.basePriceAsset,
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
  /// Payment asset codes supported by this plan, e.g. ['thb_ltt', 'meow_points', 'meow_credit'].
  final List<String>? supportedPaymentAssets;
  final String? basePriceAmount;
  final String? basePriceAsset;
}
