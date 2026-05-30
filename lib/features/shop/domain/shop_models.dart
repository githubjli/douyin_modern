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

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'targetUrl': targetUrl,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

  factory ShopBanner.fromJson(Map<String, dynamic> j) => ShopBanner(
        id: j['id'] as int,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        targetUrl: j['targetUrl'] as String,
        imageUrl: j['imageUrl'] as String?,
      );
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

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'slug': slug};

  factory ShopCategory.fromJson(Map<String, dynamic> j) => ShopCategory(
        id: j['id'] as int,
        name: j['name'] as String,
        slug: j['slug'] as String,
      );
}

class ShopProductSpec {
  const ShopProductSpec({required this.name, required this.value});

  final String name;
  final String value;

  Map<String, dynamic> toJson() => {'name': name, 'value': value};

  factory ShopProductSpec.fromJson(Map<String, dynamic> j) =>
      ShopProductSpec(name: j['name'] as String, value: j['value'] as String);
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
    this.specs = const <ShopProductSpec>[],
    this.meowPointsPrice,
    this.meowCreditPrice,
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
  final List<ShopProductSpec> specs;
  final String? meowPointsPrice;
  final String? meowCreditPrice;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'soldCount': soldCount,
        'stock': stock,
        if (originalPrice != null) 'originalPrice': originalPrice,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (badge != null) 'badge': badge,
        if (category != null) 'category': category!.toJson(),
        if (description != null) 'description': description,
        'images': images,
        'specs': specs.map((s) => s.toJson()).toList(),
        if (meowPointsPrice != null) 'meowPointsPrice': meowPointsPrice,
        if (meowCreditPrice != null) 'meowCreditPrice': meowCreditPrice,
      };

  factory ShopProduct.fromJson(Map<String, dynamic> j) => ShopProduct(
        id: j['id'] as int,
        name: j['name'] as String,
        price: j['price'] as String,
        soldCount: j['soldCount'] as int,
        stock: j['stock'] as int,
        originalPrice: j['originalPrice'] as String?,
        thumbnailUrl: j['thumbnailUrl'] as String?,
        badge: j['badge'] as String?,
        category: j['category'] == null
            ? null
            : ShopCategory.fromJson(j['category'] as Map<String, dynamic>),
        description: j['description'] as String?,
        images: (j['images'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        specs: (j['specs'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(ShopProductSpec.fromJson)
                .toList() ??
            const [],
        meowPointsPrice: j['meowPointsPrice'] as String?,
        meowCreditPrice: j['meowCreditPrice'] as String?,
      );
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

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        'count': count,
        'page': page,
        'pageSize': pageSize,
      };

  factory ShopProductPage.fromJson(Map<String, dynamic> j) => ShopProductPage(
        items: (j['items'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(ShopProduct.fromJson)
            .toList(),
        count: j['count'] as int,
        page: j['page'] as int,
        pageSize: j['pageSize'] as int,
      );
}
