enum ShopPaymentAsset { meowPoints, meowCredit }

extension ShopPaymentAssetX on ShopPaymentAsset {
  String get apiValue =>
      this == ShopPaymentAsset.meowPoints ? 'meow_points' : 'meow_credit';

  String get displayName =>
      this == ShopPaymentAsset.meowPoints ? 'MeowPoints' : 'MeowCredit';
}

class ShopShipment {
  const ShopShipment({
    required this.carrier,
    required this.trackingNumber,
    this.trackingUrl,
    this.shippedNote,
    this.shippedAt,
  });

  final String carrier;
  final String trackingNumber;
  final String? trackingUrl;
  final String? shippedNote;
  final String? shippedAt;

  factory ShopShipment.fromJson(Map<String, dynamic> j) => ShopShipment(
        carrier: j['carrier'] as String? ?? '',
        trackingNumber: j['tracking_number'] as String? ?? '',
        trackingUrl: j['tracking_url'] as String?,
        shippedNote: j['shipped_note'] as String?,
        shippedAt: j['shipped_at'] as String?,
      );
}

class ShopRefundSummary {
  const ShopRefundSummary({
    required this.activeRefundRequestExists,
    this.latestRefundRequest,
  });

  final bool activeRefundRequestExists;
  final Map<String, dynamic>? latestRefundRequest;

  factory ShopRefundSummary.fromJson(Map<String, dynamic> j) =>
      ShopRefundSummary(
        activeRefundRequestExists:
            j['active_refund_request_exists'] as bool? ?? false,
        latestRefundRequest:
            j['latest_refund_request'] as Map<String, dynamic>?,
      );
}

class ShopPaymentSummary {
  const ShopPaymentSummary({
    required this.status,
    this.amount,
    this.currency,
    this.txid,
  });

  final String status;
  final String? amount;
  final String? currency;
  final String? txid;

  factory ShopPaymentSummary.fromJson(Map<String, dynamic> j) =>
      ShopPaymentSummary(
        status: j['status'] as String? ?? '',
        amount: j['amount'] as String?,
        currency: j['currency'] as String?,
        txid: j['txid'] as String?,
      );
}

class ShopOrder {
  const ShopOrder({
    required this.orderNo,
    required this.status,
    required this.paymentAsset,
    required this.unitPriceSnapshot,
    required this.totalAmountSnapshot,
    required this.platformFeeAmount,
    required this.sellerReceivableAmount,
    this.paidAt,
    this.shippingAddressSnapshot,
    this.productNameSnapshot,
    this.productThumbnailSnapshot,
    this.quantity = 1,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
    this.shipment,
    this.refundSummary,
    this.paymentSummary,
  });

  final String orderNo;
  final String status;
  final String paymentAsset;
  final String unitPriceSnapshot;
  final String totalAmountSnapshot;
  final String platformFeeAmount;
  final String sellerReceivableAmount;
  final String? paidAt;
  final String? createdAt;
  final String? updatedAt;
  final String? expiresAt;

  final Map<String, dynamic>? shippingAddressSnapshot;
  final String? productNameSnapshot;
  final String? productThumbnailSnapshot;
  final int quantity;

  final ShopShipment? shipment;
  final ShopRefundSummary? refundSummary;
  final ShopPaymentSummary? paymentSummary;

  String get statusText => switch (status) {
        'pending_payment' || 'pending' => 'Pending payment',
        'paid' => 'Paid, waiting for shipment',
        'shipping' => 'Shipped, waiting for receipt',
        'completed' || 'settled' => 'Completed',
        'cancelled' => 'Cancelled',
        _ => status,
      };

  String get paymentAssetDisplay => switch (paymentAsset) {
        'meow_points' => 'MeowPoints',
        'meow_credit' => 'MeowCredit',
        _ => paymentAsset,
      };

  bool get canConfirmReceived => status == 'shipping';
  bool get canRequestRefund =>
      (status == 'paid' || status == 'shipping' || status == 'completed') &&
      (refundSummary?.activeRefundRequestExists != true);

  String? get shippingAddressLine {
    final Map<String, dynamic>? snap = shippingAddressSnapshot;
    if (snap == null || snap.isEmpty) return null;
    final List<String> parts = <String>[
      if ((snap['address_line1'] as String?)?.isNotEmpty == true)
        snap['address_line1'] as String,
      if ((snap['address_line2'] as String?)?.isNotEmpty == true)
        snap['address_line2'] as String,
      if ((snap['district'] as String?)?.isNotEmpty == true)
        snap['district'] as String,
      if ((snap['city'] as String?)?.isNotEmpty == true)
        snap['city'] as String,
      if ((snap['state'] as String?)?.isNotEmpty == true)
        snap['state'] as String,
      if ((snap['postal_code'] as String?)?.isNotEmpty == true)
        snap['postal_code'] as String,
      if ((snap['country'] as String?)?.isNotEmpty == true)
        snap['country'] as String,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  String? get shippingReceiverName =>
      shippingAddressSnapshot?['receiver_name'] as String?;
}
