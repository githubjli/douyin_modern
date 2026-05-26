import 'shop_models.dart';

abstract class ShopRepository {
  Future<List<ShopBanner>> getBanners();
  Future<List<ShopCategory>> getCategories();
  Future<ShopProductPage> getProducts({
    int page = 1,
    int pageSize = 20,
    String? category,
    String? query,
  });
}
