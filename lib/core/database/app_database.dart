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
class FeedProgressTable extends Table {
  IntColumn get episodeId => integer()();
  IntColumn get positionSeconds => integer()();

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
    ])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(homeCacheTable);
            await m.createTable(shopCacheTable);
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
