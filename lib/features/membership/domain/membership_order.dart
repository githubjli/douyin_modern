class MembershipOrder {
  const MembershipOrder({
    required this.orderNo,
    required this.status,
    this.planCode,
    this.planTitle,
    this.expectedAmountLbc,
    this.actualAmountLbc,
    this.currency,
    this.payToAddress,
    this.txid,
    this.confirmations,
    this.expiresAt,
    this.paidAt,
    this.createdAt,
  });

  factory MembershipOrder.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = _orderMap(json);
    final String? orderNo = _firstString(data, const <String>[
      'order_no',
      'orderNo',
      'id',
    ]);
    final String? status = _string(data['status']);
    if (orderNo == null || status == null) {
      throw const FormatException('Invalid membership order response');
    }

    final dynamic plan = data['plan'];
    return MembershipOrder(
      orderNo: orderNo,
      status: status,
      planCode: _firstString(data, const <String>['plan_code', 'planCode']) ??
          _nestedString(plan, const <String>['code', 'slug']),
      planTitle: _firstString(data, const <String>['plan_title', 'planTitle']) ??
          _nestedString(plan, const <String>['title', 'name']) ??
          _firstString(data, const <String>['plan_code', 'planCode']),
      expectedAmountLbc: _firstString(data, const <String>[
        'expected_amount_lbc',
        'expectedAmountLbc',
        'expected_amount',
        'amount',
      ]),
      actualAmountLbc: _firstString(data, const <String>[
        'actual_amount_lbc',
        'actualAmountLbc',
        'actual_amount',
      ]),
      currency: _firstString(data, const <String>[
            'currency',
            'price_currency',
          ]) ??
          'LBC',
      payToAddress: _firstString(data, const <String>[
        'pay_to_address',
        'payToAddress',
        'address',
      ]),
      txid: _string(data['txid']),
      confirmations: _int(data['confirmations']),
      expiresAt: _firstString(data, const <String>['expires_at', 'expiresAt']),
      paidAt: _firstString(data, const <String>['paid_at', 'paidAt']),
      createdAt: _firstString(data, const <String>['created_at', 'createdAt']),
    );
  }

  final String orderNo;
  final String status;
  final String? planCode;
  final String? planTitle;
  final String? expectedAmountLbc;
  final String? actualAmountLbc;
  final String? currency;
  final String? payToAddress;
  final String? txid;
  final int? confirmations;
  final String? expiresAt;
  final String? paidAt;
  final String? createdAt;

  bool get isPending {
    return _normalizedStatus == 'pending' ||
        _normalizedStatus == 'created' ||
        _normalizedStatus == 'awaiting_payment';
  }

  bool get isPaid => _normalizedStatus == 'paid';

  bool get isExpired => _normalizedStatus == 'expired';

  bool get isUnderpaid => _normalizedStatus == 'underpaid';

  bool get isOverpaid => _normalizedStatus == 'overpaid';

  bool get isSuccessLike {
    return isPaid || isOverpaid || _normalizedStatus == 'paid_after_expiry';
  }

  String get _normalizedStatus => status.toLowerCase().trim();
}

Map<String, dynamic> _orderMap(Map<String, dynamic> json) {
  final dynamic order = json['order'];
  if (order is Map<String, dynamic>) return order;
  return json;
}

String? _firstString(Map<String, dynamic> data, List<String> keys) {
  for (final String key in keys) {
    final String? value = _string(data[key]);
    if (value != null) return value;
  }
  return null;
}

String? _nestedString(dynamic value, List<String> keys) {
  if (value is! Map<String, dynamic>) return null;
  return _firstString(value, keys);
}

String? _string(dynamic value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  if (value is num) return value.toString();
  return null;
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value.trim());
  return null;
}
