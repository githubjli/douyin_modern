import '../domain/shop_models.dart';
import '../domain/shop_repository.dart';

class MockShopRepository implements ShopRepository {
  const MockShopRepository();

  static const List<ShopBanner> _banners = <ShopBanner>[
    ShopBanner(
      id: 1,
      title: 'Summer Sale',
      subtitle: 'Up to 50% off selected items',
      targetUrl: '',
    ),
    ShopBanner(
      id: 2,
      title: 'New Arrivals',
      subtitle: 'Fresh products just landed',
      targetUrl: '',
    ),
    ShopBanner(
      id: 3,
      title: 'Members Only',
      subtitle: 'Exclusive deals for VIP members',
      targetUrl: '',
    ),
  ];

  static const List<ShopCategory> _categories = <ShopCategory>[
    ShopCategory(id: 0, name: 'All', slug: 'all'),
    ShopCategory(id: 1, name: 'Food', slug: 'food'),
    ShopCategory(id: 2, name: 'Drink', slug: 'drink'),
    ShopCategory(id: 3, name: 'Beauty', slug: 'beauty'),
    ShopCategory(id: 4, name: 'Electronics', slug: 'electronics'),
  ];

  static const List<ShopProduct> _products = <ShopProduct>[
    ShopProduct(
      id: 1001,
      name: 'Orange Juice 1L',
      price: '12.00',
      originalPrice: '15.00',
      badge: 'HOT',
      category: ShopCategory(id: 2, name: 'Drink', slug: 'drink'),
      soldCount: 120,
      stock: 55,
    ),
    ShopProduct(
      id: 1002,
      name: 'Apple Juice 500ml',
      price: '9.90',
      category: ShopCategory(id: 2, name: 'Drink', slug: 'drink'),
      soldCount: 43,
      stock: 8,
    ),
    ShopProduct(
      id: 1003,
      name: 'Instant Noodles Pack x5',
      price: '6.50',
      originalPrice: '8.00',
      badge: 'NEW',
      category: ShopCategory(id: 1, name: 'Food', slug: 'food'),
      soldCount: 210,
      stock: 200,
    ),
    ShopProduct(
      id: 1004,
      name: 'Green Tea 350ml',
      price: '4.50',
      category: ShopCategory(id: 2, name: 'Drink', slug: 'drink'),
      soldCount: 88,
      stock: 30,
    ),
    ShopProduct(
      id: 1005,
      name: 'Wireless Earbuds',
      price: '49.00',
      originalPrice: '79.00',
      badge: 'SALE',
      category: ShopCategory(id: 4, name: 'Electronics', slug: 'electronics'),
      soldCount: 512,
      stock: 12,
    ),
    ShopProduct(
      id: 1006,
      name: 'Moisturising Cream 50ml',
      price: '22.00',
      category: ShopCategory(id: 3, name: 'Beauty', slug: 'beauty'),
      soldCount: 67,
      stock: 40,
    ),
    ShopProduct(
      id: 1007,
      name: 'Chocolate Snack Bar x3',
      price: '7.80',
      originalPrice: '9.00',
      category: ShopCategory(id: 1, name: 'Food', slug: 'food'),
      soldCount: 155,
      stock: 100,
    ),
    ShopProduct(
      id: 1008,
      name: 'Phone Stand Desk Mount',
      price: '15.00',
      badge: 'NEW',
      category: ShopCategory(id: 4, name: 'Electronics', slug: 'electronics'),
      soldCount: 29,
      stock: 60,
    ),
  ];

  @override
  Future<List<ShopBanner>> getBanners() async => _banners;

  @override
  Future<List<ShopCategory>> getCategories() async => _categories;

  @override
  Future<ShopProductPage> getProducts({
    int page = 1,
    int pageSize = 20,
    String? category,
    String? query,
  }) async {
    List<ShopProduct> filtered = _products;

    if (category != null && category != 'all') {
      filtered = filtered
          .where((ShopProduct p) => p.category?.slug == category)
          .toList();
    }

    if (query != null && query.trim().isNotEmpty) {
      final String q = query.trim().toLowerCase();
      filtered = filtered
          .where((ShopProduct p) => p.name.toLowerCase().contains(q))
          .toList();
    }

    final int start = (page - 1) * pageSize;
    final List<ShopProduct> paged = start >= filtered.length
        ? const <ShopProduct>[]
        : filtered.sublist(start, (start + pageSize).clamp(0, filtered.length));

    return ShopProductPage(
      items: paged,
      count: filtered.length,
      page: page,
      pageSize: pageSize,
    );
  }
}
