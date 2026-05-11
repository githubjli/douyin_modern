class MeowPointWallet {
  const MeowPointWallet({
    required this.balance,
    required this.totalEarned,
    required this.totalSpent,
    required this.totalPurchased,
    required this.totalBonus,
    this.updatedAt,
  });

  final int balance;
  final int totalEarned;
  final int totalSpent;
  final int totalPurchased;
  final int totalBonus;
  final String? updatedAt;

  factory MeowPointWallet.fromJson(Map<String, dynamic> json) {
    return MeowPointWallet(
      balance: _int(json['balance']) ?? 0,
      totalEarned: _int(json['total_earned']) ?? 0,
      totalSpent: _int(json['total_spent']) ?? 0,
      totalPurchased: _int(json['total_purchased']) ?? 0,
      totalBonus: _int(json['total_bonus']) ?? 0,
      updatedAt: json['updated_at'] is String ? json['updated_at'] as String : null,
    );
  }
}

int? _int(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v);
  return null;
}
