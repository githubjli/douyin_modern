import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meow_credit_repository.dart';
import '../domain/meow_credit_wallet.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class RechargeState {
  const RechargeState({
    this.order,
    this.submittingTxid = false,
    this.savingQr = false,
    this.remaining = Duration.zero,
  });

  final MeowCreditOrder? order;
  final bool submittingTxid;
  final bool savingQr;
  final Duration remaining;

  bool get isCredited => order?.isCredited ?? false;
  bool get isExpired =>
      order?.isExpired == true && remaining == Duration.zero && !isCredited;

  RechargeState copyWith({
    MeowCreditOrder? order,
    bool? submittingTxid,
    bool? savingQr,
    Duration? remaining,
  }) {
    return RechargeState(
      order: order ?? this.order,
      submittingTxid: submittingTxid ?? this.submittingTxid,
      savingQr: savingQr ?? this.savingQr,
      remaining: remaining ?? this.remaining,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class RechargeNotifier extends StateNotifier<RechargeState> {
  RechargeNotifier(this._repo, MeowCreditOrder initialOrder)
      : super(RechargeState(order: initialOrder));

  final MeowCreditRepository _repo;

  RechargeState get currentState => state;

  void tick(Duration remaining) {
    state = state.copyWith(remaining: remaining);
  }

  void setSavingQr({required bool value}) {
    state = state.copyWith(savingQr: value);
  }

  /// Poll the order; returns true when credited.
  Future<bool> pollOrder() async {
    final String? orderNo = state.order?.orderNo;
    if (orderNo == null) return false;
    try {
      final MeowCreditOrder updated = await _repo.getRechargeDetail(orderNo);
      state = state.copyWith(order: updated);
      return updated.isCredited;
    } catch (_) {
      return false;
    }
  }

  /// Submit txid hint; returns true on success.
  Future<bool> submitTxHint(String txid) async {
    final String? orderNo = state.order?.orderNo;
    if (orderNo == null) return false;
    state = state.copyWith(submittingTxid: true);
    try {
      await _repo.submitTxHint(orderNo, txid);
      return true;
    } catch (_) {
      return false;
    } finally {
      state = state.copyWith(submittingTxid: false);
    }
  }
}

// Placeholder — always overridden via ProviderScope in MeowCreditRechargePage.
final rechargeNotifierProvider =
    StateNotifierProvider.autoDispose<RechargeNotifier, RechargeState>(
  (ref) => throw UnimplementedError('rechargeNotifierProvider must be overridden'),
);
