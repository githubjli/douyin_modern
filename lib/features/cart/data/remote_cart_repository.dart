import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../shop/domain/shop_models.dart';
import '../domain/cart_models.dart';
import '../domain/cart_repository.dart';

class RemoteCartRepository implements CartRepository {
  RemoteCartRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<int> getCount() async {
    final response = await _apiClient.get<dynamic>(
      Endpoints.cartCount,
      authenticated: true,
    );
    final dynamic data = response.data;
    if (data is Map<String, dynamic>) {
      return data['count'] as int? ?? 0;
    }
    return 0;
  }

  @override
  Future<List<CartItem>> getItems() async {
    final response = await _apiClient.get<dynamic>(
      Endpoints.cartItems,
      authenticated: true,
    );
    final dynamic data = response.data;
    if (data is! Map<String, dynamic>) return const <CartItem>[];
    final dynamic results = data['results'];
    if (results is! List) return const <CartItem>[];
    return results.whereType<Map<String, dynamic>>().map(_mapItem).toList();
  }

  @override
  Future<CartItem> addItem(int productId) async {
    final response = await _apiClient.post<dynamic>(
      Endpoints.cartItems,
      data: <String, dynamic>{'product_id': productId},
      authenticated: true,
    );
    final dynamic data = response.data;
    if (data is! Map<String, dynamic>) throw Exception('Invalid cart response');
    return _mapItem(data);
  }

  @override
  Future<void> removeItem(int savedItemId) async {
    await _apiClient.delete<dynamic>(
      Endpoints.cartItemDelete(savedItemId),
      authenticated: true,
    );
  }

  CartItem _mapItem(Map<String, dynamic> m) {
    final dynamic p = m['product'];
    return CartItem(
      id: m['id'] as int? ?? 0,
      product: p is Map<String, dynamic> ? _mapProduct(p) : _kEmptyProduct,
      createdAt: m['created_at'] as String? ?? '',
    );
  }

  ShopProduct _mapProduct(Map<String, dynamic> m) {
    final dynamic cat = m['category'];
    return ShopProduct(
      id: m['id'] as int? ?? 0,
      name: m['name'] as String? ?? '',
      price: m['price'] as String? ?? '0',
      originalPrice: m['original_price'] as String?,
      thumbnailUrl: m['thumbnail_url'] as String?,
      badge: m['badge'] as String?,
      category: cat is Map<String, dynamic>
          ? ShopCategory(
              id: cat['id'] as int? ?? 0,
              name: cat['name'] as String? ?? '',
              slug: cat['slug'] as String? ?? '',
            )
          : null,
      soldCount: m['sold_count'] as int? ?? 0,
      stock: m['stock'] as int? ?? 0,
      meowPointsPrice: m['meow_points_price'] as String?,
      meowCreditPrice: m['meow_credit_price'] as String?,
    );
  }
}

const ShopProduct _kEmptyProduct = ShopProduct(
  id: 0,
  name: '',
  price: '0',
  soldCount: 0,
  stock: 0,
);
