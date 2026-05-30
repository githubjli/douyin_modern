import 'dart:convert';

import 'package:drift/drift.dart';

import '../../features/shop/domain/shop_models.dart';
import 'app_database.dart';
import 'cache_config.dart';

part 'shop_dao.g.dart';

class ShopSnapshot {
  const ShopSnapshot({
    required this.banners,
    required this.categories,
    required this.productPage,
  });

  final List<ShopBanner> banners;
  final List<ShopCategory> categories;
  final ShopProductPage productPage;

  Map<String, dynamic> toJson() => {
        'banners': banners.map((b) => b.toJson()).toList(),
        'categories': categories.map((c) => c.toJson()).toList(),
        'productPage': productPage.toJson(),
      };

  factory ShopSnapshot.fromJson(Map<String, dynamic> j) => ShopSnapshot(
        banners: (j['banners'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(ShopBanner.fromJson)
            .toList(),
        categories: (j['categories'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(ShopCategory.fromJson)
            .toList(),
        productPage: ShopProductPage.fromJson(
            j['productPage'] as Map<String, dynamic>),
      );
}

@DriftAccessor(tables: [ShopCacheTable])
class ShopDao extends DatabaseAccessor<AppDatabase> with _$ShopDaoMixin {
  ShopDao(super.db);

  Future<void> save(ShopSnapshot snapshot) =>
      into(shopCacheTable).insertOnConflictUpdate(
        ShopCacheTableCompanion(
          id: const Value(1),
          json: Value(jsonEncode(snapshot.toJson())),
          cachedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  Future<ShopSnapshot?> load() async {
    final row = await (select(shopCacheTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    if (row == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - row.cachedAt;
    if (age > CacheConfig.ttl.inMilliseconds) return null;
    return _decode(row.json);
  }

  Future<ShopSnapshot?> loadStale() async {
    final row = await (select(shopCacheTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    if (row == null) return null;
    return _decode(row.json);
  }

  ShopSnapshot? _decode(String raw) {
    try {
      return ShopSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() => delete(shopCacheTable).go();
}
