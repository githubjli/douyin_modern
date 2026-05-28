import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../domain/membership_order.dart';
import '../domain/membership_plan.dart';
import '../domain/membership_repository.dart';
import '../domain/membership_status.dart';
import '../domain/payment_asset_option.dart';

class RemoteMembershipRepository implements MembershipRepository {
  RemoteMembershipRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<MembershipPlan>> getPlans() async {
    final response = await _apiClient.get<dynamic>(Endpoints.membershipPlans);
    return _rows(response.data).map(_mapPlan).toList();
  }

  @override
  Future<MembershipOrder> createOrder({
    required String planCode,
    String? paymentAsset,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{'plan_code': planCode};
    if (paymentAsset != null && paymentAsset.trim().isNotEmpty) {
      body['payment_asset'] = paymentAsset.trim();
    }
    final response = await _apiClient.post<dynamic>(
      Endpoints.membershipOrders,
      data: body,
      authenticated: true,
    );
    return _mapOrderResponse(response.data);
  }

  @override
  Future<List<MembershipOrder>> listOrders() async {
    final response = await _apiClient.get<dynamic>(
      Endpoints.membershipOrders,
      authenticated: true,
    );
    return _rows(response.data)
        .map((Map<String, dynamic> row) => MembershipOrder.fromJson(row))
        .toList();
  }

  @override
  Future<MembershipOrder> getOrder(String orderNo) async {
    final response = await _apiClient.get<dynamic>(
      Endpoints.membershipOrderDetail(orderNo),
      authenticated: true,
    );
    return _mapOrderResponse(response.data);
  }

  @override
  Future<MembershipOrder> submitTxHint({
    required String orderNo,
    required String txid,
  }) async {
    final response = await _apiClient.post<dynamic>(
      Endpoints.membershipOrderTxHint(orderNo),
      data: <String, dynamic>{'txid': txid},
      authenticated: true,
    );
    return _mapOrderResponse(response.data);
  }

  @override
  Future<MembershipOrder> verifyNow(String orderNo) async {
    final response = await _apiClient.post<dynamic>(
      Endpoints.membershipOrderVerifyNow(orderNo),
      authenticated: true,
    );
    return _mapOrderResponse(response.data);
  }

  @override
  Future<MembershipStatus?> getCurrentStatus() async {
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

  List<Map<String, dynamic>> _rows(dynamic data) {
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    if (data is Map<String, dynamic>) {
      final dynamic results = data['results'];
      if (results is List) {
        return results.whereType<Map<String, dynamic>>().toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  MembershipStatus? _mapStatus(Map<String, dynamic> data) {
    if (data.isEmpty) return null;

    // New API shape: { "is_active": bool, "current_membership": { ... } | null }
    if (data.containsKey('is_active')) {
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
        planTitle: _nonEmptyStr(current['plan_name']) ??
            _nonEmptyStr(current['plan_code']) ??
            'Membership',
        status: 'active',
        isActive: true,
        startsAt: _nonEmptyStr(current['starts_at']),
        endsAt: _nonEmptyStr(current['ends_at']),
      );
    }

    // Legacy API shape: flat object with status / plan fields
    final String planTitle = _statusPlanTitle(data);
    final String status = _nonEmptyStr(data['status']) ?? 'inactive';
    return MembershipStatus(
      planTitle: planTitle,
      status: status,
      startsAt: _nonEmptyStr(data['starts_at']) ??
          _nonEmptyStr(data['current_period_start']),
      endsAt: _nonEmptyStr(data['ends_at']) ??
          _nonEmptyStr(data['current_period_end']),
      isActive: _statusIsActive(data['is_active'] ?? data['active'], status),
    );
  }

  String _statusPlanTitle(Map<String, dynamic> data) {
    final dynamic plan = data['plan'];
    return _nestedStr(plan, 'title') ??
        _nestedStr(plan, 'name') ??
        _nonEmptyStr(plan) ??
        _nonEmptyStr(data['plan_title']) ??
        _nonEmptyStr(data['plan_name']) ??
        'Membership';
  }

  bool _statusIsActive(dynamic value, String status) {
    if (value is bool) return value;
    if (value is String) {
      final String normalized = value.toLowerCase().trim();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    final String normalizedStatus = status.toLowerCase().trim();
    return normalizedStatus == 'active' ||
        normalizedStatus == 'trialing' ||
        normalizedStatus == 'trial';
  }

  MembershipOrder _mapOrderResponse(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid membership order response');
    }
    return MembershipOrder.fromJson(data);
  }

  MembershipPlan _mapPlan(Map<String, dynamic> data) {
    final String id = _nonEmptyStr(data['id']) ?? '';
    final String title = _nonEmptyStr(data['title']) ??
        _nonEmptyStr(data['name']) ??
        'Membership';
    return MembershipPlan(
      id: id.isEmpty ? null : id,
      code: _planCode(data, id),
      title: title,
      price: _price(data),
      perks: _perks(data),
      durationDays: _int(data['duration_days']),
      settlementBlockchain: _settlementStr(data, 'blockchain'),
      settlementTokenName: _settlementStr(data, 'token_name'),
      settlementTokenSymbol: _settlementStr(data, 'token_symbol'),
      settlementTokenPeg: _settlementStr(data, 'token_peg'),
      supportedPaymentAssets: _stringListField(data['supported_payment_assets']),
      basePriceAmount: _nonEmptyStr(data['base_price_amount']),
      basePriceAsset: _nonEmptyStr(data['base_price_asset']),
      paymentAssetOptions: _paymentAssetOptions(data['payment_asset_options']),
    );
  }

  String? _planCode(Map<String, dynamic> data, String id) {
    return _nonEmptyStr(data['code']) ??
        _nonEmptyStr(data['plan_code']) ??
        _nonEmptyStr(data['slug']) ??
        (id.isEmpty ? null : id);
  }

  String _price(Map<String, dynamic> data) {
    final String? amount = _nonEmptyStr(data['price_lbc']) ??
        _nonEmptyStr(data['amount']) ??
        _nonEmptyStr(data['price']) ??
        _nonEmptyStr(data['price_amount']);
    final String? currency = _settlementStr(data, 'token_symbol') ??
        _nonEmptyStr(data['currency']) ??
        _nonEmptyStr(data['price_currency']);
    final int? durationDays = _int(data['duration_days']);
    final String? interval = _nonEmptyStr(data['interval']) ??
        _nonEmptyStr(data['billing_interval']);

    if (amount == null) return 'Price unavailable';

    final bool usesMembershipPlanShape =
        data.containsKey('price_lbc') || data.containsKey('duration_days');
    final String formattedAmount = _formatAmount(amount);
    final StringBuffer price = StringBuffer();

    if (usesMembershipPlanShape) {
      price.write(formattedAmount);
      if (currency != null && currency.trim().isNotEmpty) {
        price.write(' ');
        price.write(currency.trim());
      }
      if (durationDays != null) {
        price.write(' / ');
        price.write(durationDays);
        price.write(durationDays == 1 ? ' day' : ' days');
      }
      return price.toString();
    }

    if (currency != null && currency.trim().isNotEmpty) {
      price.write(currency.trim());
      price.write(' ');
    }
    price.write(formattedAmount);
    if (interval != null && interval.trim().isNotEmpty) {
      price.write(' / ');
      price.write(interval.trim());
    }
    return price.toString();
  }

  String _perks(Map<String, dynamic> data) {
    return _stringList(data['perks']) ??
        _nonEmptyStr(data['description']) ??
        _stringList(data['features']) ??
        'Membership benefits included';
  }

  String? _stringList(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is List) {
      final List<String> items = value
          .map(_str)
          .whereType<String>()
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .toList();
      if (items.isNotEmpty) return items.join(', ');
    }
    return null;
  }

  String? _settlementStr(Map<String, dynamic> data, String key) {
    return _nestedStr(data['settlement'], key);
  }

  String? _nestedStr(dynamic value, String key) {
    if (value is Map<String, dynamic>) return _nonEmptyStr(value[key]);
    return null;
  }

  int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  String _formatAmount(String amount) {
    final String trimmed = amount.trim();
    if (!trimmed.contains('.')) return trimmed;
    return trimmed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String? _nonEmptyStr(dynamic value) {
    final String? stringValue = _str(value)?.trim();
    if (stringValue == null || stringValue.isEmpty) return null;
    return stringValue;
  }

  String? _str(dynamic value) {
    if (value is String) return value;
    if (value is num) return value.toString();
    return null;
  }

  List<String>? _stringListField(dynamic value) {
    if (value is List) {
      final List<String> items = value
          .whereType<String>()
          .map((String s) => s.trim())
          .where((String s) => s.isNotEmpty)
          .toList();
      return items.isEmpty ? null : items;
    }
    return null;
  }

  List<PaymentAssetOption>? _paymentAssetOptions(dynamic value) {
    if (value is! List) return null;
    final List<PaymentAssetOption> options = value
        .whereType<Map<String, dynamic>>()
        .map(PaymentAssetOption.fromJson)
        .where((PaymentAssetOption o) => o.assetCode.isNotEmpty)
        .toList();
    return options.isEmpty ? null : options;
  }
}
