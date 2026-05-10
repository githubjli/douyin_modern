/// A user-submitted transaction hint returned by
/// GET  /api/membership/manual/tx-hints/
/// POST /api/membership/manual/tx-hints/
enum ManualTxHintStatus {
  pending,
  submitted,
  dryRunVerified,
  pendingConfirmation,
  verified,
  rejected,
  unknown;

  static ManualTxHintStatus fromString(String raw) {
    return switch (raw.toLowerCase().trim()) {
      'pending' => ManualTxHintStatus.pending,
      'submitted' => ManualTxHintStatus.submitted,
      'dry_run_verified' => ManualTxHintStatus.dryRunVerified,
      'pending_confirmation' => ManualTxHintStatus.pendingConfirmation,
      'verified' => ManualTxHintStatus.verified,
      'rejected' => ManualTxHintStatus.rejected,
      _ => ManualTxHintStatus.unknown,
    };
  }

  String get displayLabel => switch (this) {
        ManualTxHintStatus.pending => 'Pending',
        ManualTxHintStatus.submitted => 'Submitted',
        ManualTxHintStatus.dryRunVerified => 'Chain verified',
        ManualTxHintStatus.pendingConfirmation => 'Awaiting confirmations',
        ManualTxHintStatus.verified => 'Verified',
        ManualTxHintStatus.rejected => 'Rejected',
        ManualTxHintStatus.unknown => 'Unknown',
      };

  bool get isTerminal =>
      this == ManualTxHintStatus.verified ||
      this == ManualTxHintStatus.rejected;

  bool get isSuccess => this == ManualTxHintStatus.verified;
}

class ManualTxHint {
  const ManualTxHint({
    required this.id,
    required this.planCode,
    required this.planName,
    required this.txid,
    required this.status,
    required this.confirmations,
    required this.expectedAmountLbc,
    required this.payToAddress,
    required this.createdAt,
    this.verified = false,
    this.actualAmountLbc,
    this.orderNo,
    this.rejectReason,
    this.verifiedAt,
    this.purchaseMode,
    this.estimatedNewStartsAt,
    this.estimatedNewEndsAt,
  });

  factory ManualTxHint.fromJson(Map<String, dynamic> json) {
    // Submit response uses manual_payment_id; list response uses id.
    final int? id =
        _int(json['id']) ?? _int(json['manual_payment_id']);
    final String? txid = _str(json['txid']);
    final String? statusRaw = _str(json['status']);
    if (id == null || txid == null || statusRaw == null) {
      throw const FormatException('Invalid manual tx hint response');
    }
    return ManualTxHint(
      id: id,
      planCode: _str(json['plan_code']) ?? '',
      planName: _str(json['plan_name']) ?? _str(json['plan_title']) ?? '',
      txid: txid,
      status: ManualTxHintStatus.fromString(statusRaw),
      confirmations: _int(json['confirmations']) ?? 0,
      expectedAmountLbc: _str(json['expected_amount_lbc']) ?? '',
      actualAmountLbc: _str(json['actual_amount_lbc']),
      payToAddress: _str(json['pay_to_address']) ?? _str(json['address']) ?? '',
      orderNo: _str(json['order_no']),
      rejectReason: _str(json['reject_reason']),
      createdAt: _str(json['created_at']) ?? '',
      verifiedAt: _str(json['verified_at']),
      verified: json['verified'] == true,
      purchaseMode: _str(json['purchase_mode']),
      estimatedNewStartsAt: _str(json['estimated_new_starts_at']),
      estimatedNewEndsAt: _str(json['estimated_new_ends_at']),
    );
  }

  final int id;
  final String planCode;
  final String planName;
  final String txid;
  final ManualTxHintStatus status;
  final int confirmations;
  final String expectedAmountLbc;
  final String? actualAmountLbc;
  final String payToAddress;
  final String? orderNo;
  final String? rejectReason;
  final String createdAt;
  final String? verifiedAt;
  /// Only populated in submit response.
  final bool verified;
  final String? purchaseMode;
  final String? estimatedNewStartsAt;
  final String? estimatedNewEndsAt;
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
