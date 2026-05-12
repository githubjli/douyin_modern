import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meow_credit_repository.dart';
import '../domain/meow_credit_wallet.dart';

// ---------------------------------------------------------------------------
// Wallet
// ---------------------------------------------------------------------------

final meowCreditWalletProvider =
    FutureProvider.autoDispose<MeowCreditWallet>((ref) {
  return ref.watch(meowCreditRepositoryProvider).getWallet();
});

// ---------------------------------------------------------------------------
// Packages
// ---------------------------------------------------------------------------

final meowCreditPackagesProvider =
    FutureProvider.autoDispose<List<MeowCreditPackage>>((ref) {
  return ref.watch(meowCreditRepositoryProvider).getPackages();
});

// ---------------------------------------------------------------------------
// Ledger
// ---------------------------------------------------------------------------

final meowCreditLedgerProvider =
    FutureProvider.autoDispose<List<MeowCreditLedgerEntry>>((ref) {
  return ref.watch(meowCreditRepositoryProvider).getLedger();
});

// ---------------------------------------------------------------------------
// Redeems
// ---------------------------------------------------------------------------

final meowCreditRedeemsProvider =
    FutureProvider.autoDispose<List<MeowCreditRedeem>>((ref) {
  return ref.watch(meowCreditRepositoryProvider).getRedeems();
});
