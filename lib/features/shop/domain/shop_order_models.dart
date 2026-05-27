enum ShopPaymentAsset { meowPoints, meowCredit }

extension ShopPaymentAssetX on ShopPaymentAsset {
  String get apiValue =>
      this == ShopPaymentAsset.meowPoints ? 'meow_points' : 'meow_credit';

  String get displayName =>
      this == ShopPaymentAsset.meowPoints ? 'MeowPoints' : 'MeowCredit';
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
  });

  final String orderNo;
  final String status;
  final String paymentAsset;
  final String unitPriceSnapshot;
  final String totalAmountSnapshot;
  final String platformFeeAmount;
  final String sellerReceivableAmount;
  final String? paidAt;

  /// Raw snapshot of the shipping address at order time (may be empty map
  /// when no address was provided).
  final Map<String, dynamic>? shippingAddressSnapshot;

  String get statusText => switch (status) {
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

  /// Product name captured at order time (may come from product_name_snapshot
  /// or a nested product object — whichever the API provides).
  final String? productNameSnapshot;

  /// Product thumbnail at order time.
  final String? productThumbnailSnapshot;

  /// Number of units ordered.
  final int quantity;

  /// ISO-8601 creation timestamp.
  final String? createdAt;

  /// Human-readable shipping address from the snapshot, or null if not set.
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
