import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_dependency_providers.dart';
import '../data/seller_repository.dart';
import '../domain/seller_models.dart';

final sellerRepositoryProvider = Provider<SellerRepository>((ref) {
  return SellerRepository(ref.watch(apiClientProvider));
});

/// Nullable — null means no application found (404).
final sellerApplicationProvider =
    FutureProvider<SellerApplication?>((ref) async {
  return ref.watch(sellerRepositoryProvider).getMyApplication();
});
