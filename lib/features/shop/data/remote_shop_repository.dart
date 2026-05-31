import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../domain/shop_models.dart';
import '../domain/shop_order_models.dart';
import '../domain/shop_repository.dart';

class RemoteShopRepository implements ShopRepository {
  RemoteShopRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<ShopBanner>> getBanners() async {
    final response = await _apiClient.get<dynamic>(Endpoints.shopBanners);
    final List<dynamic> data =
        response.data is List ? response.data as List<dynamic> : const <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(_mapBanner)
        .toList();
  }

  @override
  Future<List<ShopCategory>> getCategories() async {
    final response = await _apiClient.get<dynamic>(Endpoints.shopCategories);
    final List<dynamic> data =
        response.data is List ? response.data as List<dynamic> : const <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(_mapCategory)
        .toList();
  }

  @override
  Future<ShopProductPage> getProducts({
    int page = 1,
    int pageSize = 20,
    String? category,
    String? query,
  }) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      if (category != null && category != 'all') 'category': category,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    };
    final response = await _apiClient.get<dynamic>(
      Endpoints.shopProducts,
      queryParameters: params,
    );
    final dynamic raw = response.data;
    if (raw is! Map<String, dynamic>) {
      assert(() {
        debugPrint('[Shop] unexpected products response type: ${raw.runtimeType}');
        return true;
      }());
      return ShopProductPage(items: const <ShopProduct>[], count: 0, page: page, pageSize: pageSize);
    }
    return _mapProductPage(raw, page, pageSize);
  }

  ShopBanner _mapBanner(Map<String, dynamic> m) => ShopBanner(
        id: m['id'] as int? ?? 0,
        imageUrl: m['image_url'] as String?,
        title: m['title'] as String? ?? '',
        subtitle: m['subtitle'] as String? ?? '',
        targetUrl: m['target_url'] as String? ?? '',
      );

  ShopCategory _mapCategory(Map<String, dynamic> m) => ShopCategory(
        id: m['id'] as int? ?? 0,
        name: m['name'] as String? ?? '',
        slug: m['slug'] as String? ?? '',
      );

  @override
  Future<ShopProduct> getProductDetail(int id) async {
    final response =
        await _apiClient.get<dynamic>(Endpoints.shopProductDetail(id));
    final dynamic raw = response.data;
    if (raw is! Map<String, dynamic>) {
      throw Exception('Invalid product detail response');
    }
    return _mapProduct(raw);
  }

  ShopProduct _mapProduct(Map<String, dynamic> m) {
    final dynamic cat = m['category'];
    final dynamic imgs = m['images'];
    final dynamic rawSpecs = m['specs'];
    final List<String> images = imgs is List
        ? imgs.whereType<String>().toList()
        : const <String>[];
    final List<ShopProductSpec> specs = rawSpecs is List
        ? rawSpecs
            .whereType<Map<String, dynamic>>()
            .map((Map<String, dynamic> s) => ShopProductSpec(
                  name: s['name'] as String? ?? '',
                  value: s['value'] as String? ?? '',
                ))
            .where((ShopProductSpec s) => s.name.isNotEmpty)
            .toList()
        : const <ShopProductSpec>[];
    return ShopProduct(
      id: m['id'] as int? ?? 0,
      name: m['name'] as String? ?? '',
      price: m['price'] as String? ?? '0',
      originalPrice: m['original_price'] as String?,
      thumbnailUrl: m['thumbnail_url'] as String?,
      badge: m['badge'] as String?,
      category: cat is Map<String, dynamic> ? _mapCategory(cat) : null,
      soldCount: m['sold_count'] as int? ?? 0,
      stock: m['stock'] as int? ?? 0,
      description: m['description'] as String?,
      images: images,
      specs: specs,
      meowPointsPrice: _asDecimalString(m['meow_points_price']),
      meowCreditPrice: _asDecimalString(m['meow_credit_price']),
    );
  }

  /// Safely converts a backend price value to a string.
  /// Handles String ("20.00"), double (20.0), int (20), and null.
  static String? _asDecimalString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    if (v is num) {
      if (kDebugMode) {
        debugPrint('[Shop] price field returned as num ($v) — expected String');
      }
      return v.toString();
    }
    return null;
  }

  @override
  Future<ShopOrder> createOrder({
    required int productId,
    required int quantity,
    required ShopPaymentAsset paymentAsset,
    int? shippingAddressId,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'product_id': productId,
      'quantity': quantity,
      'payment_asset': paymentAsset.apiValue,
      'shipping_address_id': shippingAddressId,
    };
    final response = await _apiClient.post<dynamic>(
      Endpoints.shopOrders,
      data: body,
      authenticated: true,
    );
    final dynamic raw = response.data;
    if (raw is! Map<String, dynamic>) {
      throw Exception('Invalid order response');
    }
    return _mapOrder(raw);
  }

  ShopOrder _mapOrder(Map<String, dynamic> m) {
    final dynamic productSnap = m['product_snapshot'];
    final String? productName = m['product_name_snapshot'] as String? ??
        m['product_title_snapshot'] as String? ??
        (productSnap is Map<String, dynamic>
            ? productSnap['name'] as String?
            : null);
    final String? productThumb = m['product_thumbnail_snapshot'] as String? ??
        (productSnap is Map<String, dynamic>
            ? productSnap['thumbnail_url'] as String?
            : null);

    final dynamic shipmentRaw = m['shipment'];
    final ShopShipment? shipment = shipmentRaw is Map<String, dynamic>
        ? ShopShipment.fromJson(shipmentRaw)
        : null;

    final dynamic refundRaw = m['refund_summary'];
    final ShopRefundSummary? refundSummary = refundRaw is Map<String, dynamic>
        ? ShopRefundSummary.fromJson(refundRaw)
        : null;

    final dynamic paymentRaw = m['payment_summary'];
    final ShopPaymentSummary? paymentSummary =
        paymentRaw is Map<String, dynamic>
            ? ShopPaymentSummary.fromJson(paymentRaw)
            : null;

    return ShopOrder(
      orderNo: m['order_no'] as String? ?? '',
      status: m['status'] as String? ?? '',
      paymentAsset: m['payment_asset'] as String? ?? '',
      unitPriceSnapshot: (m['unit_price_snapshot'] ??
              m['product_price_snapshot'] ??
              m['expected_amount'] ??
              '0')
          .toString(),
      totalAmountSnapshot:
          (m['total_amount_snapshot'] ?? m['total_amount'] ?? '0').toString(),
      platformFeeAmount: (m['platform_fee_amount'] ?? '0').toString(),
      sellerReceivableAmount:
          (m['seller_receivable_amount'] ?? '0').toString(),
      paidAt: m['paid_at'] as String?,
      shippingAddressSnapshot:
          m['shipping_address_snapshot'] is Map<String, dynamic>
              ? m['shipping_address_snapshot'] as Map<String, dynamic>
              : null,
      productNameSnapshot: productName,
      productThumbnailSnapshot: productThumb,
      quantity: m['quantity'] as int? ?? 1,
      createdAt: m['created_at'] as String?,
      updatedAt: m['updated_at'] as String?,
      expiresAt: m['expires_at'] as String?,
      shipment: shipment,
      refundSummary: refundSummary,
      paymentSummary: paymentSummary,
    );
  }

  @override
  Future<List<ShopOrder>> getOrders({int page = 1, int pageSize = 20}) async {
    final response = await _apiClient.get<dynamic>(
      Endpoints.shopOrders,
      queryParameters: <String, dynamic>{'page': page, 'page_size': pageSize},
      authenticated: true,
    );
    final dynamic raw = response.data;
    // Support both paginated {results: [...]} and plain list responses
    List<dynamic> items;
    if (raw is Map<String, dynamic> && raw['results'] is List) {
      items = raw['results'] as List<dynamic>;
    } else if (raw is List) {
      items = raw;
    } else {
      items = const <dynamic>[];
    }
    return items.whereType<Map<String, dynamic>>().map(_mapOrder).toList();
  }

  @override
  Future<ShopOrder> getOrderDetail(String orderNo) async {
    final response = await _apiClient.get<dynamic>(
      Endpoints.shopOrderDetail(orderNo),
      authenticated: true,
    );
    final dynamic raw = response.data;
    if (raw is! Map<String, dynamic>) throw Exception('Invalid order detail response');
    return _mapOrder(raw);
  }

  @override
  Future<ShopOrder> confirmReceived(String orderNo) async {
    final response = await _apiClient.post<dynamic>(
      Endpoints.shopOrderConfirmReceived(orderNo),
      authenticated: true,
    );
    final dynamic raw = response.data;
    if (raw is! Map<String, dynamic>) throw Exception('Invalid confirm-received response');
    return _mapOrder(raw);
  }

  @override
  Future<void> requestRefund({
    required String orderNo,
    required String reason,
    required String requestedAmount,
  }) async {
    await _apiClient.post<dynamic>(
      Endpoints.shopOrderRefundRequests(orderNo),
      data: <String, dynamic>{
        'reason': reason,
        'requested_amount': requestedAmount,
      },
      authenticated: true,
    );
  }

  ShopProductPage _mapProductPage(Map<String, dynamic> m, int page, int pageSize) {
    final List<dynamic> results =
        m['results'] is List ? m['results'] as List<dynamic> : const <dynamic>[];
    return ShopProductPage(
      items: results.whereType<Map<String, dynamic>>().map(_mapProduct).toList(),
      count: m['count'] as int? ?? 0,
      page: m['page'] as int? ?? page,
      pageSize: m['page_size'] as int? ?? pageSize,
    );
  }
}
