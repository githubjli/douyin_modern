import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../domain/membership_plan.dart';
import '../domain/membership_repository.dart';
import '../domain/membership_status.dart';

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

  MembershipPlan _mapPlan(Map<String, dynamic> data) {
    final String id = _nonEmptyStr(data['id']) ?? '';
    final String title = _nonEmptyStr(data['title']) ??
        _nonEmptyStr(data['name']) ??
        'Membership';
    return MembershipPlan(
      id: id.isEmpty ? null : id,
      title: title,
      price: _price(data),
      perks: _perks(data),
    );
  }

  String _price(Map<String, dynamic> data) {
    final String? amount = _nonEmptyStr(data['amount']) ??
        _nonEmptyStr(data['price']) ??
        _nonEmptyStr(data['price_amount']);
    final String? currency =
        _nonEmptyStr(data['currency']) ?? _nonEmptyStr(data['price_currency']);
    final String? interval = _nonEmptyStr(data['interval']) ??
        _nonEmptyStr(data['billing_interval']);

    if (amount == null) return 'Price unavailable';

    final StringBuffer price = StringBuffer();
    if (currency != null && currency.trim().isNotEmpty) {
      price.write(currency.trim());
      price.write(' ');
    }
    price.write(amount.trim());
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

  String? _nestedStr(dynamic value, String key) {
    if (value is Map<String, dynamic>) return _nonEmptyStr(value[key]);
    return null;
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
}
