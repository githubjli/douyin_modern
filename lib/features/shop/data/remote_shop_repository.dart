import 'package:flutter/foundation.dart';

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
      meowPointsPrice: m['meow_points_price'] as String?,
      meowCreditPrice: m['meow_credit_price'] as String?,
    );
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
      if (shippingAddressId != null) 'shipping_address_id': shippingAddressId,
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

  ShopOrder _mapOrder(Map<String, dynamic> m) => ShopOrder(
        orderNo: m['order_no'] as String? ?? '',
        status: m['status'] as String? ?? '',
        paymentAsset: m['payment_asset'] as String? ?? '',
        unitPriceSnapshot: m['unit_price_snapshot'] as String? ?? '0',
        totalAmountSnapshot: m['total_amount_snapshot'] as String? ?? '0',
        platformFeeAmount: m['platform_fee_amount'] as String? ?? '0',
        sellerReceivableAmount: m['seller_receivable_amount'] as String? ?? '0',
        paidAt: m['paid_at'] as String?,
      );

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
