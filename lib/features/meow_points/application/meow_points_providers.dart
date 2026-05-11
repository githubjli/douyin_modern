import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/endpoints.dart';
import '../../../features/auth/application/auth_providers.dart';
import '../domain/meow_point_wallet.dart';

final meowPointsWalletProvider =
    FutureProvider.autoDispose<MeowPointWallet>((ref) async {
  final response = await ref.watch(apiClientProvider).get<dynamic>(
    Endpoints.meowPointsWallet,
    authenticated: true,
  );
  final dynamic data = response.data;
  if (data is! Map<String, dynamic>) {
    throw FormatException('Unexpected wallet response format');
  }
  return MeowPointWallet.fromJson(data);
});

/// True while the daily-reward claim request is in-flight.
final claimingRewardProvider = StateProvider.autoDispose<bool>((ref) => false);
