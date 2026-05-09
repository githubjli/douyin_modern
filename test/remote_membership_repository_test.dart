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
    expect(plans.single.code, '12');
    expect(plans.single.title, 'Gold Plan');
    expect(plans.single.price, 'USD 9.99 / month');
    expect(plans.single.perks, 'Badge, Exclusive rooms');
  });

  test('maps alternate membership plan fields from list responses', () async {
    final RemoteMembershipRepository repository = RemoteMembershipRepository(
      apiClient: _FakeApiClient(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'monthly-id',
          'code': 'monthly-code',
          'title': 'Monthly',
          'amount': 5,
          'currency': 'CNY',
          'interval': 'month',
          'perks': 'Creator boosts',
        },
        <String, dynamic>{
          'id': 'quarterly-id',
          'plan_code': 'quarterly-code',
          'title': 'Quarterly',
          'price': '15',
          'description': 'Popular',
        },
        <String, dynamic>{
          'id': 'yearly-id',
          'slug': 'yearly-slug',
          'title': 'Yearly',
          'price': '50',
          'description': 'Best value',
        },
        <String, dynamic>{
          'id': 'fallback-id',
          'title': 'Fallback',
          'price': '5',
          'description': 'Fallback code',
        },
      ]),
    );

    final plans = await repository.getPlans();

    expect(plans, hasLength(4));
    expect(plans[0].code, 'monthly-code');
    expect(plans[1].code, 'quarterly-code');
    expect(plans[2].code, 'yearly-slug');
    expect(plans[3].code, 'fallback-id');
    expect(plans.first.price, 'CNY 5 / month');
    expect(plans.first.perks, 'Creator boosts');
    expect(plans[2].price, '50');
    expect(plans[2].perks, 'Best value');
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

  test('createOrder posts plan_code and maps membership order', () async {
    final _FakeApiClient apiClient = _FakeApiClient(<String, dynamic>{
      'order_no': 'ord-1',
      'status': 'pending',
      'plan_code': 'monthly',
      'plan_title': 'Monthly',
      'expected_amount_lbc': '10.5',
      'currency': 'LBC',
      'pay_to_address': 'lbc-address',
      'expires_at': '2026-05-10T00:00:00Z',
    });
    final RemoteMembershipRepository repository =
        RemoteMembershipRepository(apiClient: apiClient);

    final order = await repository.createOrder(planCode: 'monthly');

    expect(apiClient.requestedPath, Endpoints.membershipOrders);
    expect(apiClient.requestedAuthenticated, isTrue);
    expect(apiClient.requestedData, <String, dynamic>{'plan_code': 'monthly'});
    expect(order.orderNo, 'ord-1');
    expect(order.status, 'pending');
    expect(order.planCode, 'monthly');
    expect(order.planTitle, 'Monthly');
    expect(order.expectedAmountLbc, '10.5');
    expect(order.currency, 'LBC');
    expect(order.payToAddress, 'lbc-address');
    expect(order.expiresAt, '2026-05-10T00:00:00Z');
    expect(order.isPending, isTrue);
  });

  test('getOrder authenticates and maps payment fields', () async {
    final _FakeApiClient apiClient = _FakeApiClient(<String, dynamic>{
      'order_no': 'ord-2',
      'status': 'paid',
      'expected_amount_lbc': 12,
      'actual_amount_lbc': '12.1',
      'pay_to_address': 'lbc-pay',
      'txid': 'tx-1',
      'confirmations': '3',
      'expires_at': '2026-05-10T00:00:00Z',
      'paid_at': '2026-05-09T00:00:00Z',
      'created_at': '2026-05-08T00:00:00Z',
    });
    final RemoteMembershipRepository repository =
        RemoteMembershipRepository(apiClient: apiClient);

    final order = await repository.getOrder('ord-2');

    expect(apiClient.requestedPath, Endpoints.membershipOrderDetail('ord-2'));
    expect(apiClient.requestedAuthenticated, isTrue);
    expect(order.orderNo, 'ord-2');
    expect(order.status, 'paid');
    expect(order.expectedAmountLbc, '12');
    expect(order.actualAmountLbc, '12.1');
    expect(order.payToAddress, 'lbc-pay');
    expect(order.txid, 'tx-1');
    expect(order.confirmations, 3);
    expect(order.expiresAt, '2026-05-10T00:00:00Z');
    expect(order.paidAt, '2026-05-09T00:00:00Z');
    expect(order.createdAt, '2026-05-08T00:00:00Z');
    expect(order.isPaid, isTrue);
    expect(order.isSuccessLike, isTrue);
  });

  test('submitTxHint posts txid and maps nested order response', () async {
    final _FakeApiClient apiClient = _FakeApiClient(<String, dynamic>{
      'order': <String, dynamic>{
        'order_no': 'ord-3',
        'status': 'underpaid',
        'plan': <String, dynamic>{
          'code': 'monthly',
          'title': 'Monthly',
        },
        'actual_amount_lbc': '8',
        'txid': 'tx-3',
      },
    });
    final RemoteMembershipRepository repository =
        RemoteMembershipRepository(apiClient: apiClient);

    final order = await repository.submitTxHint(
      orderNo: 'ord-3',
      txid: 'tx-3',
    );

    expect(apiClient.requestedPath, Endpoints.membershipOrderTxHint('ord-3'));
    expect(apiClient.requestedAuthenticated, isTrue);
    expect(apiClient.requestedData, <String, dynamic>{'txid': 'tx-3'});
    expect(order.orderNo, 'ord-3');
    expect(order.planCode, 'monthly');
    expect(order.planTitle, 'Monthly');
    expect(order.txid, 'tx-3');
    expect(order.isUnderpaid, isTrue);
  });

  test('verifyNow posts authenticated request and maps order response', () async {
    final _FakeApiClient apiClient = _FakeApiClient(<String, dynamic>{
      'orderNo': 'ord-4',
      'status': 'overpaid',
      'planCode': 'yearly',
      'expectedAmountLbc': '100',
      'actualAmountLbc': '101',
      'payToAddress': 'lbc-pay',
    });
    final RemoteMembershipRepository repository =
        RemoteMembershipRepository(apiClient: apiClient);

    final order = await repository.verifyNow('ord-4');

    expect(apiClient.requestedPath, Endpoints.membershipOrderVerifyNow('ord-4'));
    expect(apiClient.requestedAuthenticated, isTrue);
    expect(apiClient.requestedData, isNull);
    expect(order.orderNo, 'ord-4');
    expect(order.planCode, 'yearly');
    expect(order.expectedAmountLbc, '100');
    expect(order.actualAmountLbc, '101');
    expect(order.payToAddress, 'lbc-pay');
    expect(order.isOverpaid, isTrue);
    expect(order.isSuccessLike, isTrue);
  });

  test('malformed order response throws FormatException', () async {
    final RemoteMembershipRepository repository = RemoteMembershipRepository(
      apiClient: _FakeApiClient(<String, dynamic>{
        'verification': <String, dynamic>{'result': 'queued'},
      }),
    );

    expect(
      () => repository.verifyNow('ord-5'),
      throwsA(isA<FormatException>()),
    );
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.data);

  final dynamic data;
  String? requestedPath;
  bool? requestedAuthenticated;
  Object? requestedData;

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

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
  }) async {
    requestedPath = path;
    requestedData = data;
    requestedAuthenticated = authenticated;
    return Response<T>(
      data: this.data as T,
      requestOptions: RequestOptions(path: path),
    );
  }
}
