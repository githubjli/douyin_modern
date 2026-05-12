import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
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

  Future<MeowCreditRechargeInfo> getRechargeInfo(String packageCode) async {
    final response = await _client.get<dynamic>(
      Endpoints.meowCreditRechargeInfo(packageCode),
      authenticated: true,
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid recharge-info response');
    }
    return MeowCreditRechargeInfo.fromJson(data);
  }

  /// Submits a txid for a package; the backend auto-verifies once.
  /// Returns a [MeowCreditSubmitResult] with status == 'credited' or 'pending'.
  /// Throws [ApiError] with statusCode 409 on duplicate txid.
  Future<MeowCreditSubmitResult> submitTxid(
      String packageCode, String txid) async {
    final response = await _client.post<dynamic>(
      Endpoints.meowCreditSubmitTxid,
      data: <String, dynamic>{'package_code': packageCode, 'txid': txid},
      authenticated: true,
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid submit-txid response');
    }
    return MeowCreditSubmitResult.fromJson(data);
  }

  Future<MeowCreditVerifyResult> verifyNow(String orderNo) async {
    final response = await _client.post<dynamic>(
      Endpoints.meowCreditVerifyNow(orderNo),
      authenticated: true,
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid verify-now response');
    }
    return MeowCreditVerifyResult.fromJson(data);
  }

  Future<MeowCreditSubmitResult> getRechargeDetail(String orderNo) async {
    final response = await _client.get<dynamic>(
      Endpoints.meowCreditRechargeDetail(orderNo),
      authenticated: true,
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid recharge detail response');
    }
    return MeowCreditSubmitResult.fromJson(data);
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

  Future<MeowCreditRedeem> createRedeem({
    required int amount,
    required String receivingAddress,
  }) async {
    final response = await _client.post<dynamic>(
      Endpoints.meowCreditRedeems,
      data: <String, dynamic>{
        'amount': amount,
        'redeem_method': 'thb_ltt_wallet',
        'account_snapshot': <String, dynamic>{
          'receiving_address': receivingAddress,
        },
      },
      authenticated: true,
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid redeem response');
    }
    return MeowCreditRedeem.fromJson(data);
  }

  Future<List<MeowCreditRedeem>> getRedeems() async {
    final response = await _client.get<dynamic>(
      Endpoints.meowCreditRedeems,
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
        .map(MeowCreditRedeem.fromJson)
        .toList();
  }
}

final meowCreditRepositoryProvider = Provider<MeowCreditRepository>((ref) {
  return MeowCreditRepository(ref.watch(apiClientProvider));
});
