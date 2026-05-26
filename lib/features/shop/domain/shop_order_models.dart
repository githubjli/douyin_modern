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
  });

  final String orderNo;
  final String status;
  final String paymentAsset;
  final String unitPriceSnapshot;
  final String totalAmountSnapshot;
  final String platformFeeAmount;
  final String sellerReceivableAmount;
  final String? paidAt;

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
}
