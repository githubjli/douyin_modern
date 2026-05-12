class MeowCreditWallet {
  const MeowCreditWallet({
    required this.balance,
    required this.totalRecharged,
    required this.totalSpent,
    required this.totalRedeemed,
    required this.totalAdjusted,
    this.createdAt,
    this.updatedAt,
  });

  final int balance;
  final int totalRecharged;
  final int totalSpent;
  final int totalRedeemed;
  final int totalAdjusted;
  final String? createdAt;
  final String? updatedAt;

  factory MeowCreditWallet.fromJson(Map<String, dynamic> json) {
    return MeowCreditWallet(
      balance: _int(json['balance']) ?? 0,
      totalRecharged: _int(json['total_recharged']) ?? 0,
      totalSpent: _int(json['total_spent']) ?? 0,
      totalRedeemed: _int(json['total_redeemed']) ?? 0,
      totalAdjusted: _int(json['total_adjusted']) ?? 0,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

class MeowCreditPackage {
  const MeowCreditPackage({
    required this.code,
    required this.name,
    required this.creditAmount,
    required this.bonusCredit,
    required this.totalCredit,
    required this.priceAmount,
    required this.priceCurrency,
    this.description,
  });

  final String code;
  final String name;
  final int creditAmount;
  final int bonusCredit;
  final int totalCredit;
  final String priceAmount;
  final String priceCurrency;
  final String? description;

  factory MeowCreditPackage.fromJson(Map<String, dynamic> json) {
    return MeowCreditPackage(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      creditAmount: _int(json['credit_amount']) ?? 0,
      bonusCredit: _int(json['bonus_credit']) ?? 0,
      totalCredit: _int(json['total_credit']) ?? 0,
      priceAmount: json['price_amount'] as String? ?? '0',
      priceCurrency: json['price_currency'] as String? ??
          json['display_currency'] as String? ??
          'THB-LTT',
      description: json['description'] as String?,
    );
  }
}

class MeowCreditOrder {
  const MeowCreditOrder({
    required this.orderNo,
    required this.status,
    required this.creditAmount,
    required this.bonusCredit,
    required this.totalCredit,
    required this.priceAmount,
    required this.priceCurrency,
    required this.expectedAmount,
    required this.payToAddress,
    this.expiresAt,
    this.paymentOrderStatus,
    this.txid,
  });

  final String orderNo;
  final String status;
  final int creditAmount;
  final int bonusCredit;
  final int totalCredit;
  final String priceAmount;
  final String priceCurrency;
  final String expectedAmount;
  final String payToAddress;
  final String? expiresAt;
  final String? paymentOrderStatus;
  final String? txid;

  bool get isCredited => status == 'credited';
  bool get isPaid => paymentOrderStatus == 'paid';
  bool get isExpired {
    if (expiresAt == null) return false;
    final DateTime? dt = DateTime.tryParse(expiresAt!);
    return dt != null && dt.isBefore(DateTime.now());
  }

  factory MeowCreditOrder.fromJson(Map<String, dynamic> json) {
    return MeowCreditOrder(
      orderNo: json['order_no'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      creditAmount: _int(json['credit_amount']) ?? 0,
      bonusCredit: _int(json['bonus_credit']) ?? 0,
      totalCredit: _int(json['total_credit']) ?? 0,
      priceAmount: json['price_amount'] as String? ?? '0',
      priceCurrency: json['price_currency'] as String? ??
          json['display_currency'] as String? ??
          'THB-LTT',
      expectedAmount: json['expected_amount'] as String? ??
          json['price_amount'] as String? ??
          '0',
      payToAddress: json['pay_to_address'] as String? ?? '',
      expiresAt: json['expires_at'] as String?,
      paymentOrderStatus: json['payment_order_status'] as String?,
      txid: json['txid'] as String?,
    );
  }

  MeowCreditOrder copyWith({String? status, String? paymentOrderStatus}) {
    return MeowCreditOrder(
      orderNo: orderNo,
      status: status ?? this.status,
      creditAmount: creditAmount,
      bonusCredit: bonusCredit,
      totalCredit: totalCredit,
      priceAmount: priceAmount,
      priceCurrency: priceCurrency,
      expectedAmount: expectedAmount,
      payToAddress: payToAddress,
      expiresAt: expiresAt,
      paymentOrderStatus: paymentOrderStatus ?? this.paymentOrderStatus,
      txid: txid,
    );
  }
}

// ---------------------------------------------------------------------------
// Recharge-info response (no order created)
// ---------------------------------------------------------------------------

class MeowCreditRechargeInfo {
  const MeowCreditRechargeInfo({
    required this.packageCode,
    required this.totalCredit,
    required this.expectedAmount,
    required this.priceCurrency,
    required this.payToAddress,
    this.notice,
  });

  final String packageCode;
  final int totalCredit;
  final String expectedAmount;
  final String priceCurrency;
  final String payToAddress;
  final String? notice;

  factory MeowCreditRechargeInfo.fromJson(Map<String, dynamic> json) {
    return MeowCreditRechargeInfo(
      packageCode: json['package_code'] as String? ?? '',
      totalCredit: _int(json['total_credit']) ?? 0,
      expectedAmount: json['expected_amount'] as String? ?? '0',
      priceCurrency: json['price_currency'] as String? ??
          json['display_currency'] as String? ??
          'THB-LTT',
      payToAddress: json['pay_to_address'] as String? ?? '',
      notice: json['notice'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Verification block (nested in submit-txid and verify-now responses)
// ---------------------------------------------------------------------------

class MeowCreditVerification {
  const MeowCreditVerification({
    required this.verified,
    required this.paid,
    required this.status,
    required this.reason,
    this.confirmations,
    this.matched,
    this.expectedAmount,
    this.actualAmount,
  });

  final bool verified;
  final bool paid;
  final String status;
  final String reason;
  final int? confirmations;
  final bool? matched;
  final String? expectedAmount;
  final String? actualAmount;

  factory MeowCreditVerification.fromJson(Map<String, dynamic> json) {
    return MeowCreditVerification(
      verified: json['verified'] as bool? ?? false,
      paid: json['paid'] as bool? ?? false,
      status: json['status'] as String? ?? 'pending',
      reason: json['reason'] as String? ?? '',
      confirmations: _int(json['confirmations']),
      matched: json['matched'] as bool?,
      expectedAmount: json['expected_amount'] as String?,
      actualAmount: json['actual_amount'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Submit-txid response (flat shape; also used for the recharge record in
// verify-now's nested "recharge" field)
// ---------------------------------------------------------------------------

class MeowCreditSubmitResult {
  const MeowCreditSubmitResult({
    required this.orderNo,
    required this.status,
    required this.paymentOrderStatus,
    this.txid,
    this.creditedAt,
    this.verification,
  });

  final String orderNo;
  final String status;
  final String paymentOrderStatus;
  final String? txid;
  final String? creditedAt;
  final MeowCreditVerification? verification;

  bool get isCredited =>
      status == 'credited' || (verification?.paid ?? false);

  factory MeowCreditSubmitResult.fromJson(Map<String, dynamic> json) {
    final verJson = json['verification'];
    return MeowCreditSubmitResult(
      orderNo: json['order_no'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      paymentOrderStatus: json['payment_order_status'] as String? ?? 'pending',
      txid: json['txid'] as String?,
      creditedAt: json['credited_at'] as String?,
      verification: verJson is Map<String, dynamic>
          ? MeowCreditVerification.fromJson(verJson)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// verify-now response
// ---------------------------------------------------------------------------

class MeowCreditVerifyResult {
  const MeowCreditVerifyResult({
    required this.recharge,
    required this.verification,
    this.detail,
  });

  final MeowCreditSubmitResult recharge;
  final MeowCreditVerification verification;
  final String? detail;

  bool get isCredited => recharge.isCredited;

  factory MeowCreditVerifyResult.fromJson(Map<String, dynamic> json) {
    final rechargeJson = json['recharge'];
    final verJson = json['verification'];
    return MeowCreditVerifyResult(
      recharge: rechargeJson is Map<String, dynamic>
          ? MeowCreditSubmitResult.fromJson(rechargeJson)
          : const MeowCreditSubmitResult(
              orderNo: '', status: 'pending', paymentOrderStatus: 'pending'),
      verification: verJson is Map<String, dynamic>
          ? MeowCreditVerification.fromJson(verJson)
          : const MeowCreditVerification(
              verified: false, paid: false, status: 'pending', reason: ''),
      detail: json['detail'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------

class MeowCreditLedgerEntry {
  const MeowCreditLedgerEntry({
    required this.entryType,
    required this.status,
    required this.amount,
    this.balanceAfter,
    this.note,
    this.createdAt,
  });

  final String entryType; // recharge | spend | redeem | refund | adjust
  final String status;    // pending | completed | rejected | cancelled
  final int amount;       // positive = credit, negative = debit
  final int? balanceAfter;
  final String? note;
  final String? createdAt;

  bool get isPositive => amount >= 0;

  factory MeowCreditLedgerEntry.fromJson(Map<String, dynamic> json) {
    return MeowCreditLedgerEntry(
      entryType: json['entry_type'] as String? ?? 'recharge',
      status: json['status'] as String? ?? 'pending',
      amount: _int(json['amount']) ?? 0,
      balanceAfter: _int(json['balance_after']),
      note: json['note'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

int? _int(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v);
  return null;
}
