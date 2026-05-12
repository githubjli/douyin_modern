import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../features/auth/application/auth_providers.dart';
import '../domain/meow_credit_wallet.dart';

class MeowCreditRepository {
  const MeowCreditRepository(this._client);
  final ApiClient _client;

  Future<MeowCreditWallet> getWallet() async {
    final response = await _client.get<dynamic>(
      Endpoints.meowCreditWallet,
      authenticated: true,
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid wallet response');
    }
    return MeowCreditWallet.fromJson(data);
  }

  Future<List<MeowCreditPackage>> getPackages() async {
    final response = await _client.get<dynamic>(
      Endpoints.meowCreditPackages,
      authenticated: true,
    );
    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(MeowCreditPackage.fromJson)
          .toList();
    }
    if (data is Map<String, dynamic> && data['results'] is List) {
      return (data['results'] as List)
          .whereType<Map<String, dynamic>>()
          .map(MeowCreditPackage.fromJson)
          .toList();
    }
    return const <MeowCreditPackage>[];
  }

  /// Create a recharge with a custom [amount] (credits).
  /// Pass [packageCode] instead when using fixed packages.
  Future<MeowCreditOrder> createRecharge(int amount) async {
    final response = await _client.post<dynamic>(
      Endpoints.meowCreditRecharges,
      data: <String, dynamic>{'amount': amount},
      authenticated: true,
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid recharge order response');
    }
    return MeowCreditOrder.fromJson(data);
  }

  Future<MeowCreditOrder> getRechargeDetail(String orderNo) async {
    final response = await _client.get<dynamic>(
      Endpoints.meowCreditRechargeDetail(orderNo),
      authenticated: true,
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid recharge detail response');
    }
    return MeowCreditOrder.fromJson(data);
  }

  Future<void> submitTxHint(String orderNo, String txid) async {
    await _client.post<dynamic>(
      Endpoints.meowCreditTxHint(orderNo),
      data: <String, dynamic>{'txid': txid},
      authenticated: true,
    );
  }

  Future<List<MeowCreditLedgerEntry>> getLedger() async {
    final response = await _client.get<dynamic>(
      Endpoints.meowCreditLedger,
      authenticated: true,
    );
    final data = response.data;
    List<dynamic> items = const <dynamic>[];
    if (data is List) {
      items = data;
    } else if (data is Map<String, dynamic> && data['results'] is List) {
      items = data['results'] as List<dynamic>;
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(MeowCreditLedgerEntry.fromJson)
        .toList();
  }

  Future<void> createRedeem({
    required int amount,
    required String receivingAddress,
  }) async {
    await _client.post<dynamic>(
      Endpoints.meowCreditRedeems,
      data: <String, dynamic>{
        'amount': amount,
        'receiving_address': receivingAddress,
      },
      authenticated: true,
    );
  }
}

final meowCreditRepositoryProvider = Provider<MeowCreditRepository>((ref) {
  return MeowCreditRepository(ref.watch(apiClientProvider));
});
