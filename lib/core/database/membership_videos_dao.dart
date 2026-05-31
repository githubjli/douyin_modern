import 'dart:convert';

import 'package:drift/drift.dart';

import '../../features/home/domain/home_models.dart';
import 'app_database.dart';
import 'cache_config.dart';

part 'membership_videos_dao.g.dart';

@DriftAccessor(tables: [MembershipVideosCacheTable])
class MembershipVideosDao extends DatabaseAccessor<AppDatabase>
    with _$MembershipVideosDaoMixin {
  MembershipVideosDao(super.db);

  Future<void> save(List<HomeVideoItem> videos) =>
      into(membershipVideosCacheTable).insertOnConflictUpdate(
        MembershipVideosCacheTableCompanion(
          id: const Value(1),
          json: Value(jsonEncode(videos.map((v) => v.toJson()).toList())),
          cachedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  /// Returns the cached list if within TTL, null if expired or missing.
  Future<List<HomeVideoItem>?> load() async {
    final row = await (select(membershipVideosCacheTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    if (row == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - row.cachedAt;
    if (age > CacheConfig.ttl.inMilliseconds) return null;
    return _decode(row.json);
  }

  /// Returns cached list ignoring TTL — used as offline fallback.
  Future<List<HomeVideoItem>?> loadStale() async {
    final row = await (select(membershipVideosCacheTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    if (row == null) return null;
    return _decode(row.json);
  }

  List<HomeVideoItem>? _decode(String raw) {
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(HomeVideoItem.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() => delete(membershipVideosCacheTable).go();
}
