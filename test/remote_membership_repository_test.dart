import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/core/network/api_client.dart';
import 'package:meow_media/core/network/endpoints.dart';
import 'package:meow_media/features/membership/data/remote_membership_repository.dart';

void main() {
  test('loads membership plans from the membership plans endpoint', () async {
    final _FakeApiClient apiClient = _FakeApiClient(<String, dynamic>{
      'results': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 12,
          'name': 'Gold Plan',
          'price_amount': '9.99',
          'price_currency': 'USD',
          'billing_interval': 'month',
          'features': <String>['Badge', 'Exclusive rooms'],
        },
      ],
    });
    final RemoteMembershipRepository repository =
        RemoteMembershipRepository(apiClient: apiClient);

    final plans = await repository.getPlans();

    expect(apiClient.requestedPath, Endpoints.membershipPlans);
    expect(plans, hasLength(1));
    expect(plans.single.id, '12');
    expect(plans.single.title, 'Gold Plan');
    expect(plans.single.price, 'USD 9.99 / month');
    expect(plans.single.perks, 'Badge, Exclusive rooms');
  });

  test('maps alternate membership plan fields from list responses', () async {
    final RemoteMembershipRepository repository = RemoteMembershipRepository(
      apiClient: _FakeApiClient(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'monthly',
          'title': 'Monthly',
          'amount': 5,
          'currency': 'CNY',
          'interval': 'month',
          'perks': 'Creator boosts',
        },
        <String, dynamic>{
          'id': 'yearly',
          'title': 'Yearly',
          'price': '50',
          'description': 'Best value',
        },
      ]),
    );

    final plans = await repository.getPlans();

    expect(plans, hasLength(2));
    expect(plans.first.price, 'CNY 5 / month');
    expect(plans.first.perks, 'Creator boosts');
    expect(plans.last.price, '50');
    expect(plans.last.perks, 'Best value');
  });

  test('loads active current membership status from membership me endpoint',
      () async {
    final _FakeApiClient apiClient = _FakeApiClient(<String, dynamic>{
      'plan': <String, dynamic>{'name': 'Basic Monthly'},
      'status': 'active',
      'starts_at': '2026-05-01T00:00:00Z',
      'ends_at': '2026-06-01T00:00:00Z',
    });
    final RemoteMembershipRepository repository =
        RemoteMembershipRepository(apiClient: apiClient);

    final status = await repository.getCurrentStatus();

    expect(apiClient.requestedPath, Endpoints.membershipMe);
    expect(apiClient.requestedAuthenticated, isTrue);
    expect(status?.planTitle, 'Basic Monthly');
    expect(status?.status, 'active');
    expect(status?.startsAt, '2026-05-01T00:00:00Z');
    expect(status?.endsAt, '2026-06-01T00:00:00Z');
    expect(status?.isActive, isTrue);
  });

  test('maps null current membership status as no active membership', () async {
    final RemoteMembershipRepository repository = RemoteMembershipRepository(
      apiClient: _FakeApiClient(null),
    );

    final status = await repository.getCurrentStatus();

    expect(status, isNull);
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.data);

  final dynamic data;
  String? requestedPath;
  bool? requestedAuthenticated;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
  }) async {
    requestedPath = path;
    requestedAuthenticated = authenticated;
    return Response<T>(
      data: data as T,
      requestOptions: RequestOptions(path: path),
    );
  }
}
