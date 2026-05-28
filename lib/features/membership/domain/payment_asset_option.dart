/// Per-asset pricing option returned by the plan API
/// under `payment_asset_options[]`.
class PaymentAssetOption {
  const PaymentAssetOption({
    required this.assetCode,
    this.displayName,
    this.exchangeRate,
    this.estimatedPaymentAmount,
  });

  factory PaymentAssetOption.fromJson(Map<String, dynamic> json) {
    return PaymentAssetOption(
      assetCode: (json['asset_code'] as String? ?? '').trim(),
      displayName: _str(json['display_name']),
      exchangeRate: _str(json['exchange_rate']),
      estimatedPaymentAmount: _str(json['estimated_payment_amount']),
    );
  }

  /// Raw asset code, e.g. 'meow_points', 'meow_credit', 'thb_ltt'.
  final String assetCode;

  /// Human-readable label from the backend, e.g. 'MeowPoints'.
  final String? displayName;

  /// Exchange rate relative to the base price asset.
  final String? exchangeRate;

  /// Estimated amount the user will pay in this asset.
  final String? estimatedPaymentAmount;

  static String? _str(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toString();
    return null;
  }
}
