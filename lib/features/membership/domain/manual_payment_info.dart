enum PurchaseMode {
  newSubscription,
  renewal,
  planChange,
  unknown;

  static PurchaseMode fromString(String? raw) => switch (raw?.toLowerCase().trim()) {
        'new' => PurchaseMode.newSubscription,
        'renewal' => PurchaseMode.renewal,
        'plan_change' => PurchaseMode.planChange,
        _ => PurchaseMode.unknown,
      };
}

class ManualCurrentMembership {
  const ManualCurrentMembership({
    required this.planCode,
    required this.planName,
    this.startsAt,
    this.endsAt,
  });

  factory ManualCurrentMembership.fromJson(Map<String, dynamic> json) {
    return ManualCurrentMembership(
      planCode: _str(json['plan_code']) ?? '',
      planName: _str(json['plan_name']) ?? _str(json['plan_title']) ?? '',
      startsAt: _str(json['starts_at']),
      endsAt: _str(json['ends_at']),
    );
  }

  final String planCode;
  final String planName;
  final String? startsAt;
  final String? endsAt;
}

/// Payment information returned by GET /api/membership/manual/payment-info/
/// This endpoint does NOT create an order; it provides the address, amount,
/// and context (new / renewal / plan_change) for the user's purchase.
class ManualPaymentInfo {
  const ManualPaymentInfo({
    required this.planCode,
    required this.planName,
    required this.expectedAmountLbc,
    required this.currency,
    required this.payToAddress,
    required this.requiredConfirmations,
    this.notice,
    this.purchaseMode = PurchaseMode.unknown,
    this.isRenewal = false,
    this.isPlanChange = false,
    this.hasActiveMembership = false,
    this.currentMembership,
    this.estimatedNewStartsAt,
    this.estimatedNewEndsAt,
  });

  factory ManualPaymentInfo.fromJson(Map<String, dynamic> json) {
    final String? planCode = _str(json['plan_code']);
    final String? payToAddress =
        _str(json['pay_to_address']) ?? _str(json['address']);
    if (planCode == null || payToAddress == null) {
      throw const FormatException('Invalid manual payment info response');
    }

    final dynamic currentJson = json['current_membership'];
    final ManualCurrentMembership? currentMembership =
        currentJson is Map<String, dynamic>
            ? ManualCurrentMembership.fromJson(currentJson)
            : null;

    return ManualPaymentInfo(
      planCode: planCode,
      planName: _str(json['plan_name']) ?? _str(json['plan_title']) ?? planCode,
      expectedAmountLbc: _str(json['expected_amount_lbc']) ??
          _str(json['amount']) ??
          'Amount unavailable',
      currency: _str(json['currency']) ??
          _str(json['token_symbol']) ??
          _nestedStr(json['settlement'], 'token_symbol') ??
          'LBC',
      payToAddress: payToAddress,
      requiredConfirmations: _int(json['required_confirmations']) ?? 0,
      notice: _str(json['notice']),
      purchaseMode: PurchaseMode.fromString(_str(json['purchase_mode'])),
      isRenewal: json['is_renewal'] == true,
      isPlanChange: json['is_plan_change'] == true,
      hasActiveMembership: json['has_active_membership'] == true,
      currentMembership: currentMembership,
      estimatedNewStartsAt: _str(json['estimated_new_starts_at']),
      estimatedNewEndsAt: _str(json['estimated_new_ends_at']),
    );
  }

  final String planCode;
  final String planName;
  final String expectedAmountLbc;
  final String currency;
  final String payToAddress;
  final int requiredConfirmations;
  final String? notice;
  final PurchaseMode purchaseMode;
  final bool isRenewal;
  final bool isPlanChange;
  final bool hasActiveMembership;
  final ManualCurrentMembership? currentMembership;
  final String? estimatedNewStartsAt;
  final String? estimatedNewEndsAt;
}

String? _str(dynamic v) {
  if (v is String && v.trim().isNotEmpty) return v.trim();
  if (v is num) return v.toString();
  return null;
}

String? _nestedStr(dynamic map, String key) {
  if (map is Map<String, dynamic>) return _str(map[key]);
  return null;
}

int? _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}
