import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../data/meow_credit_repository.dart';
import '../domain/meow_credit_wallet.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class RechargeState {
  const RechargeState({
    this.result,
    this.submitting = false,
    this.verifying = false,
  });

  /// Set after a successful submit-txid or verify-now call.
  final MeowCreditSubmitResult? result;
  final bool submitting;
  final bool verifying;

  bool get hasResult => result != null;
  bool get isCredited => result?.isCredited ?? false;
  bool get isPending => hasResult && !isCredited;
  bool get canVerify => isPending && !verifying;

  RechargeState copyWith({
    MeowCreditSubmitResult? result,
    bool? submitting,
    bool? verifying,
  }) {
    return RechargeState(
      result: result ?? this.result,
      submitting: submitting ?? this.submitting,
      verifying: verifying ?? this.verifying,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class RechargeNotifier extends StateNotifier<RechargeState> {
  RechargeNotifier(this._repo) : super(const RechargeState());

  final MeowCreditRepository _repo;

  RechargeState get currentState => state;

  /// Submits txid. Returns true when credited immediately.
  /// Throws [ApiError] (check statusCode == 409 for duplicate txid).
  Future<bool> submitTxid(String packageCode, String txid) async {
    state = state.copyWith(submitting: true);
    try {
      final MeowCreditSubmitResult result =
          await _repo.submitTxid(packageCode, txid);
      state = state.copyWith(result: result, submitting: false);
      return result.isCredited;
    } catch (e) {
      state = state.copyWith(submitting: false);
      rethrow;
    }
  }

  /// Triggers a manual verify-now check. Returns true when credited.
  Future<bool> verifyNow() async {
    final String? orderNo = state.result?.orderNo;
    if (orderNo == null || orderNo.isEmpty) return false;
    state = state.copyWith(verifying: true);
    try {
      final MeowCreditVerifyResult verifyResult =
          await _repo.verifyNow(orderNo);
      state = state.copyWith(
        result: verifyResult.recharge,
        verifying: false,
      );
      return verifyResult.isCredited;
    } catch (_) {
      state = state.copyWith(verifying: false);
      return false;
    }
  }
}

// Placeholder — always overridden via ProviderScope in MeowCreditRechargePage.
final rechargeNotifierProvider =
    StateNotifierProvider.autoDispose<RechargeNotifier, RechargeState>(
  (ref) =>
      throw UnimplementedError('rechargeNotifierProvider must be overridden'),
);
