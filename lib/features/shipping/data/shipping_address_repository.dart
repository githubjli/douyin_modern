import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../features/auth/application/auth_providers.dart';
import '../domain/shipping_address.dart';

class ShippingAddressRepository {
  const ShippingAddressRepository(this._client);

  final ApiClient _client;

  // ── List ───────────────────────────────────────────────────────────────

  Future<List<ShippingAddress>> getAddresses() async {
    final response = await _client.get<dynamic>(
      Endpoints.shippingAddresses,
      authenticated: true,
    );
    final dynamic data = response.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(ShippingAddress.fromJson)
          .toList();
    }
    debugPrint('[ShippingAddress] unexpected list response: ${data.runtimeType}');
    return const <ShippingAddress>[];
  }

  // ── Create ─────────────────────────────────────────────────────────────

  Future<ShippingAddress> createAddress(ShippingAddress address) async {
    final response = await _client.post<dynamic>(
      Endpoints.shippingAddresses,
      data: address.toJson(),
      authenticated: true,
    );
    final dynamic data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid create address response');
    }
    return ShippingAddress.fromJson(data);
  }

  // ── Update ─────────────────────────────────────────────────────────────

  Future<ShippingAddress> updateAddress(int id, Map<String, dynamic> patch) async {
    final response = await _client.patch<dynamic>(
      Endpoints.shippingAddressDetail(id),
      data: patch,
      authenticated: true,
    );
    final dynamic data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid update address response');
    }
    return ShippingAddress.fromJson(data);
  }

  // ── Delete ─────────────────────────────────────────────────────────────

  Future<void> deleteAddress(int id) async {
    await _client.delete<dynamic>(
      Endpoints.shippingAddressDetail(id),
      authenticated: true,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final shippingAddressRepositoryProvider =
    Provider<ShippingAddressRepository>((ref) {
  return ShippingAddressRepository(ref.watch(apiClientProvider));
});

/// Full address list — refreshable via `ref.invalidate(shippingAddressListProvider)`.
final shippingAddressListProvider =
    FutureProvider<List<ShippingAddress>>((ref) {
  return ref.watch(shippingAddressRepositoryProvider).getAddresses();
});

/// Convenience: returns the first address marked `is_default`, or the first
/// address if none is default, or null when the list is empty.
final defaultShippingAddressProvider =
    FutureProvider<ShippingAddress?>((ref) async {
  final List<ShippingAddress> list =
      await ref.watch(shippingAddressListProvider.future);
  if (list.isEmpty) return null;
  return list.firstWhere(
    (ShippingAddress a) => a.isDefault,
    orElse: () => list.first,
  );
});
