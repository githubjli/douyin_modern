import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/membership_order.dart';
import '../domain/membership_repository.dart';

class PaymentPageState {
  const PaymentPageState({
    required this.currentOrder,
    this.remaining = Duration.zero,
    this.savingQr = false,
    this.submittingTx = false,
    this.verifyingNow = false,
    this.txSubmitted = false,
  });

  final MembershipOrder currentOrder;
  final Duration remaining;
  final bool savingQr;
  final bool submittingTx;
  final bool verifyingNow;
  final bool txSubmitted;

  bool get isPaid => currentOrder.isSuccessLike;

  PaymentPageState copyWith({
    MembershipOrder? currentOrder,
    Duration? remaining,
    bool? savingQr,
    bool? submittingTx,
    bool? verifyingNow,
    bool? txSubmitted,
  }) {
    return PaymentPageState(
      currentOrder: currentOrder ?? this.currentOrder,
      remaining: remaining ?? this.remaining,
      savingQr: savingQr ?? this.savingQr,
      submittingTx: submittingTx ?? this.submittingTx,
      verifyingNow: verifyingNow ?? this.verifyingNow,
      txSubmitted: txSubmitted ?? this.txSubmitted,
    );
  }
}

class PaymentPageNotifier extends StateNotifier<PaymentPageState> {
  PaymentPageNotifier({
    required MembershipOrder initialOrder,
    required MembershipRepository repository,
  })  : _repository = repository,
        super(PaymentPageState(currentOrder: initialOrder));

  final MembershipRepository _repository;

  void tick(Duration remaining) {
    state = state.copyWith(remaining: remaining);
  }

  /// Returns true if the order is now success-like (stop timers).
  Future<bool> pollOrder() async {
    try {
      final MembershipOrder updated =
          await _repository.getOrder(state.currentOrder.orderNo);
      state = state.copyWith(currentOrder: updated);
      return updated.isSuccessLike;
    } catch (_) {
      return false;
    }
  }

  /// Returns true on success, false on error (caller shows the error message).
  Future<bool> verifyNow() async {
    if (state.verifyingNow) return false;
    state = state.copyWith(verifyingNow: true);
    try {
      final MembershipOrder updated =
          await _repository.verifyNow(state.currentOrder.orderNo);
      state = state.copyWith(currentOrder: updated, verifyingNow: false);
      return true;
    } catch (_) {
      state = state.copyWith(verifyingNow: false);
      return false;
    }
  }

  /// Returns true on success, false on error (caller shows the error message).
  Future<bool> submitTxHint({
    required String orderNo,
    required String txid,
  }) async {
    if (state.submittingTx) return false;
    state = state.copyWith(submittingTx: true);
    try {
      final MembershipOrder updated = await _repository.submitTxHint(
        orderNo: orderNo,
        txid: txid,
      );
      state = state.copyWith(
        currentOrder: updated,
        submittingTx: false,
        txSubmitted: true,
      );
      return true;
    } catch (_) {
      state = state.copyWith(submittingTx: false);
      return false;
    }
  }

  void setSavingQr({required bool value}) {
    state = state.copyWith(savingQr: value);
  }
}

/// Placeholder — always overridden via ProviderScope inside MembershipPaymentPage.
final paymentPageProvider = StateNotifierProvider.autoDispose<
    PaymentPageNotifier, PaymentPageState>(
  (ref) => throw UnimplementedError('paymentPageProvider must be overridden'),
);
