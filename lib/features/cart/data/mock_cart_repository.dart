import '../../shop/domain/shop_models.dart';
import '../domain/cart_models.dart';
import '../domain/cart_repository.dart';

class MockCartRepository implements CartRepository {
  MockCartRepository();

  final List<CartItem> _items = <CartItem>[
    const CartItem(
      id: 1,
      product: ShopProduct(
        id: 1001,
        name: 'Orange Juice 1L',
        price: '12.00',
        soldCount: 120,
        stock: 55,
        badge: 'HOT',
        meowPointsPrice: '1200',
        meowCreditPrice: '12',
      ),
      createdAt: '2026-05-25T10:00:00Z',
    ),
    const CartItem(
      id: 2,
      product: ShopProduct(
        id: 1005,
        name: 'Wireless Earbuds',
        price: '49.00',
        soldCount: 512,
        stock: 12,
        badge: 'SALE',
        meowPointsPrice: '4900',
        meowCreditPrice: '49',
      ),
      createdAt: '2026-05-26T08:30:00Z',
    ),
  ];

  int _nextId = 3;

  @override
  Future<int> getCount() async => _items.length;

  @override
  Future<List<CartItem>> getItems() async =>
      List<CartItem>.unmodifiable(_items);

  @override
  Future<CartItem> addItem(int productId) async {
    final CartItem? existing = _items
        .where((CartItem i) => i.product.id == productId)
        .firstOrNull;
    if (existing != null) return existing;
    final CartItem item = CartItem(
      id: _nextId++,
      product: ShopProduct(
        id: productId,
        name: 'Product #$productId',
        price: '0',
        soldCount: 0,
        stock: 10,
      ),
      createdAt: DateTime.now().toIso8601String(),
    );
    _items.add(item);
    return item;
  }

  @override
  Future<void> removeItem(int savedItemId) async {
    _items.removeWhere((CartItem i) => i.id == savedItemId);
  }
}
