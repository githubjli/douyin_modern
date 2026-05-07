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
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.data);

  final dynamic data;
  String? requestedPath;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
  }) async {
    requestedPath = path;
    return Response<T>(
      data: data as T,
      requestOptions: RequestOptions(path: path),
    );
  }
}
