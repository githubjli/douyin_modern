import 'dart:convert';

import 'package:drift/drift.dart';

import '../../features/home/domain/home_models.dart';
import 'app_database.dart';

part 'home_dao.g.dart';

@DriftAccessor(tables: [HomeCacheTable])
class HomeDao extends DatabaseAccessor<AppDatabase> with _$HomeDaoMixin {
  HomeDao(super.db);

  static const Duration _ttl = Duration(hours: 2);

  Future<void> save(HomePortalData data) =>
      into(homeCacheTable).insertOnConflictUpdate(
        HomeCacheTableCompanion(
          id: const Value(1),
          json: Value(jsonEncode(data.toJson())),
          cachedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  /// Within TTL — returns null when expired.
  Future<HomePortalData?> load() async {
    final row = await (select(homeCacheTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    if (row == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - row.cachedAt;
    if (age > _ttl.inMilliseconds) return null;
    return _decode(row.json);
  }

  /// Ignores TTL — stale fallback when offline.
  Future<HomePortalData?> loadStale() async {
    final row = await (select(homeCacheTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    if (row == null) return null;
    return _decode(row.json);
  }

  HomePortalData? _decode(String raw) {
    try {
      return HomePortalData.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() => delete(homeCacheTable).go();
}
