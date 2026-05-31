import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../domain/seller_models.dart';

class SellerRepository {
  const SellerRepository(this._client);

  final ApiClient _client;

  // ── Seller Application ────────────────────────────────────────────────────

  /// Returns null when the user has no application (404).
  Future<SellerApplication?> getMyApplication() async {
    try {
      final response = await _client.get<dynamic>(
        Endpoints.sellerApplicationMe,
        authenticated: true,
      );
      final dynamic raw = response.data;
      if (raw is! Map<String, dynamic>) return null;
      return SellerApplication.fromJson(raw);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<SellerApplication> submitApplication({
    required String storeName,
    required String businessType,
    required String businessDescription,
    required String contactPhone,
    required String contactEmail,
    String? businessLicenseUrl,
  }) async {
    final response = await _client.post<dynamic>(
      Endpoints.sellerApplications,
      data: <String, dynamic>{
        'store_name': storeName,
        'business_type': businessType,
        'business_description': businessDescription,
        'contact_phone': contactPhone,
        'contact_email': contactEmail,
        'business_license_url': businessLicenseUrl ?? '',
      },
      authenticated: true,
    );
    final dynamic raw = response.data;
    if (raw is! Map<String, dynamic>) throw Exception('Invalid response');
    return SellerApplication.fromJson(raw);
  }

  // ── Store ──────────────────────────────────────────────────────────────────

  Future<SellerStore> getStore() async {
    final response = await _client.get<dynamic>(
      Endpoints.sellerStoreMe,
      authenticated: true,
    );
    final dynamic raw = response.data;
    if (raw is! Map<String, dynamic>) throw Exception('Invalid store response');
    return SellerStore.fromJson(raw);
  }

  Future<SellerStore> createStore(Map<String, dynamic> body) async {
    final response = await _client.post<dynamic>(
      Endpoints.sellerStoreMe,
      data: body,
      authenticated: true,
    );
    final dynamic raw = response.data;
    if (raw is! Map<String, dynamic>) throw Exception('Invalid store response');
    return SellerStore.fromJson(raw);
  }

  Future<SellerStore> updateStore(Map<String, dynamic> patch) async {
    final response = await _client.patch<dynamic>(
      Endpoints.sellerStoreMe,
      data: patch,
      authenticated: true,
    );
    final dynamic raw = response.data;
    if (raw is! Map<String, dynamic>) throw Exception('Invalid store response');
    return SellerStore.fromJson(raw);
  }

  // ── Products ───────────────────────────────────────────────────────────────

  Future<List<SellerProduct>> getProducts() async {
    final response = await _client.get<dynamic>(
      Endpoints.sellerProducts,
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
    return items
        .whereType<Map<String, dynamic>>()
        .map(SellerProduct.fromJson)
        .toList();
  }

  Future<SellerProduct> createProduct(Map<String, dynamic> body) async {
    final response = await _client.post<dynamic>(
      Endpoints.sellerProducts,
      data: body,
      authenticated: true,
    );
    final dynamic raw = response.data;
    if (raw is! Map<String, dynamic>) throw Exception('Invalid product response');
    return SellerProduct.fromJson(raw);
  }

  Future<SellerProduct> updateProduct(int id, Map<String, dynamic> patch) async {
    final response = await _client.patch<dynamic>(
      Endpoints.sellerProductDetail(id),
      data: patch,
      authenticated: true,
    );
    final dynamic raw = response.data;
    if (raw is! Map<String, dynamic>) throw Exception('Invalid product response');
    return SellerProduct.fromJson(raw);
  }

  Future<void> deleteProduct(int id) async {
    await _client.delete<dynamic>(
      Endpoints.sellerProductDetail(id),
      authenticated: true,
    );
  }

  // ── Orders ─────────────────────────────────────────────────────────────────

  Future<List<SellerOrder>> getOrders({String? status}) async {
    final Map<String, dynamic> params = <String, dynamic>{
      if (status != null && status != 'all') 'status': status,
    };
    final response = await _client.get<dynamic>(
      Endpoints.sellerOrders,
      queryParameters: params.isEmpty ? null : params,
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
    return items
        .whereType<Map<String, dynamic>>()
        .map(SellerOrder.fromJson)
        .toList();
  }

  Future<SellerOrder> getOrderDetail(String orderNo) async {
    final response = await _client.get<dynamic>(
      Endpoints.sellerOrderDetail(orderNo),
      authenticated: true,
    );
    final dynamic raw = response.data;
    if (raw is! Map<String, dynamic>) throw Exception('Invalid order detail response');
    return SellerOrder.fromJson(raw);
  }

  Future<SellerOrder> shipOrder({
    required String orderNo,
    required String carrier,
    required String trackingNumber,
    String? trackingUrl,
    String? shippedNote,
  }) async {
    final response = await _client.post<dynamic>(
      Endpoints.sellerOrderShip(orderNo),
      data: <String, dynamic>{
        'carrier': carrier,
        'tracking_number': trackingNumber,
        if (trackingUrl != null) 'tracking_url': trackingUrl,
        if (shippedNote != null) 'shipped_note': shippedNote,
      },
      authenticated: true,
    );
    final dynamic raw = response.data;
    if (raw is! Map<String, dynamic>) throw Exception('Invalid ship response');
    return SellerOrder.fromJson(raw);
  }
}
