class ShopBanner {
  const ShopBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.targetUrl,
    this.imageUrl,
  });

  final int id;
  final String? imageUrl;
  final String title;
  final String subtitle;
  final String targetUrl;
}

class ShopCategory {
  const ShopCategory({
    required this.id,
    required this.name,
    required this.slug,
  });

  final int id;
  final String name;
  final String slug;
}

class ShopProduct {
  const ShopProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.soldCount,
    required this.stock,
    this.originalPrice,
    this.thumbnailUrl,
    this.badge,
    this.category,
    this.description,
    this.images = const <String>[],
  });

  final int id;
  final String name;
  final String price;
  final String? originalPrice;
  final String? thumbnailUrl;
  final String? badge;
  final ShopCategory? category;
  final int soldCount;
  final int stock;
  final String? description;
  final List<String> images;
}

class ShopProductPage {
  const ShopProductPage({
    required this.items,
    required this.count,
    required this.page,
    required this.pageSize,
  });

  final List<ShopProduct> items;
  final int count;
  final int page;
  final int pageSize;

  bool get hasMore => page * pageSize < count;
}
