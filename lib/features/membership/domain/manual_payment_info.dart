/// Payment information returned by GET /api/membership/manual/payment-info/
/// This endpoint does NOT create an order; it only provides the address and
/// expected amount so the user can initiate an on-chain transfer manually.
class ManualPaymentInfo {
  const ManualPaymentInfo({
    required this.planCode,
    required this.planName,
    required this.expectedAmountLbc,
    required this.currency,
    required this.payToAddress,
    required this.requiredConfirmations,
    this.notice,
  });

  factory ManualPaymentInfo.fromJson(Map<String, dynamic> json) {
    final String? planCode = _str(json['plan_code']);
    final String? payToAddress =
        _str(json['pay_to_address']) ?? _str(json['address']);
    if (planCode == null || payToAddress == null) {
      throw const FormatException('Invalid manual payment info response');
    }
    return ManualPaymentInfo(
      planCode: planCode,
      planName: _str(json['plan_name']) ?? _str(json['plan_title']) ?? planCode,
      expectedAmountLbc: _str(json['expected_amount_lbc']) ??
          _str(json['amount']) ??
          'Amount unavailable',
      currency: _str(json['currency']) ?? 'LBC',
      payToAddress: payToAddress,
      requiredConfirmations: _int(json['required_confirmations']) ?? 0,
      notice: _str(json['notice']),
    );
  }

  final String planCode;
  final String planName;
  final String expectedAmountLbc;
  final String currency;
  final String payToAddress;
  final int requiredConfirmations;
  final String? notice;
}

String? _str(dynamic v) {
  if (v is String && v.trim().isNotEmpty) return v.trim();
  if (v is num) return v.toString();
  return null;
}

int? _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}
