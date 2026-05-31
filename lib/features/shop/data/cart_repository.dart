import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../auth/application/auth_providers.dart';
import '../domain/shop_models.dart';

class CartItem {
  const CartItem({
    required this.id,
    required this.product,
    required this.addedAt,
  });

  final int id;
  final ShopProduct product;
  final String addedAt;

  factory CartItem.fromJson(Map<String, dynamic> j) {
    final dynamic p = j['product'];
    return CartItem(
      id: j['id'] as int? ?? 0,
      product: p is Map<String, dynamic>
          ? ShopProduct.fromJson(p)
          : ShopProduct(
              id: j['product_id'] as int? ?? 0,
              name: '',
              price: '0',
              soldCount: 0,
              stock: 0,
            ),
      addedAt: j['added_at'] as String? ?? j['created_at'] as String? ?? '',
    );
  }
}

class CartRepository {
  const CartRepository(this._client);

  final ApiClient _client;

  Future<List<CartItem>> getItems() async {
    final response = await _client.get<dynamic>(
      Endpoints.cartItems,
      authenticated: true,
    );
    final dynamic raw = response.data;
    List<dynamic> items;
    if (raw is List) {
      items = raw;
    } else if (raw is Map<String, dynamic> && raw['results'] is List) {
      items = raw['results'] as List<dynamic>;
    } else {
      items = const <dynamic>[];
    }
    return items.whereType<Map<String, dynamic>>().map(CartItem.fromJson).toList();
  }

  Future<CartItem> addItem(int productId) async {
    final response = await _client.post<dynamic>(
      Endpoints.cartItems,
      data: <String, dynamic>{'product_id': productId},
      authenticated: true,
    );
    final dynamic raw = response.data;
    if (raw is! Map<String, dynamic>) throw Exception('Invalid cart response');
    return CartItem.fromJson(raw);
  }

  Future<void> removeItem(int itemId) async {
    await _client.delete<dynamic>(
      Endpoints.cartItemDetail(itemId),
      authenticated: true,
    );
  }

  Future<int> getCount() async {
    final response = await _client.get<dynamic>(
      Endpoints.cartCount,
      authenticated: true,
    );
    final dynamic raw = response.data;
    if (raw is Map<String, dynamic>) {
      return (raw['count'] as int?) ?? 0;
    }
    return 0;
  }
}

// ── Riverpod providers ────────────────────────────────────────────────────────

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(apiClientProvider));
});

/// Async provider: list of saved cart items. Refreshable.
final cartItemsProvider = FutureProvider.autoDispose<List<CartItem>>((ref) {
  return ref.watch(cartRepositoryProvider).getItems();
});

/// Async provider: total cart item count for badge display.
final cartCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(cartRepositoryProvider).getCount();
});
