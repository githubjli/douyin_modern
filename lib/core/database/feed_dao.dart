import 'dart:convert';

import 'package:drift/drift.dart';

import '../../features/feed/domain/feed_item.dart';
import 'app_database.dart';

part 'feed_dao.g.dart';

@DriftAccessor(tables: [FeedItemsTable, FeedProgressTable, FeedMetaTable])
class FeedDao extends DatabaseAccessor<AppDatabase> with _$FeedDaoMixin {
  FeedDao(super.db);

  static const Duration _ttl = Duration(hours: 2);
  static const String _lastIndexKey = 'last_index';

  // ------------------------------------------------------------------
  // Feed list
  // ------------------------------------------------------------------

  Future<void> saveFeed(List<FeedItem> items) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    await transaction(() async {
      await delete(feedItemsTable).go();
      await batch((b) {
        b.insertAll(
          feedItemsTable,
          items.asMap().entries.map(
                (e) => FeedItemsTableCompanion.insert(
                  position: e.key,
                  json: jsonEncode(e.value.toJson()),
                  cachedAt: now,
                ),
              ),
        );
      });
    });
  }

  /// Returns cached feed if within TTL, null if expired or empty.
  Future<List<FeedItem>?> loadFeed() async {
    final rows = await (select(feedItemsTable)
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    if (rows.isEmpty) return null;
    if (_isExpired(rows.first.cachedAt)) return null;
    return _decode(rows);
  }

  /// Returns cached feed regardless of TTL — offline stale fallback.
  Future<List<FeedItem>?> loadStale() async {
    final rows = await (select(feedItemsTable)
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    if (rows.isEmpty) return null;
    return _decode(rows);
  }

  Future<void> clearFeed() => delete(feedItemsTable).go();

  List<FeedItem> _decode(List<FeedItemsTableData> rows) {
    final List<FeedItem> result = [];
    for (final row in rows) {
      try {
        result.add(FeedItem.fromJson(
            jsonDecode(row.json) as Map<String, dynamic>));
      } catch (_) {
        // Skip corrupted rows.
      }
    }
    return result;
  }

  bool _isExpired(int cachedAtMs) {
    final age = DateTime.now().millisecondsSinceEpoch - cachedAtMs;
    return age > _ttl.inMilliseconds;
  }

  // ------------------------------------------------------------------
  // Last viewed index
  // ------------------------------------------------------------------

  Future<void> saveLastIndex(int index) => into(feedMetaTable).insertOnConflictUpdate(
        FeedMetaTableCompanion.insert(key: _lastIndexKey, value: '$index'),
      );

  Future<int> loadLastIndex() async {
    final row = await (select(feedMetaTable)
          ..where((t) => t.key.equals(_lastIndexKey)))
        .getSingleOrNull();
    return int.tryParse(row?.value ?? '0') ?? 0;
  }

  // ------------------------------------------------------------------
  // Per-episode playback progress
  // ------------------------------------------------------------------

  Future<void> saveProgress(int episodeId, int positionSeconds) =>
      into(feedProgressTable).insertOnConflictUpdate(
        FeedProgressTableCompanion(
          episodeId: Value(episodeId),
          positionSeconds: Value(positionSeconds),
        ),
      );

  Future<int?> loadProgress(int episodeId) async {
    final row = await (select(feedProgressTable)
          ..where((t) => t.episodeId.equals(episodeId)))
        .getSingleOrNull();
    return row?.positionSeconds;
  }

  Future<void> clearProgress(int episodeId) =>
      (delete(feedProgressTable)
            ..where((t) => t.episodeId.equals(episodeId)))
          .go();
}
