import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/mock_cart_repository.dart';
import '../data/remote_cart_repository.dart';
import '../domain/cart_models.dart';
import '../domain/cart_repository.dart';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return RemoteCartRepository(apiClient: ref.watch(apiClientProvider));
});

/// Lightweight count used for icon badges; auto-invalidated by CartNotifier.
final cartCountProvider = FutureProvider.autoDispose<int>((ref) async {
  if (!ref.watch(authControllerProvider).isSignedIn) return 0;
  return ref.watch(cartRepositoryProvider).getCount();
});

class CartNotifier extends AsyncNotifier<List<CartItem>> {
  @override
  Future<List<CartItem>> build() async {
    if (!ref.watch(authControllerProvider).isSignedIn) {
      return const <CartItem>[];
    }
    return ref.read(cartRepositoryProvider).getItems();
  }

  Future<bool> addItem(int productId) async {
    try {
      await ref.read(cartRepositoryProvider).addItem(productId);
      ref.invalidate(cartCountProvider);
      ref.invalidateSelf();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeItem(int savedItemId) async {
    try {
      await ref.read(cartRepositoryProvider).removeItem(savedItemId);
      ref.invalidate(cartCountProvider);
      ref.invalidateSelf();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final cartNotifierProvider =
    AsyncNotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

/// For use in tests / mock mode only.
final mockCartRepositoryProvider = Provider<CartRepository>(
  (_) => MockCartRepository(),
);
