import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

/// One row per cached FeedItem. `position` preserves feed order.
/// `cachedAt` is epoch-ms of the batch that wrote this row.
class FeedItemsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get position => integer()();
  TextColumn get json => text()(); // FeedItem.toJson()
  IntColumn get cachedAt => integer()();
}

/// Per-episode playback progress.
/// `savedAt` (epoch-ms) is used to prune oldest entries when the table
/// exceeds [CacheConfig.maxProgressRows].
class FeedProgressTable extends Table {
  IntColumn get episodeId => integer()();
  IntColumn get positionSeconds => integer()();
  IntColumn get savedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {episodeId};
}

/// Scalar metadata (last viewed index, etc.).
class FeedMetaTable extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Home portal snapshot — single-row cache keyed by `id = 1`.
class HomeCacheTable extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get json => text()(); // HomePortalData.toJson()
  IntColumn get cachedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Shop snapshot — banners, categories, first-page products in one JSON blob.
class ShopCacheTable extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get json => text()();
  IntColumn get cachedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Membership VIP video list — JSON array of HomeVideoItem.
class MembershipVideosCacheTable extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get json => text()();
  IntColumn get cachedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(
    tables: [
      FeedItemsTable,
      FeedProgressTable,
      FeedMetaTable,
      HomeCacheTable,
      ShopCacheTable,
      MembershipVideosCacheTable,
    ])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Each step is isolated so a failure in one migration does not
          // prevent later steps from running.
          if (from < 2) {
            try {
              await m.createTable(homeCacheTable);
              await m.createTable(shopCacheTable);
            } catch (e, st) {
              // ignore: avoid_print
              print('[DB] migration v2 error: $e\n$st');
            }
          }
          if (from < 3) {
            try {
              // Add savedAt column; existing rows get epoch 0 (treated as
              // oldest — will be pruned first on next saveProgress call).
              await m.addColumn(feedProgressTable, feedProgressTable.savedAt);
            } catch (e, st) {
              // ignore: avoid_print
              print('[DB] migration v3 error: $e\n$st');
            }
          }
          if (from < 4) {
            try {
              await m.createTable(membershipVideosCacheTable);
            } catch (e, st) {
              // ignore: avoid_print
              print('[DB] migration v4 error: $e\n$st');
            }
          }
        },
      );

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final Directory dir = await getApplicationDocumentsDirectory();
      final File file = File(p.join(dir.path, 'meow_media.db'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
