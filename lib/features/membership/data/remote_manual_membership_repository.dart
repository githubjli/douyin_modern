import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/endpoints.dart';
import '../domain/manual_membership_repository.dart';
import '../domain/manual_payment_info.dart';
import '../domain/manual_tx_hint.dart';
import '../domain/membership_status.dart';

class RemoteManualMembershipRepository implements ManualMembershipRepository {
  RemoteManualMembershipRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<ManualPaymentInfo> getPaymentInfo({required String planCode}) async {
    final response = await _apiClient.get<dynamic>(
      Endpoints.manualPaymentInfo(planCode),
      authenticated: true,
    );
    final dynamic data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid payment info response');
    }
    return ManualPaymentInfo.fromJson(data);
  }

  @override
  Future<List<ManualTxHint>> getTxHints() async {
    final response = await _apiClient.get<dynamic>(
      Endpoints.manualTxHints,
      authenticated: true,
    );
    final dynamic data = response.data;
    final List<dynamic> rows = switch (data) {
      final List<dynamic> list => list,
      final Map<String, dynamic> map when map['results'] is List =>
        map['results'] as List<dynamic>,
      _ => <dynamic>[],
    };
    return rows
        .whereType<Map<String, dynamic>>()
        .map(ManualTxHint.fromJson)
        .toList();
  }

  @override
  Future<ManualTxHint> submitTxHint({
    required String planCode,
    required String txid,
  }) async {
    try {
      final response = await _apiClient.post<dynamic>(
        Endpoints.manualTxHints,
        data: <String, dynamic>{'plan_code': planCode, 'txid': txid},
        authenticated: true,
      );
      final dynamic data = response.data;
      // Server may explicitly disable this endpoint (2xx with detail field).
      if (data is Map<String, dynamic>) {
        final String? detail = _str(data['detail']);
        if (detail != null &&
            detail.toLowerCase().contains('does not accept')) {
          throw ManualTxSubmitDisabledException(detail);
        }
        return ManualTxHint.fromJson(data);
      }
      throw const FormatException('Invalid tx hint response');
    } on ManualTxSubmitDisabledException {
      rethrow;
    } on ApiError catch (e) {
      final String msg = e.message.toLowerCase();
      // Endpoint disabled — server says "does not accept".
      if (msg.contains('does not accept')) {
        throw ManualTxSubmitDisabledException(e.message);
      }
      // 409 Conflict — txid already submitted.
      if (e.statusCode == 409 || msg.contains('already submitted')) {
        throw ManualTxDuplicateException(
          e.message,
          manualPaymentId: _intFromError(e),
        );
      }
      // User already has a pending payment.
      if (msg.contains('pending manual membership payment already exists') ||
          msg.contains('pending payment already exists')) {
        throw ManualTxPendingExistsException(
          e.message,
          manualPaymentId: _intFromError(e),
        );
      }
      rethrow;
    }
  }

  @override
  Future<ManualTxHintVerifyResult> verifyNow(int id) async {
    final response = await _apiClient.post<dynamic>(
      Endpoints.manualTxHintVerifyNow(id),
      authenticated: true,
    );
    final dynamic data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid verify-now response');
    }
    return ManualTxHintVerifyResult.fromJson(data);
  }

  @override
  Future<MembershipStatus?> getMembershipStatus() async {
    final response = await _apiClient.get<dynamic>(
      Endpoints.membershipMe,
      authenticated: true,
    );
    final dynamic data = response.data;
    if (data == null) return null;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid membership status response');
    }
    return _mapStatus(data);
  }

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  MembershipStatus? _mapStatus(Map<String, dynamic> data) {
    // New API shape:
    // { "is_active": bool, "current_membership": { ... } | null }
    final bool isActive = data['is_active'] == true;
    final dynamic current = data['current_membership'];

    if (!isActive || current is! Map<String, dynamic>) {
      return const MembershipStatus(
        planTitle: 'Membership',
        status: 'inactive',
        isActive: false,
      );
    }

    return MembershipStatus(
      planTitle: _str(current['plan_name']) ??
          _str(current['plan_code']) ??
          'Membership',
      status: 'active',
      isActive: true,
      startsAt: _str(current['starts_at']),
      endsAt: _str(current['ends_at']),
    );
  }

  String? _str(dynamic v) {
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }
}

// Re-export so callers only need one import.
// ignore: unused_element
ApiError _unused() => throw UnimplementedError();

int? _intFromError(ApiError e) => null; // detail body not accessible after mapping
