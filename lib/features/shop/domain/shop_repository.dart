import 'shop_models.dart';
import 'shop_order_models.dart';

abstract class ShopRepository {
  Future<List<ShopBanner>> getBanners();
  Future<List<ShopCategory>> getCategories();
  Future<ShopProductPage> getProducts({
    int page = 1,
    int pageSize = 20,
    String? category,
    String? query,
  });
  Future<ShopProduct> getProductDetail(int id);
  Future<ShopOrder> createOrder({
    required int productId,
    required int quantity,
    required ShopPaymentAsset paymentAsset,
    int? shippingAddressId,
  });

  Future<List<ShopOrder>> getOrders({int page = 1, int pageSize = 20});
}
