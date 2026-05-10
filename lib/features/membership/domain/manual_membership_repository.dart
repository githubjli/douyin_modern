import 'manual_payment_info.dart';
import 'manual_tx_hint.dart';
import 'membership_status.dart';

abstract class ManualMembershipRepository {
  /// GET /api/membership/manual/payment-info/?plan_code={planCode}
  /// Returns payment address and amount. Does NOT create an order.
  Future<ManualPaymentInfo> getPaymentInfo({required String planCode});

  /// GET /api/membership/manual/tx-hints/
  /// Returns the authenticated user's submitted transaction history.
  Future<List<ManualTxHint>> getTxHints();

  /// POST /api/membership/manual/tx-hints/
  /// Submits a txid for a given plan. The endpoint may be disabled server-side;
  /// callers should catch [ManualTxSubmitDisabledException] and surface a notice.
  Future<ManualTxHint> submitTxHint({
    required String planCode,
    required String txid,
  });

  /// POST /api/membership/manual/tx-hints/{id}/verify-now/
  /// Triggers an immediate on-chain re-verification for the given hint.
  Future<ManualTxHintVerifyResult> verifyNow(int id);

  /// GET /api/membership/me/
  /// Returns the current user's membership activation status.
  Future<MembershipStatus?> getMembershipStatus();
}

/// Thrown when the server returns the "not accepting txid" notice.
class ManualTxSubmitDisabledException implements Exception {
  const ManualTxSubmitDisabledException([this.message]);
  final String? message;
  @override
  String toString() => message ?? 'txid submission is not available yet';
}

class ManualTxHintVerifyResult {
  const ManualTxHintVerifyResult({
    required this.verified,
    required this.status,
    this.orderNo,
    this.reason,
    this.confirmations,
    this.requiredConfirmations,
  });

  factory ManualTxHintVerifyResult.fromJson(Map<String, dynamic> json) {
    return ManualTxHintVerifyResult(
      verified: json['verified'] == true,
      status: _str(json['status']) ?? 'unknown',
      orderNo: _str(json['order_no']),
      reason: _str(json['reason']),
      confirmations: _int(json['confirmations']),
      requiredConfirmations: _int(json['required_confirmations']),
    );
  }

  final bool verified;
  final String status;
  final String? orderNo;
  final String? reason;
  final int? confirmations;
  final int? requiredConfirmations;
}

String? _str(dynamic v) {
  if (v is String && v.trim().isNotEmpty) return v.trim();
  return null;
}

int? _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}
