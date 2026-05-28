class MeowPointWallet {
  const MeowPointWallet({
    required this.balance,
    required this.totalEarned,
    required this.totalSpent,
    required this.totalPurchased,
    required this.totalBonus,
    this.balanceDisplay,
    this.updatedAt,
  });

  final double balance;
  final double totalEarned;
  final double totalSpent;
  final double totalPurchased;
  final double totalBonus;
  /// Pre-formatted balance string from the backend (e.g. "300.50").
  final String? balanceDisplay;
  final String? updatedAt;

  /// Formatted balance for display: shows decimals only when non-zero.
  String get displayBalance =>
      balanceDisplay ?? _formatDecimal(balance);

  factory MeowPointWallet.fromJson(Map<String, dynamic> json) {
    return MeowPointWallet(
      balance: _double(json['balance']) ?? 0,
      totalEarned: _double(json['total_earned']) ?? 0,
      totalSpent: _double(json['total_spent']) ?? 0,
      totalPurchased: _double(json['total_purchased']) ?? 0,
      totalBonus: _double(json['total_bonus']) ?? 0,
      balanceDisplay: json['balance_display'] as String?,
      updatedAt: json['updated_at'] is String ? json['updated_at'] as String : null,
    );
  }
}

double? _double(dynamic v) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

String _formatDecimal(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
