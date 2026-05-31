import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/seller_repository.dart';
import '../domain/seller_models.dart';

final sellerRepositoryProvider = Provider<SellerRepository>((ref) {
  return SellerRepository(ref.watch(apiClientProvider));
});

/// Nullable — null means no application found (404).
/// Watches auth state so the cache resets on login/logout.
final sellerApplicationProvider =
    FutureProvider<SellerApplication?>((ref) async {
  final session = ref.watch(authControllerProvider).session;
  if (session?.isSignedIn != true) return null;
  return ref.watch(sellerRepositoryProvider).getMyApplication();
});
