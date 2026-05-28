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
// Notifier — plain Dart class; used directly (not through ProviderScope)
// ---------------------------------------------------------------------------

class RechargeNotifier {
  RechargeNotifier(this._repo);

  final MeowCreditRepository _repo;
  RechargeState _state = const RechargeState();

  RechargeState get currentState => _state;

  /// Submits txid. Returns true when credited immediately.
  /// Throws [ApiError] (check statusCode == 409 for duplicate txid).
  Future<bool> submitTxid(String packageCode, String txid) async {
    _state = _state.copyWith(submitting: true);
    try {
      final MeowCreditSubmitResult result =
          await _repo.submitTxid(packageCode, txid);
      _state = _state.copyWith(result: result, submitting: false);
      return result.isCredited;
    } catch (e) {
      _state = _state.copyWith(submitting: false);
      rethrow;
    }
  }

  /// Triggers a manual verify-now check. Returns true when credited.
  Future<bool> verifyNow() async {
    final String? orderNo = _state.result?.orderNo;
    if (orderNo == null || orderNo.isEmpty) return false;
    _state = _state.copyWith(verifying: true);
    try {
      final MeowCreditVerifyResult verifyResult =
          await _repo.verifyNow(orderNo);
      _state = _state.copyWith(
        result: verifyResult.recharge,
        verifying: false,
      );
      return verifyResult.isCredited;
    } catch (_) {
      _state = _state.copyWith(verifying: false);
      return false;
    }
  }
}
