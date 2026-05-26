import '../../shop/domain/shop_models.dart';

class CartItem {
  const CartItem({
    required this.id,
    required this.product,
    required this.createdAt,
  });

  final int id;
  final ShopProduct product;
  final String createdAt;
}
