import 'cart_models.dart';

abstract class CartRepository {
  Future<int> getCount();
  Future<List<CartItem>> getItems();
  Future<CartItem> addItem(int productId);
  Future<void> removeItem(int savedItemId);
}
